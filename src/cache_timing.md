# Cache Critical Path Analysis

## The Problem

The entire path from the PC register to the PC's clock-enable pin is one unbroken combinatorial chain:

```
PC register (s_pc_if)
  → s_index  [concurrent assignment in cache.vhd]
  → cache_mem(s_index)  [128-entry LUTRAM MUX — high fanout on PC index bits]
  → tag compare + valid_bit check
  → word-select MUX  [2:1 for 64-bit lines]
  → o_data / o_valid
  → s_instr_if_id  [cpu.vhd]
  → decoder → s_rs1_id / s_rs2_id
  → stall process  [s_rd_id_ex = s_rs1_id / s_rs2_id, s_valid_cache_if check]
  → s_pc_en_if
  → PC i_en (CE)
```

Both `o_data` (through the decoder) and `o_valid` (directly) land on the stall process that drives the PC's CE. Neither is registered inside the cache.

With `CACHE_LINE_WIDTH = 256` this chain measured **~18 ns** in Vivado (WNS = −4.205 ns at 100 MHz). With `CACHE_LINE_WIDTH = 64` the LUTRAM MUX and word-select are smaller, but the full chain is still a single path and remains the timing bottleneck.

---

## Fix: Register `o_data` and `o_valid` Inside the Cache

Insert a pipeline register after the word-select MUX. A registered address (`s_o_addr`) suppresses stale output after the PC advances — `o_valid` is only asserted when the registered data corresponds to the current request address.

### New signals in `cache.vhd`

```vhdl
signal s_o_data  : std_logic_vector(31 downto 0) := (others => '0');
signal s_o_valid : std_logic                      := '0';
signal s_o_addr  : std_logic_vector(31 downto 0) := (others => '1');

o_data  <= s_o_data;
o_valid <= s_o_valid and bool_to_sl(s_o_addr = i_address);
```

### Clocked process changes

`s_o_valid <= '0'` is the default at the top of the `else` branch so the flag is only high for one cycle:

```vhdl
s_o_valid <= '0';   -- default: clear every cycle

case state_reg is
    when Compare_Tag =>
        if hit then
            -- latch selected word
            for w in 0 to CACHE_LINE_WIDTH/32 - 1 loop
                if to_integer(unsigned(s_offset)) = w then
                    s_o_data <= cache_mem(s_index).data((w+1)*32-1 downto w*32);
                end if;
            end loop;
            s_o_valid <= '1';
            s_o_addr  <= i_address;
        end if;

    when Allocate =>
        if i_mem_ready = '1' then
            for w in 0 to CACHE_LINE_WIDTH/32 - 1 loop
                if to_integer(unsigned(s_offset)) = w then
                    s_o_data <= i_mem_data((w+1)*32-1 downto w*32);
                end if;
            end loop;
            s_o_valid <= '1';
            s_o_addr  <= i_address;
        end if;
    ...
end case;
```

---

## Path Breakdown After the Fix

| Path | Route | Expected |
|------|-------|----------|
| **Path 1** | PC → LUTRAM MUX → tag compare → word-select → **register** | ~7–9 ns ✓ |
| **Path 2** | **register** → 32-bit addr compare → `o_valid` → stall → PC CE | ~4–6 ns ✓ |
| **Path 3** | **register** → `o_data` → decoder → stall → PC CE | ~8–10 ns ⚠ |

Path 3 (decoder + stall comparators) is the new potential bottleneck. If it still fails after synthesis, the stall register outputs (`s_rd_id_ex`, `s_rs1_id`, `s_rs2_id`) can be pipelined one stage earlier, breaking that path at the cost of one additional stall-detection latency cycle.

---

## Throughput Impact

Throughput stays at **2 cycles per instruction** on a warm cache — the same as the current design. The no-Idle optimisation (Compare_Tag loops back to itself on a hit) already achieves this; the registered output holds the result for one cycle while the same PC address is re-evaluated, then the PC advances on the following cycle.

The benefit is purely **timing**: the path budget is halved without changing pipeline behaviour or miss penalty.
