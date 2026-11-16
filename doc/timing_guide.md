# Cycles, timing and stages — how to show them

This guide covers the processor's clock-cycle behaviour, for the design report,
the demonstration and the oral defence: which **stage** each clock cycle is
in, the **timing** in nanoseconds, and the **numeric output** of every step.

## 1. Run it

| Where | Command | Result |
|---|---|---|
| Windows (Icarus) | `run_cycle_trace.bat T36_multiply` | table on screen + files in `build\trace\` |
| Linux / Git Bash | `make trace PROG=T36_multiply` | same |
| Any program | `run_cycle_trace.bat X04_io_slow_readback` or a path to your own `.asm` | same |

Files written to `build/trace/`:

- `cycle_trace.txt`: one line per clock cycle, plus the summary
- `cycle_trace_instructions.txt`: the start cycle, retire cycle and cycle count of every instruction
- `cycle_trace.vcd`: the waveform. Open it with
  `gtkwave build/trace/cycle_trace.vcd tb/cycle_trace.gtkw` (the `.gtkw` file
  arranges the signals in groups), or in Vivado's waveform viewer.

The viewer is `tb/cycle_trace.v`. It is not a pass/fail test, so `make test`
does not run it.

## 2. The stages (multi-cycle FSM)

Every instruction passes through 3 stages, one clock cycle each. IN/OUT add
waiting cycles while the device holds `io_ready` low.

| Stage | Cycle | What happens | What is committed at the end of the cycle |
|---|---|---|---|
| FETCH | 1 | the PC addresses instruction memory and the instruction word settles | nothing |
| EXECUTE | 2 | decoder → register reads → ALU, memory address and branch decision settle | nothing |
| WRITEBACK | 3 | commit cycle: `rf_we`, `mem_we`, `flags_we`, `pc_en`, `pc_load` and `retire` as needed | register / memory / flags / PC; one trace line |
| MEM_IO (IN/OUT only) | 3 … 3+n | the bus request is held; `MEM_IO*` = still waiting for `io_ready` | only in the cycle where `io_ready = 1` |
| HALTED | — | after HLT | nothing, ever |

```
              cycle 1     cycle 2     cycle 3
clk        __/‾‾\__/‾‾\__/‾‾\__/‾‾\__/‾‾\__
stage        FETCH      EXECUTE    WRITEBACK   FETCH (next instruction)
pc           004         004         004       005        <- PC holds until the commit edge
rf_we         0           0           1         0
retire        0           0           1         0
                                         ^ commit edge: R5 <= 00, PC <= 005, trace line
```

OUT and IN to the slow test port SLOW_ECHO (real output, T34). The port holds
`io_ready` low, so the instruction stays in MEM_IO and commits only in the
cycle where `io_ready = 1`:

```
cycle  time(ns)  stage      PC   IR    instruction     rf mem fl pc ld rdwr ret ZNCV  committed
   16      150  FETCH      005  e340  OUT 0x40, R1    0  0   0  0  0  00   0
   17      160  EXECUTE    005  e340  OUT 0x40, R1    0  0   0  0  0  00   0
   18      170  MEM_IO*    005  e340  OUT 0x40, R1    0  0   0  0  0  01   0          <- waiting
   19      180  MEM_IO*    005  e340  OUT 0x40, R1    0  0   0  0  0  01   0
   20      190  MEM_IO     005  e340  OUT 0x40, R1    0  0   0  1  0  01   1   ----   PORT 40 <= 00
   21      200  FETCH      006  ea40  IN  R5, 0x40    0  0   0  0  0  00   0
   22      210  EXECUTE    006  ea40  IN  R5, 0x40    0  0   0  0  0  00   0
   23..29  220-280  MEM_IO*  006  ea40  IN  R5, 0x40  0  0   0  0  0  10   0          <- 7 wait cycles
   30      290  MEM_IO     006  ea40  IN  R5, 0x40    1  0   0  1  0  10   1   ----   R5 <= 00
```

OUT took 5 cycles (2 waits) and IN took 10 cycles (7 waits). Nothing is
committed while waiting.

## 3. Reading the table (real output, multiply program T36)

```
cycle  time(ns)  stage      PC   IR    instruction             rf mem fl pc ld rdwr  ret  ZNCV   committed at the end of the cycle
    1        0  FETCH      000  120d  LDI R1, 0x0d            0  0   0  0  0  00    0
    2       10  EXECUTE    000  120d  LDI R1, 0x0d            0  0   0  0  0  00    0
    3       20  WRITEBACK  000  120d  LDI R1, 0x0d            1  0   0  1  0  00    1   ----   R1 <= 0d
   16      150  FETCH      005  b0a8  CMP R2, R5              0  0   0  0  0  00    0
   17      160  EXECUTE    005  b0a8  CMP R2, R5              0  0   0  0  0  00    0
   18      170  WRITEBACK  005  b0a8  CMP R2, R5              0  0   1  1  0  00    1   --C-   flags only
   21      200  WRITEBACK  006  d00a  BEQ 0x00a               0  0   0  1  0  00    1   --C-   PC <= 007
   30      290  WRITEBACK  009  c004  JMP 0x004               0  0   0  1  1  00    1   --C-   PC <= 004 (jump)
```

| Column | Meaning |
|---|---|
| cycle / time | clock-cycle number from reset release; time = (cycle − 1) × 10 ns in simulation |
| stage | FSM state in that cycle |
| PC, IR | address and instruction word (both stay the same for the whole instruction) |
| rf mem fl pc ld | `rf_we`, `mem_we`, `flags_we`, `pc_en`, `pc_load`: each commits at the end of the cycle |
| rdwr | `io_rd`, `io_wr` |
| ret | `retire`: 1 in exactly one cycle per instruction |
| ZNCV | flags **after** the instruction (as in trace field 10) |
| committed | what changed: a register, memory, an output port, a jump, or flags only |

What the defence questions are looking for:
- CMP (cycle 18): `fl = 1` and `rf = 0`. CMP writes flags but no register.
- BEQ not taken (cycle 21): `ld = 0`, so the PC goes to PC + 1.
- JMP (cycle 30): `ld = 1`, and the next FETCH is at 004.

## 4. The numbers

| Program | Instructions | Clock cycles | CPI | I/O wait cycles | Time in simulation (100 MHz) | Time on the board (25 MHz) |
|---|---|---|---|---|---|---|
| T36 multiply (13 × 7) | 51 | 153 | 3.00 | 0 | 1.53 µs | 6.12 µs |
| T34 SLOW_ECHO handshake | 241 | 1092 | 4.53 | 369 | 10.92 µs | 43.68 µs* |

\* The board has no SLOW_ECHO device, so this figure is a simulation estimate.

Formulas (the tool prints them):

- **clock cycles = 3 × instructions + I/O wait cycles** (T36: 3 × 51 + 0 = 153; T34: 3 × 241 + 369 = 1092)
- **CPI = clock cycles ÷ instructions**: exactly 3 without waiting; IN/OUT to SLOW_ECHO averaged 8.34
- **time = clock cycles × clock period**: 10 ns in simulation, 40 ns on the board (100 MHz ÷ 4, design decision D7)

The summary also gives cycles per instruction type, the final registers and
flags, and the output ports. For T36 that is LEDs = 0x5B = 91 = 13 × 7.
