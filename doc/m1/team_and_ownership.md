# M1 — Team and module ownership agreement

Spec §4.2 / R12: ownership is examined individually at the oral defence, so it
is agreed here in writing. Replace the placeholders with real names and GitHub
usernames, then mirror the usernames in `.github/CODEOWNERS`.

| Role | Name | Student ID | GitHub username | Signature / date |
|---|---|---|---|---|
| Member A — Fetch & decode (+ shared integration, extension) | Abdul Qadeer | _______ | `@memberA` | _______ |
| Member B — Datapath | Hitesh Kumar | _______ | `@memberB` | _______ |
| Member C — Control, memory & I/O | Afzal Khan | _______ | `@memberC` | _______ |

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

## Who pushes which files (see PUSH_GUIDE.md in each member's folder)

The eleven frozen modules keep the A/B/C split of spec §4.2. Everything else
(shared core, board support, the RSA-enclave extension, test programs,
scripts, CI and documentation) is divided by subject so each member owns
about a third of the repository: 47 files each.

| Member | Round 1 — own spec modules | Round 2 — share of everything else |
|---|---|---|
| A — Abdul Qadeer | `prog_counter`, `instr_decoder` (+ supplied `instr_memory`), shared `dsd8_cpu` integration, their testbenches, conformance groups T1 + T4, `run_conformance.py` | enclave + debugger (`rsa_enclave`, `dsd8_secure_top`), 5 system testbenches, `tests/secure`, design report, microarchitecture, enclave docs, README |
| B — Hitesh Kumar | `register_file`, `alu`, `flags_reg`, their testbenches, `run_unit_tests.py` | `rsa_modexp` engine + testbench, conformance group T3, all extra/random programs, verification scripts, verification report, bug log, mutation results, defence prep, design review |
| C — Afzal Khan | `data_memory`, `control_unit`, `io_bus`, their testbenches | shared `dsd8_top` board top, 7-seg + debouncer, `cpu_mailbox` + testbenches, conformance groups T2, T5, T6, Makefile, lint, CI, FPGA pins, control-signal table, demo guide |

Push order (each step after the previous one is merged; CI stays green):
**C0 → B1 → C1 → A1 → B2 → C2 → A2**.

## Working agreement

1. Interfaces in spec §5 are frozen; nobody changes another member's port list.
2. Branch per module/feature; PR into `main`; the owner approves (CODEOWNERS).
3. Every bug found gets a row in `doc/bug_log.md` the same day, with an honest *found by*.
4. Every bug fixed gets a test that would have caught it.
5. Milestone commits are tagged (`m1` … `m5`, `final`); grading reads the tag.
6. Shared integration decisions (glue in `dsd8_cpu`) are recorded in `doc/design_report.md` §4.
