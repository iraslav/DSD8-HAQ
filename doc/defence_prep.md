# Oral defence preparation (M6)

Ten minutes per member, no notes (spec §9.3 item 6). The defence *multiplies*
your share of the team marks (0.4–1.0), so every member must be able to trace
a signal through their own modules **and** explain the system. Study this,
then close it and explain each answer aloud from the RTL.

## 1. Answers to the published sample questions (§9.4)

**"Point to the logic that produces `flags_we`. Walk me from the instruction word to that signal."**
`imem_data[15:12]` → `instr_decoder.opcode` (plain slice) → `control_unit`:
`sets_flags = (opcode >= 4'h4 && opcode <= 4'hB)` → in the output block,
`flags_we = sets_flags` **only in state S_WB**; 0 in every other state. It
drives `flags_reg.flags_we`, and also selects `retire_flags` between the ALU's
new flags and `flags_out` in `dsd8_cpu`.

**"What happens if `io_ready` goes low for two hundred cycles? Show me where your design waits."**
`control_unit`, state `S_MEMIO`: `next_state = io_ready ? S_FETCH : S_MEMIO`.
While waiting: `io_rd`/`io_wr` stay 1, `io_port` (= decoder `port`) and
`io_wdata` (= `rd2`) are stable because the PC — hence the instruction — does
not move; `rf_we`, `pc_en`, `retire` are `io_ready` = 0; `mem_we`, `flags_we`
are 0. So no architectural state changes and no trace line is written for
200 cycles; in the cycle `io_ready` = 1 the instruction commits and retires
once. `tb_dsd8_cpu.v` checks exactly this on every stall cycle.

**"Why does CMP not write a register? What did you have to do differently to achieve that?"**
CMP is architecturally "SUB without the write" (§3.4.2). The ALU computes the
same subtraction for opcode 0xB; the difference is only in the control unit:
`writes_reg` covers LDI, LD and 0x4–0xA but **not** 0xB, while `sets_flags`
covers 0x4–0xB. Writing R[rd] would clobber R0 (CMP's rd field is 000) —
the "register corrupted several instructions later" symptom. T21 checks the
rf fields are `0 0 00` and that R0 survives; mutation M01 is caught by all suites.

**"Your trace showed the right value one instruction late. How did you find that, and what was it?"**
Two candidate causes (guide slide 38): retire sampled a cycle late, or flags
taken from `flags_reg` before it updates. Our design retires in the commit
cycle, where `flags_out` still holds the *previous* flags because
`flags_reg` updates at the same edge the harness samples. Fix: `retire_flags
= flags_we ? alu_flags : flags_out` (decision D4). Mutation M06 reproduces
the bug: the diff's first differing line is a flag-setting instruction whose
field 10 equals the line above's — caught by conformance on the first ALU
test, while every other field is correct. Method: first differing line →
name the field → open the waveform only at that instruction's retire cycle.

**"I want to add an ADDI instruction. Do not write code — tell me every module you would touch and what would break."**
All 16 opcodes are used, but Format I bit 8 is reserved and 0 for LDI, so
`0001 ddd 1 iiiiiiii` is free. Touch: `dsd8_cpu` glue (ALU `op` forced to
ADD and `b` = `imm8` when opcode 1 & bit 8; `wb_sel` = ALU; `flags_we`
qualified like `io_dir` because `control_unit` cannot see bit 8);
`control_unit` port list is frozen so it cannot be the place; `alu` unchanged;
`instr_decoder` unchanged (bit 8 is already `io_dir`); assembler and golden
simulator; unit TBs and new conformance tests. Break: anything relying on R10
reserved-bit-zero for LDI; the trace format is unchanged.

**"Show me the coverage bin that proves you tested signed overflow, and tell me what it does not prove."**
`tb_alu_random.v` flag-coverage table: ADD V = 1 observed 2 746 times, SUB
2 736, CMP 2 809; corner cross bin 0x7F × 0x01 hit for ADD (the textbook
overflow). It proves the ALU computes V correctly on those operands. It does
**not** prove that V reaches the branch logic (that is T17, T24/T25 BVS/BVC,
T29), that V is preserved by non-flag instructions (T27, T35), or anything
about operand pairs that random sampling never produced.

## 2. Per-member topics

### Member A — `prog_counter`, `instr_memory`, `instr_decoder`
- Why 9 bits; what `pc + 1` does at 0x1FF (X07 wraps to 0x000).
- What `pc_en` does in the cycle reset is released (FSM in FETCH → 0, so line 0001 is pc 000 exactly once).
- Why the PC holds for three cycles (D2) and why there is no IR register.
- The decoder never looks at the opcode — explain each overlap (rd = cond, imm8 = port, rs1 ⊂ addr9).
- What `$readmemh` does with a short image (rest X) and why every program ends in HLT.
- Your testbenches: the exhaustive decoder check and why it uses div/mod instead of slices.

### Member B — `register_file`, `alu`, `flags_reg`
- R14: why no write-through; why it would form a combinational loop in our FSM (M17).
- The single 9-bit adder; `b_eff`; why C = 1 means "no borrow"; why V uses `b_eff`.
- SHR vs arithmetic shift; how T22 builds ASR from SHR/AND/OR.
- Flag bit order {Z,N,C,V} in every place it appears.
- Your random test: seed, constraint, reference style, the coverage table, M04 caught by random but not directed.

### Member C — `control_unit`, `data_memory`, `io_bus`
- Draw the FSM; for any opcode, give every output in every state.
- Mealy terms: `pc_load` (flags) and the I/O commit (`io_ready`) — why (D6).
- How IN vs OUT is resolved without `io_dir` on your ports (D5).
- DMEM zero without a reset port (D3) and its limitation.
- `io_bus`: local vs forwarded ports, R20, what an unmapped port does, why LEDs only change at the completing edge.
- M08: why conformance passes a design that drops the request mid-transfer, and which of your testbenches catches it.

### Everyone — the system
- Walk ST [R3], R0 through the datapath (address = R[rs1] via rd1, data = R[rd] via ra2 select → rd2).
- What each of the ten trace fields comes from (`dsd8_cpu` glue 4) and why fields 5/6/8/9 are zero-forced.
- The bug log: which bugs cost minutes and which cost more, and how each was found.
- The ISA cost argument from design report §5.
