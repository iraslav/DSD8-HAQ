# Bug log

Required by spec §8.5 and graded under Verification quality. One row per
bug, written when the bug was found. *Found by* is one of: **unit test**,
**conformance diff**, **review**, **inspection**. *Cost* is wall-clock time
from first symptom to verified fix.

| # | Date | Module | Symptom | Found by | Root cause | Fix | Cost | Milestone |
|---|------|--------|---------|----------|------------|-----|------|-----------|
| 1 | 2026-10-29 | tb_alu_example.v (supplied TB) | `iverilog -g2005` compile error at line 89, testbench never runs | unit test (`make test` compile step) | `expected_result(...)[7]` — bit-select of a function call is not legal Verilog-2005 | assign the call to an 8-bit variable, then take bit 7 | 3 min | M2 |
| 2 | 2026-10-29 | tb_alu_random.v | `COVERAGE HOLE: SHR flag 1 not seen both ways` with 0 data mismatches | unit test | TB coverage rule expected N = 1 to be reachable for SHR; a logical right shift always clears bit 7, so N is architecturally 0 | added SHR/N to the unreachable-bin list **and** an explicit check that N is never 1 for SHR (catches an arithmetic-shift bug) | 4 min | M2 |
