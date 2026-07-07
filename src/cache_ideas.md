# Direct-Mapped Instruction Cache — Ideas & Improvements

## Simplification: Read-Only FSM

An instruction cache is read-only by definition — `dirty_bit` is never set and `Write_Back` is unreachable. The implementation can be simplified to reflect this:

- Remove `dirty_bit`, `i_direction`, `i_data` ports and the `Write_Back` state
- Miss check in `Compare_Tag` becomes unconditional: always go to `Allocate`
- FSM collapses from 4 states to 3: **Idle → Compare_Tag → Allocate**

This is the architecturally correct design for an I-cache and demonstrates the distinction from a D-cache.

---

## Parametrisation: Generic Cache Depth

`C_NUM_LINES` is currently hardcoded to 128. Making it a generic alongside `CACHE_LINE_WIDTH` completes the parametrisation and exposes the direct-mapped tradeoff:

| `C_NUM_LINES` | Conflict misses | Area |
|:---:|:---:|:---:|
| 64 | Higher | Smaller |
| 128 | Moderate | Medium |
| 256 | Lower | Larger |

---

## Flush / Invalidate Port

An `i_flush` input that clears all `valid_bit`s in a single cycle — same effect as reset but without disturbing pipeline state. Needed when:

- The CPU writes to instruction memory (e.g. a bootloader or self-modifying code)
- A data cache is added later and cache coherency must be managed explicitly

---

## Performance: Early Memory Request on Miss

Currently, the memory request is sent one cycle late — only after the FSM enters `Allocate`. Since the miss is detected combinatorially in `Compare_Tag`, `o_mem_valid` can be asserted in the same cycle as the miss:

```
Current:   Compare_Tag (detect miss) → Allocate (send request) → wait → fill
Proposed:  Compare_Tag (detect miss + send request) → Allocate (response already ready) → fill
```

Saves **1 cycle** from every cold miss. No burst required.

---

## Performance: Remove Idle State

On a cache hit the FSM currently returns to `Idle` before accepting the next fetch, halving throughput on a warm cache:

```
Current:   ... → Idle (1 cycle) → Compare_Tag (hit) → Idle (1 cycle) → Compare_Tag (hit) → ...
Proposed:  ... → Compare_Tag (hit) → Compare_Tag (hit) → Compare_Tag (hit) → ...
```

Change: `state_next <= Idle` on hit becomes `state_next <= Compare_Tag`, initial state becomes `Compare_Tag`. Restores **1 instruction/cycle** throughput for a warm cache.

---

## Observability: Hit/Miss Counters

Two registered output counters for simulation and hardware verification:

- `o_hit_count` — increments when `o_valid = '1'` in `Compare_Tag`
- `o_miss_count` — increments on entry to `Allocate`

Useful for measuring actual miss rate, validating the cache is working, and justifying line size or depth choices.
