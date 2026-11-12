# M1 — Control-signal table, all sixteen opcodes

Values are those `control_unit` drives in the **commit cycle** (WRITEBACK, or
MEM_IO with `io_ready = 1`). In FETCH, EXECUTE and HALTED every enable is 0;
in MEM_IO with `io_ready = 0` only the I/O request is high. `–` = don't care
(the implementation drives 0 / ALU to avoid latches).

`taken = cond-mux(flags)`: 000 Z, 001 ¬Z, 010 C, 011 ¬C, 100 N, 101 ¬N, 110 V, 111 ¬V.

| Op | Instr | Commit state | rf_we | mem_we | io_rd | io_wr | flags_we | wb_sel | pc_en | pc_load | retire | Next state |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | NOP | WB | 0 | 0 | 0 | 0 | 0 | – | 1 | 0 | 1 | FETCH |
| 1 | LDI | WB | 1 | 0 | 0 | 0 | 0 | 2 imm8 | 1 | 0 | 1 | FETCH |
| 2 | LD | WB | 1 | 0 | 0 | 0 | 0 | 1 DMEM | 1 | 0 | 1 | FETCH |
| 3 | ST | WB | 0 | 1 | 0 | 0 | 0 | – | 1 | 0 | 1 | FETCH |
| 4 | ADD | WB | 1 | 0 | 0 | 0 | 1 | 0 ALU | 1 | 0 | 1 | FETCH |
| 5 | SUB | WB | 1 | 0 | 0 | 0 | 1 | 0 ALU | 1 | 0 | 1 | FETCH |
| 6 | AND | WB | 1 | 0 | 0 | 0 | 1 | 0 ALU | 1 | 0 | 1 | FETCH |
| 7 | OR | WB | 1 | 0 | 0 | 0 | 1 | 0 ALU | 1 | 0 | 1 | FETCH |
| 8 | XOR | WB | 1 | 0 | 0 | 0 | 1 | 0 ALU | 1 | 0 | 1 | FETCH |
| 9 | SHL | WB | 1 | 0 | 0 | 0 | 1 | 0 ALU | 1 | 0 | 1 | FETCH |
| A | SHR | WB | 1 | 0 | 0 | 0 | 1 | 0 ALU | 1 | 0 | 1 | FETCH |
| B | CMP | WB | **0** | 0 | 0 | 0 | 1 | – | 1 | 0 | 1 | FETCH |
| C | JMP | WB | 0 | 0 | 0 | 0 | 0 | – | 1 | **1** | 1 | FETCH |
| D | Bcc | WB | 0 | 0 | 0 | 0 | 0 | – | 1 | **taken** | 1 | FETCH |
| E | IN (dir 0) | MEM_IO | io_ready | 0 | 1 | 0* | 0 | 3 io | io_ready | 0 | io_ready | ready ? FETCH : MEM_IO |
| E | OUT (dir 1) | MEM_IO | 0* | 0 | 0* | 1 | 0 | – | io_ready | 0 | io_ready | ready ? FETCH : MEM_IO |
| F | HLT | WB | 0 | 0 | 0 | 0 | 0 | – | **0** | 0 | 1 | HALTED |

\* `control_unit` has no `io_dir` input, so for opcode 0xE it drives
`io_rd = io_wr = 1` and `rf_we = io_ready`; `dsd8_cpu` qualifies them with
`io_dir` (glue 3). The values shown for IN/OUT are those seen at the
`dsd8_cpu` ports.

`halted` = 1 only in HALTED. `retire` = 1 exactly once per instruction.

## Register operand routing (spec §6.3, R18) — as implemented

| Instruction | ra1 | ra2 | Write address |
|---|---|---|---|
| R-type (ADD…XOR, CMP) | rs1 | rs2 | rd (none for CMP) |
| SHL, SHR | rs1 | rs2 (ignored) | rd |
| LD | rs1 (address) | rs2 (unused) | rd |
| ST | rs1 (address) | **rd** (data) | none |
| LDI | – | – | rd |
| IN | – | rd (unused) | rd |
| OUT | – | **rd** (data) | none |
