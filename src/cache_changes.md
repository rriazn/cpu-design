# Cache Implementation — Review & Fixes

## Fixed issues in `src/cache.vhd`

### 1. `cache_mem` written from combinatorial process (latch inference)

**Problem:** The original design updated `cache_mem` signals inside the combinatorial FSM output process. In VHDL, a signal assigned conditionally without a default value in a combinatorial process is inferred as a **latch**, not a flip-flop. This would cause incorrect simulation behaviour and synthesis warnings/errors.

**Fix:** All writes to `cache_mem` were moved into the **clocked process**. The clocked process now handles both the state register update (`state_reg <= state_next`) and all cache array updates:

```vhdl
-- Clocked process handles cache_mem updates
case state_reg is
    when Compare_Tag =>
        if hit and i_direction = '1' then   -- write hit
            cache_mem(s_index).data      <= i_data;
            cache_mem(s_index).dirty_bit <= '1';
        end if;
    when Allocate =>
        if i_mem_ready = '1' then           -- fill on memory response
            cache_mem(s_index).data      <= i_mem_data;
            cache_mem(s_index).valid_bit <= '1';
            cache_mem(s_index).dirty_bit <= '0';
            cache_mem(s_index).tag       <= s_tag;
        end if;
    when others => null;
end case;
```

The combinatorial process now only computes next-state and output signals — it never writes to `cache_mem`.

The reset path also now explicitly clears `valid_bit` and `dirty_bit` for all lines so no stale valid entries persist after reset.

---

### 2. `o_data` missing default assignment (latch inference)

**Problem:** `o_data` was only assigned inside the Compare_Tag hit branch of the combinatorial process. In all other states (Idle, Write_Back, Allocate) it had no driver, causing a latch to be inferred.

**Fix:** A default assignment was added at the top of the combinatorial process:

```vhdl
o_data <= (others => '0');
```

---

### 3. Write-back used the wrong address

**Problem:** During Write_Back, the evicted dirty line must be flushed to its **original** memory address — reconstructed from the stored tag and the current index. The original code used `i_address` (the new incoming request's address), which would have written the dirty data to the wrong location, corrupting memory.

**Fix:** A dedicated signal `s_wb_addr` reconstructs the evicted line's address from the stored tag, the index, and the zero byte-offset bits:

```vhdl
s_wb_addr <= cache_mem(s_index).tag
             & std_logic_vector(to_unsigned(s_index, C_INDEX_BITS))
             & "00";
```

The combinatorial process uses `s_wb_addr` (not `i_address`) only when in the Write_Back state:

```vhdl
when Write_Back =>
    o_mem_addr <= s_wb_addr;
    ...
```

---

### 4. Unnecessary extra cycle after Allocate (read miss)

**Problem:** After filling a line (Allocate), the FSM returned to Compare_Tag. This caused an extra cycle just to re-detect the hit that was already guaranteed by the fill, adding 1 cycle of latency to every read miss.

**Fix:** For **read misses**, when `i_mem_ready = '1'` in Allocate, the fill data is output directly (`o_data <= i_mem_data`, `o_valid <= '1'`) and the FSM transitions straight to Idle, saving one cycle per miss.

For **write misses**, the FSM still goes back to Compare_Tag after filling, so the pending write is applied to the now-populated line. This preserves write-allocate correctness.

```vhdl
when Allocate =>
    if i_mem_ready = '1' then
        if i_direction = '0' then   -- read: output directly, done
            o_data     <= i_mem_data;
            o_valid    <= '1';
            state_next <= Idle;
        else                        -- write: re-enter Compare_Tag to apply the write
            state_next <= Compare_Tag;
        end if;
    end if;
```

---

## Known limitations / remaining work

- **`cpu.vhd` integration is incomplete.** The current wiring has several issues (double-driver on `s_instr_if_id`, `o_mem_rd_wr` incorrectly connected to the pipeline stall enable, `s_valid_cpu_if` never driven, no cache-miss stall logic). This is tracked separately.
- **Instruction cache does not need write-back.** The instruction memory is read-only at runtime, so `dirty_bit` will always remain `'0'` and the Write_Back state is unreachable. The write path is retained so the module can be reused as a data cache later.
- **1-word cache lines.** Each line holds exactly one instruction word. Spatial locality is not exploited. A multi-word line (e.g. 4 words) would improve performance on sequential fetches.
