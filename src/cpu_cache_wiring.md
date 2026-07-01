# cpu.vhd — Cache Wiring Fixes

These are the targeted fixes applied to the partial cache integration in `src/cpu.vhd`.
Full cache-miss stall logic is **not yet implemented** and is called out below.

---

## Fixed issues

### 1. `o_mem_rd_wr` connected to `s_if_id_en` (wrong signal)

**Problem:** The cache's `o_mem_rd_wr` output (selects read vs write on the memory interface, used during write-back) was wired to `s_if_id_en`, which is the pipeline freeze enable for the IF/ID stage. This would have caused the pipeline to randomly freeze or unfreeze whenever the cache performed a write-back.

**Fix:** A new signal `s_mem_wr_en_if` was added. `cache.o_mem_rd_wr` now drives `s_mem_wr_en_if`, which in turn connects to `instr_mem.i_wr_en`. `s_if_id_en` is exclusively driven by the LW stall process, as intended.

---

### 2. Double-driver on `s_instr_if_id`

**Problem:** Both `instr_mem.o_rd_data` and `cache.o_data` were mapped to `s_instr_if_id`. Two drivers on the same signal is a synthesis error and causes undefined simulation behaviour.

**Fix:** A new signal `s_mem_rd_data_if` was added for `instr_mem.o_rd_data`. The pipeline (`s_instr_if_id`) is now driven **only** by `cache.o_data`, which is the architecturally correct source: the pipeline always receives the instruction word from the cache, not directly from memory.

---

### 3. `i_mem_data` feedback loop

**Problem:** `cache.i_mem_data` (the data the cache receives from memory during a fill) was mapped to `s_instr_if_id` — the same signal the cache itself drives via `o_data`. This created a combinatorial feedback loop: cache output → fill input → cache.

**Fix:** `cache.i_mem_data` is now connected to `s_mem_rd_data_if` (the `instr_mem.o_rd_data` output). Data flow is now unidirectional:

```
instr_mem.o_rd_data --> s_mem_rd_data_if --> cache.i_mem_data
                                             cache.o_data --> s_instr_if_id --> pipeline
```

---

### 4. `s_valid_cpu_if` never driven

**Problem:** The CPU-to-cache request-valid signal was declared but left undriven (logic value `'U'`), so the cache FSM never left the Idle state and no instruction was ever fetched.

**Fix:** Added the assignment:

```vhdl
s_valid_cpu_if <= s_if_id_en;
```

This asserts a fetch request whenever the pipeline is not frozen by a load-use stall. It is a **placeholder** — see the note below.

---

## Pending work (not in scope for this change)

- **Cache-miss stall:** When the cache has a miss (`s_valid_cache_if = '0'`), the pipeline must be frozen (PC held, IF/ID and ID/EX held) until the fill completes. Currently the pipeline runs freely regardless of cache status. `s_valid_cpu_if` will also need to factor in the cache-miss stall once this is implemented.
- **Branch flush + cache interaction:** A taken branch reloads the PC. The cache will still hold the old PC's request in flight for one more cycle. The flush/bubble mechanism needs to be verified against this path.
