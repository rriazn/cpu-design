# Instruction Cache — Full Integration

Completes the integration of `instr_cache` into `src/cpu.vhd`.
Builds on the wiring fixes documented in `cpu_cache_wiring.md`.

---

## Changes made

### 1. `s_valid_cpu_if` always asserted

```vhdl
s_valid_cpu_if <= '1';
```

The cache manages its own fetch timing through its FSM. The pipeline controls
correctness by freezing the PC via `s_pc_en_if` when stalling — so the same
address is re-presented to the cache on the next cycle. Tying `s_valid_cpu_if`
to `s_if_id_en` (the old placeholder) would have de-asserted it during cache
stalls, returning the cache to Idle just when it needed to keep running.

---

### 2. Cache-miss stall added to the stall process

The existing stall process was extended with a `s_valid_cache_if = '0'` condition:

```vhdl
process(s_rd_id_ex, s_mem_rd_en_id_ex, s_rs1_id, s_rs2_id,
        s_branch_taken_mem, s_valid_cache_if)
begin
    s_pc_en_if <= '1';
    s_if_id_en <= '1';
    s_stall    <= '0';
    if s_branch_taken_mem = '0' then
        -- LW load-use hazard (unchanged)
        if s_mem_rd_en_id_ex = '1' and s_rd_id_ex /= "00000" then
            if s_rd_id_ex = s_rs1_id or s_rd_id_ex = s_rs2_id then
                s_pc_en_if <= '0';
                s_if_id_en <= '0';
                s_stall    <= '1';
            end if;
        end if;
        -- Cache not ready (new)
        if s_valid_cache_if = '0' then
            s_pc_en_if <= '0';
            s_if_id_en <= '0';
        end if;
    end if;
end process;
```

**Why no `s_stall` for cache misses?**
`s_stall = '1'` clears ID/EX (inserts a NOP bubble). During a cache miss,
`cache.o_data` is `(others => '0')` by default, which decodes as
`ADD x0, x0, x0` — functionally a NOP with no register-file side effects.
This zeros-as-NOP flows through ID/EX naturally, so there is no need to
explicitly clear the register; setting `s_stall` would be redundant.

**Why branch overrides the cache stall?**
`s_branch_taken_mem` is the outer guard for both conditions. When a branch is
taken, the PC redirect must not be blocked by an in-progress cache stall.
The existing `s_if_id_flushed` mechanism (registered `s_branch_taken_mem`)
handles the one-cycle pipeline drain after the branch as before.

---

## Behaviour summary

| Situation | `s_pc_en_if` | `s_if_id_en` | `s_stall` | ID/EX |
|---|---|---|---|---|
| Normal (cache hit, no hazard) | 1 | 1 | 0 | captures instruction |
| LW load-use hazard | 0 | 0 | 1 | cleared (NOP bubble) |
| Cache miss / Idle cycle | 0 | 0 | 0 | captures zeros (NOP) |
| Branch taken | 1 | 1 | 0 | cleared by `s_branch_taken_mem` |

---

## Timing notes

The cache FSM has one unavoidable Idle cycle between each fetch (Idle →
Compare_Tag → Idle). This means the pipeline sustains **1 useful instruction
every 2 cycles** on cache hits, compared to 1 cycle per instruction with the
bare BRAM. Cache misses add further cycles (Write_Back if dirty + Allocate from
memory). For hardware with human-visible LED output this is acceptable; if
throughput matters the cache FSM can be extended to loop directly from a hit
back into Compare_Tag without returning to Idle.

## Branch + cache-miss interaction

If a branch is resolved while the cache is in the middle of an Allocate (filling
a line for the pre-branch PC), the stall logic freezes the PC at the branch
target. The cache completes the fill (wasted work) and then serves the branch
target on its next Compare_Tag cycle. This is functionally correct at the cost
of a few extra stall cycles per taken branch that coincides with a cache miss.
