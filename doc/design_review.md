# M5 — Design review with a partner team

Spec §9.1 M5: "Design review with a partner team completed and findings
answered in writing." The partner team fills in **Part A**; we answer in
**Part B**. Part C is our own self-review against the same checklist,
done before the meeting so the partner's time goes on what we missed.

*Partner team: ______ · Reviewers: ______ · Date: ______ · Commit / tag reviewed: `m4`*

## Part A — Partner review checklist (partner fills in)

| # | Question for the reviewer | Finding (OK / issue + detail) |
|---|---|---|
| 1 | Trace one instruction of each format (R, I, M, J, P) from `imem_data` to the state it commits. Any wire you could not follow? | |
| 2 | Point to where `flags_we` is produced. Is it high for exactly ADD SUB AND OR XOR SHL SHR CMP? | |
| 3 | Can `rf_we` ever be high for CMP, ST, OUT, JMP, Bcc, NOP, HLT? | |
| 4 | ST and OUT: is the data taken from bits 11:9 and the address from rs1? | |
| 5 | Hold `io_ready` low for 200 cycles: what stays stable, what commits, how many trace lines? | |
| 6 | Is there any `always @(*)` that does not assign every output on every path (latch risk)? | |
| 7 | Do all ten `retire_*` values describe the same instruction in the retire cycle? Flags *after*? | |
| 8 | What happens in the cycle `rst_n` is released? Can the first instruction execute twice or be skipped? | |
| 9 | Is data memory 0x00 before the first write? How, given it has no reset port? | |
| 10 | Are the unit testbenches' references independent of the RTL? Pick one and argue. | |
| 11 | Pick one design decision from `doc/design_report.md` §4 and argue for the rejected alternative. | |
| 12 | Anything in the RTL that would not synthesise, or would synthesise differently from simulation? | |

## Part B — Our written responses (team fills in after the meeting)

| # | Partner finding | Our response | Action / commit |
|---|---|---|---|
| | | | |

## Part C — Self-review before the meeting (done)

| # | Our finding | Resolution |
|---|---|---|
| 1 | All formats traced against `doc/m1/microarchitecture.md`; the Format P register (OUT) also sits in bits 11:9 and needs the same ra2 select as ST. | Implemented: `ra2 = (ST or opcode 0xE) ? rd : rs2`. Tested by T31–T35, M05, M16. |
| 2 | `flags_we = (opcode in 0x4..0xB)` in WRITEBACK only. | `tb_control_unit` checks every opcode; M11 (LD/ST writing flags) is caught. |
| 3 | `rf_we` for OUT: the control unit cannot distinguish IN from OUT. | Glue in `dsd8_cpu` kills `rf_we` for OUT (D5). T32/T35 OUT lines show `0 0 00`. |
| 5 | While stalled nothing commits; request and port held; exactly one line. | `tb_dsd8_cpu` checks this every cycle over 369 stall cycles. M08 shows conformance alone would *not* catch a design that drops and re-issues the request — the unit/system TBs do. |
| 6 | All combinational blocks have defaults before `case`. | Verilator `-Wall` clean from both roots (after fixing bug #3, where the core was not being linted at all). |
| 7 | Flags field would lag by one if taken from `flags_out` in the commit cycle. | Bypass mux (D4); M06 caught by conformance. |
| 8 | Reset release: FSM is in FETCH with all enables 0, so the first instruction cannot be skipped or doubled. | T05 line 0001 at pc 000 exactly once. |
| 9 | DMEM zero by `initial` block; does not re-clear on a second reset. | Accepted limitation, recorded as D3. |
| 12 | Board build: the core-clock divider was reset together with the core, so the core never saw reset. | Found by `tb_dsd8_top` (bug #6), fixed. |
| 13 | Spec §8.2 extract shows `140D` for `LDI R1, 13`; correct is `120D` (B.1 agrees). | Noted in the verification report; our tests use the assembler's output. |
