# DSD-8 Verification Report

*Team: ______ · Members: A Abdul Qadeer, B Hitesh Kumar, C Afzal Khan · Date: ______*

Spec §9.3 item 3 (4–6 pages), §8.5 R24/R25. Every number in this report is
produced by a command in the repository; the command is given next to it.

---

## 1. Test plan

Verification is organised in five layers (guide slide 49), climbed bottom-up:
a failure at a higher layer is only cheap to debug if the layers below pass.

| Layer | What | Where | Command |
|---|---|---|---|
| 1 Unit | one self-checking testbench per module; constrained-random ALU | `tb/tb_<module>.v` | `make test` |
| 2 Single-instruction | one behaviour per program, every result visible in the trace | `tests/conformance/T01–T35` | `make conformance` |
| 3 Corner / interaction | flag edges, operand aliasing, read-after-write, both branch sides, PC wrap | T03–T08, T15–T30, `tests/extra/X01–X07` | `make conformance extra` |
| 4 Integration | multiply, popcount, bubble sort, max/min, UART | T36–T40, `tb/tb_dsd8_top.v` | `make conformance test` |
| 5 Random | 10 seeded 300-instruction programs vs the golden model | `tests/extra/R*.asm` | `make extra` |
| Meta | does the verification catch real bugs? 20 injected classic bugs | `scripts/mutation_check.py` | `python3 scripts/mutation_check.py` |

Bring-up order actually followed (spec §8.4): T05 (NOP: fetch, PC, trace) →
T01 (LDI: register write-back) → T23 (JMP: branch path) → all others. The
first bring-up run failed with an empty trace — the conformance runner itself
was not loading the program image (bug log #4). Because T05 exercises nothing
but fetch and trace, the diagnosis took 15 minutes instead of being confused
with an ALU or decoder problem.

**Golden-model check.** Before trusting `tools/dsd8sim.py` we compared its
output with every trace printed in the spec and the guide: Appendix B.1
first six lines, B.1 / B.2 final state and instruction counts, guide slide 51
(ALU corners, reproduced verbatim as X01), slides 52–53 (memory, branch, I/O
tests). All agree. One inconsistency *in the spec* was found and noted:
§8.2's extract shows `140D` for `LDI R1, 13`, but the correct encoding (and
Appendix B.1) is `120D`; `140D` is `LDI R2, 13`.

## 2. Unit testbench coverage

All testbenches print `TESTBENCH: PASS` / `FAIL (n errors)`; references are
computed independently of the RTL (different arithmetic, literal tables).

| Module | Testbench | What it covers | Known gaps |
|---|---|---|---|
| prog_counter | `tb_prog_counter.v` | reset priority over enables, hold, increment, wrap 0x1FF→0x000, load, `pc_load` ignored without `pc_en`; 5 000 random cycles vs reference model incl. random resets | none known |
| instr_memory | `tb_instr_memory.v` | all 512 words of an independently generated image, sequential and random order | registered-read variant not used |
| instr_decoder | `tb_instr_decoder.v` | the 11 worked encodings of §3.5 (literal expected fields); **all 65 536 words** vs an arithmetic (div/mod) reference | exhaustive — none |
| register_file | `tb_register_file.v` | reset clears all 8 (and a mid-run reset), every register on both ports, `we = 0`, **R14** old-value-on-same-cycle read, 2 000 random cycles vs shadow | none known |
| alu | `tb_alu_example.v` | directed: one vector per op + corner operands for ADD/SUB | directed only |
| alu | `tb_alu_random.v` | **96 000 constrained-random pairs** (12 000 per op), integer-arithmetic reference, corner and flag coverage (§3) | none known |
| flags_reg | `tb_flags_reg.v` | reset (beats a write), hold, bit order Z=3…V=0, 3 000 random cycles | none known |
| data_memory | `tb_data_memory.v` | all 256 bytes read 0x00 (never X) before any write, `we = 0`, old value during write cycle, addresses 0x00/0xFF, 4 000 random accesses vs shadow | re-clear on a second reset — not supported by design (D3) |
| control_unit | `tb_control_unit.v` | every opcode cycle-by-cycle against a literal copy of the §6.2 table; Bcc 8 conditions × 16 flag values; IN/OUT with 0–9 stall cycles (request held, no enable); reset mid-instruction; HLT retires once then 20 cycles of nothing | none known |
| io_bus | `tb_io_bus.v` | R20 (no ready without request, all 256 ports), switches/buttons, LEDS/SEG latch only on write, unmapped and read-only ports, external forwarding with 0–7 wait cycles, local registers stable during external access | real UART timing (model has no RX) |
| dsd8_cpu | `tb_dsd8_cpu.v` | system protocol on T34 (69 SLOW_ECHO transfers, 369 stall cycles): no retire in reset/after HLT, PC changes only after a retire, bus stable and no commit while stalled, no X, zero-forcing, CPI = 3 (+stall for I/O), shadow register file = golden final state | — |
| dsd8_top | `tb_dsd8_top.v` | board build: multiply → LEDs 0x5B + halted; bubble sort → LEDs 0x01, 7-seg digit 0 shows "9", other digits dark; debouncer rejects a 2-cycle glitch and passes a held press | real FPGA timing (needs Vivado) |

## 3. ALU constrained-random test and coverage evidence (R24, R25)

`tb/tb_alu_random.v`, seed 20261029 (fixed, so the run is reproducible).
Each operand is a corner value (0x00, 0x01, 0x7F, 0x80, 0xFF) with
probability 3/8, otherwise a uniform random byte. Output of `make test`
(verbatim):

```
ALU constrained-random test: 96000 operand pairs (12000 per op), seed 20261029, 0 mismatches
Corner-operand coverage: hits as operand a / operand b
op  |  0x00      |  0x01      |  0x7F      |  0x80      |  0xFF      | corner x corner bins hit
ADD |  925/ 887  |  980/ 944  |  894/ 927  |  962/ 893  |  912/ 901  | 25/25
SUB |  948/ 963  |  951/ 934  |  948/ 916  |  956/ 939  |  894/ 922  | 25/25
AND |  922/ 948  |  934/ 924  |  931/ 924  |  929/ 937  |  886/ 936  | 25/25
OR  |  892/ 888  |  903/ 920  |  937/ 879  |  907/ 898  |  895/ 940  | 25/25
XOR |  953/1012  |  893/ 914  |  881/ 894  |  941/ 918  |  948/ 951  | 25/25
SHL |  951/ 925  |  941/ 967  |  944/ 908  |  932/ 910  |  931/ 991  | 25/25
SHR |  857/ 945  |  901/ 919  |  978/ 928  |  916/ 935  |  908/ 898  | 25/25
CMP |  941/ 918  |  954/ 941  |  916/ 914  |  917/ 934  |  905/ 906  | 25/25
Flag coverage: times each flag was observed 1 / 0
op  |  Z          |  N          |  C          |  V
ADD |   312/11688 |  5963/ 6037 |  5135/ 6865 |  2746/ 9254
SUB |   385/11615 |  5975/ 6025 |  6163/ 5837 |  2736/ 9264
AND |  3593/ 8407 |  2594/ 9406 |     0/12000 |     0/12000
OR  |    63/11937 |  8546/ 3454 |     0/12000 |     0/12000
XOR |   384/11616 |  5980/ 6020 |     0/12000 |     0/12000
SHL |  1883/10117 |  5515/ 6485 |  5489/ 6511 |     0/12000
SHR |  1758/10242 |     0/12000 |  6473/ 5527 |     0/12000
CMP |   391/11609 |  5978/ 6022 |  6179/ 5821 |  2809/ 9191
(C and V are architecturally 0 for AND/OR/XOR, V is 0 for SHL/SHR, N is 0 for SHR: their '1' column must read 0)
TESTBENCH: PASS
```

Reading the evidence:

- **R24:** 96 000 pairs ≥ 10 000, all eight operations, 0 mismatches.
- **R25:** every corner value occurs as operand *a* and as operand *b* for
  every operation (smallest count 857), and all 25 corner × corner pairs
  occur for every operation — e.g. 0x7F + 0x01 (signed overflow), 0xFF + 0x01
  (carry, no overflow), 0x80 − 0x01 (subtract overflow), 0x00 − 0x01 (borrow).
- **Flag coverage:** every flag that *can* be 1 for an operation was seen both
  1 and 0 (Z for OR only 63 times — OR is rarely zero — still non-zero). The
  architecturally-zero bins (C, V for logic ops; V for shifts; N for SHR)
  read 0, which is itself a check: an arithmetic SHR would put 1s in SHR/N.
- **What it does not prove:** that the ALU is *used* correctly — e.g. that the
  control unit writes the flags only for the eight flag-setting instructions,
  or that CMP's result is discarded. Those are covered by T14, T21, T35 and
  by `tb_control_unit.v`.
- **Independence check:** mutation M04 (overflow computed from `b` instead of
  the effective `b`) passes the directed `tb_alu_example.v` but is caught by
  the random test with 11 449 mismatches — the directed vectors alone would
  have missed a real SUB overflow bug.

## 4. Conformance and extra results

`make report` writes `doc/conformance_report.txt`.

| Suite | Programs | Result |
|---|---|---|
| Conformance T01–T40 (+ the two supplied samples) | 42 | **42 / 42 pass** |
| Extra directed X01–X07 | 7 | 7 / 7 pass |
| Seeded random R00001…R31337 (300 instructions each, forward branches, I/O incl. SLOW_ECHO) | 10 | 10 / 10 pass |
| Unit testbenches | 12 | 12 / 12 pass |
| Lint (`verilator --lint-only -Wall`, roots `dsd8_top` and `dsd8_cpu`) | 13 files | clean, no latches |

**Important caveat:** the official T01–T40 suite had not been distributed to
us; our T01–T40 are written from the one-line descriptions in §8.4, under the
same numbers, with golden traces from `dsd8sim.py`. T40 is a documented
bounded variant (the reference UART model has no receive stimulus and the
golden model cannot reproduce a cycle-limit stop). When the official suite
arrives it drops into `tests/conformance/` unchanged.

## 5. Does the verification find bugs? — mutation analysis

`scripts/mutation_check.py` re-introduces 20 classic DSD-8 bugs (spec
Appendix C, guide slide 38), one at a time, into a scratch copy and runs all
three suites.

| ID | Injected bug | Unit TBs | Conformance T01-T40 | Extra + random |
|---|---|---|---|---|
| M01 | rf_we asserted for CMP | **killed** | **killed** | **killed** |
| M02 | SUB/CMP carry = borrow (inverted convention) | **killed** | **killed** | **killed** |
| M03 | SHR arithmetic instead of logical | **killed** | **killed** | **killed** |
| M04 | overflow uses b instead of effective b (SUB V wrong) | **killed** | **killed** | **killed** |
| M05 | Format M/P routing: read port 2 always rs2 | **killed** | **killed** | **killed** |
| M06 | trace flags sampled before update (lag) | survived | **killed** | **killed** |
| M07 | no zero-forcing of rf_addr (R23) | **killed** | **killed** | **killed** |
| M08 | io_ready ignored for the state (no stall) | **killed** | survived | survived |
| M09 | I/O commits without waiting for io_ready | **killed** | **killed** | **killed** |
| M10 | data memory not cleared (R16) | **killed** | **killed** | **killed** |
| M11 | LD and ST also write flags | **killed** | **killed** | **killed** |
| M12 | BCS tests C = 0 | **killed** | **killed** | **killed** |
| M13 | rs1 / rs2 slices swapped | **killed** | **killed** | **killed** |
| M14 | unmapped low ports read the switches | **killed** | survived | survived |
| M15 | PC advances past HLT | **killed** | survived | survived |
| M16 | OUT sends R[rs1] instead of R[rd] | **killed** | **killed** | **killed** |
| M17 | write-through forwarding (violates R14) | **killed** | **killed** | **killed** |
| M18 | PC increments by 2 | **killed** | **killed** | **killed** |
| M19 | HLT does not halt | **killed** | **killed** | **killed** |
| M20 | flags register ignores flags_we | **killed** | **killed** | **killed** |

20 / 20 mutations killed by at least one suite.

What the table shows:

- **Every injected bug is caught by at least one suite** (20 / 20).
- **Conformance alone misses three** (M08, M14, M15), all caught by unit or
  system testbenches:
  - M08 drops the I/O request after one cycle and re-issues it; the
    architectural result is the same, so no trace line differs, but it
    violates R19 (request must be held until `io_ready`). Caught by
    `tb_control_unit` and the bus-stability check in `tb_dsd8_cpu`.
  - M14 makes unmapped low ports return the switches. The harness drives
    `switches = 0x00`, so the trace cannot tell 0x00 from "the switches" —
    a blind spot of the harness, caught by `tb_io_bus` (switches = 0x3C).
  - M15 lets the PC advance past HLT. The machine still halts and no line
    differs, but the PC no longer "holds its own address" (§3.4.3).
    Caught by `tb_control_unit`.
- **Unit tests alone miss one** (M06, trace flags lag): the bug is in the
  integration glue, which only the trace sees. This is the spec's point that
  both layers are required.
- **The extra suite (7 directed + 10 random programs) kills exactly the same
  mutations as T01–T40** — an independent second opinion on the trace layer,
  most of it at no authoring cost per test.

## 5a. Extension: RSA enclave -- secure channel and debugger

Five further testbenches (`tb_rsa_modexp`, `tb_rsa_enclave`, `tb_cpu_mailbox`,
`tb_rsa_cpu`, `tb_dsd8_secure_top`) verify the extension; see
`doc/security_enclave.md` for what each covers. The engine is checked against
400 vectors from Python's `pow()`. The end-to-end test checks that every
mailbox word after the public-key exchange is ciphertext, that no data moves
while either key is wrong, and that both sides decrypt each other's data.
`scripts/check_enclave_keys.py` proves no wrong-key combination can open the
channel. Fifteen enclave and debugger mutations (M21–M35) are all caught; M26 was missed
twice and each time led to a stronger scenario (bug log #12, #15), and M35 once (#17). The debugger is verified by
`tb_rsa_debug` (every feature at bus level, values from Python) and
`tb_dsd8_secure_debug` (both processors boot in DEBUG mode and pass all 8
on-chip debug checks). The core's conformance results are unchanged (42/42).

## 6. Closure argument

We consider the design verified for submission because:

1. **Every module** is exercised in isolation by a self-checking testbench
   whose reference is independent of the RTL, two of them exhaustively
   (decoder: all 65 536 words; control unit: every opcode, every
   condition × flag combination).
2. **Every requirement R1–R25** maps to at least one passing test (traceability
   table in §7).
3. **The integrated core** matches the golden model instruction-for-instruction
   on 59 programs (10 112 retired instructions), including 10 random
   programs nobody hand-wrote.
4. **The verification itself is measured**: the mutation table shows which
   suites catch which classes of bug. Every injected bug is caught by at
   least one suite.

**What is not verified, and why the risk is acceptable:**

| Not verified | Why acceptable |
|---|---|
| Behaviour with non-zero reserved bits | R10: undefined, never presented by the suite |
| DMEM re-clear on a *second* reset | design decision D3; grading and the demo reset once |
| UART receive path, real UART timing | reference model has no RX; T40 bounded variant; `io_bus` forwarding is unit-tested and SLOW_ECHO exercises the stall path |
| Official T01–T40 | not distributed; ours follow §8.4 and are drop-in replaceable |
| FPGA timing closure | needs Vivado; mitigated by the 25 MHz core clock (D7). Board build is simulated end-to-end by `tb_dsd8_top.v` |
| Branch *targets* outside the program image | instruction memory past the image is X by design of the supplied ROM; every test ends in HLT |
| Trace hex case | spec §8.2 shows `%03X` (upper case); the supplied harness and golden model both print lower case. Both sides agree, so comparison is unaffected |

## 7. Requirement traceability

| Req | Subject | Evidence |
|---|---|---|
| R1, R2 | 8 GPRs, R0 not special | `tb_register_file`, T01, T03, T12 (R0 as address), X06 |
| R3 | exactly 8 instrs set flags | T04, T14, T27, T35, `tb_control_unit` |
| R4 | IMEM 512×16 read-only | `tb_instr_memory`, X07 (address 0x1FF) |
| R5 | DMEM 256 bytes, all reachable | T10, T13 (all 256), T09 |
| R6 | reset state | `tb_register_file`, `tb_flags_reg`, `tb_prog_counter`, `tb_data_memory`, T09 |
| R7 | sync active-low reset ≥ 2 cycles | all TBs (synchronous reset), bug #6 fix in `dsd8_top` |
| R8, R9 | HLT stops, nothing changes | `tb_control_unit` (20 cycles after HLT), `tb_dsd8_cpu`, M15/M19 |
| R10 | reserved bits | assembler emits 0 (not exercised, by definition) |
| R11 | IN/OUT honour `io_ready` | T34, `tb_control_unit`, `tb_dsd8_cpu` (369 stall cycles), M08/M09 |
| R12 | module/port names | harness compiles against our RTL unchanged |
| R13 | in-order retirement, one line each | `tb_dsd8_cpu` CPI/retire checks; all traces |
| R14 | old value on same-cycle read | `tb_register_file`; M17 |
| R15 | one 9-bit adder | `rtl/alu.v` (`sum9`), design decision D8 |
| R16 | DMEM reads 0x00 never X | `tb_data_memory`, T09; M10 |
| R17 | branch from cond/flags; pc_load only if taken | `tb_control_unit` 8×16, T24, T25, T26; M12 |
| R18 | ST data from rd, address from rs1 | T11, T12, X06; M05 |
| R19, R20 | handshake protocol | `tb_io_bus`, `tb_dsd8_cpu` |
| R21 | port map, unmapped 0x00 | T31, T32, `tb_io_bus`; M14 |
| R22 | one trace line per retired instr | every conformance diff; `tb_dsd8_cpu` |
| R23 | zero-forcing | T21 and every non-writing line; `tb_dsd8_cpu`; M07 |
| R24 | unit TB per module + random ALU + this report | §2, §3 |
| R25 | ALU corner coverage reported | §3 table |

## 8. Bug log summary

Full log: `doc/bug_log.md`.

| Found by | Bugs | Typical cost | Entries |
|---|---|---|---|
| unit test | 4 | 3–10 min | #1 (compile step), #2, #5, #6 |
| conformance diff | 1 | 15 min | #4 |
| inspection | 2 | 2–6 min | #3, #7 |
| review | 0 | — | — |

Seven bugs, all found before or during bring-up, none in the processor's
architectural behaviour once integrated: the 40 conformance programs passed
on their first complete run. That is the pattern the spec predicts —
cheap bugs caught by unit tests, and an integration that has little left to
find — but it is also a reason for suspicion, which is why §5 measures the
test suites with deliberately injected bugs instead of trusting a green run.
Most of our bugs were in **verification infrastructure** (testbenches, the
lint script, the conformance runner, the board wrapper), not in the core —
an honest observation: infrastructure is code, and it needs testing too.
The single most expensive bug (#4, 15 min) was found at integration, by the
conformance diff, exactly where the spec says bugs are expensive.
