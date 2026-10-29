# M1 — Team and module ownership agreement

Spec §4.2 / R12: ownership is examined individually at the oral defence, so it
is agreed here in writing. Replace the placeholders with real names and GitHub
usernames, then mirror the usernames in `.github/CODEOWNERS`.

| Role | Name | Student ID | GitHub username | Signature / date |
|---|---|---|---|---|
| Member A — Fetch & decode | _______ | _______ | `@memberA` | _______ |
| Member B — Datapath | _______ | _______ | `@memberB` | _______ |
| Member C — Control, memory & I/O | _______ | _______ | `@memberC` | _______ |

## Module ownership (frozen names, §4.2)

| Module / file | Owner | Responsibility | Unit testbench (owner writes) |
|---|---|---|---|
| `rtl/prog_counter.v` | A | 9-bit PC, hold / increment (wraps) / load | `tb/tb_prog_counter.v` |
| `rtl/instr_memory.v` | A | 512×16 ROM, `$readmemh(IMAGE)` | `tb/tb_instr_memory.v` |
| `rtl/instr_decoder.v` | A | combinational field slicing | `tb/tb_instr_decoder.v` |
| `rtl/register_file.v` | B | 8×8, 2 read / 1 write, reset clear | `tb/tb_register_file.v` |
| `rtl/alu.v` | B | 8 ops, single 9-bit adder, Z N C V | `tb/tb_alu_example.v`, `tb/tb_alu_random.v` |
| `rtl/flags_reg.v` | B | architectural Z N C V | `tb/tb_flags_reg.v` |
| `rtl/data_memory.v` | C | 256×8 RAM, zero at start | `tb/tb_data_memory.v` |
| `rtl/control_unit.v` | C | multi-cycle FSM, control table | `tb/tb_control_unit.v` |
| `rtl/io_bus.v` | C | port decode, `io_ready` handshake | `tb/tb_io_bus.v` |
| `rtl/dsd8_cpu.v` | shared | integration + glue + retire | `tb/tb_dsd8_cpu.v` + conformance |
| `rtl/dsd8_top.v` (+ `seg7_driver.v`, `btn_debounce.v`) | shared | board top level | `tb/tb_dsd8_top.v` |

## Working agreement

1. Interfaces in spec §5 are frozen; nobody changes another member's port list.
2. Branch per module/feature; PR into `main`; the owner approves (CODEOWNERS).
3. Every bug found gets a row in `doc/bug_log.md` the same day, with an honest *found by*.
4. Every bug fixed gets a test that would have caught it.
5. Milestone commits are tagged (`m1` … `m5`, `final`); grading reads the tag.
6. Shared integration decisions (glue in `dsd8_cpu`) are recorded in `doc/design_report.md` §4.
