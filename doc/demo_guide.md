# Demonstration guide (M6, spec §9.3 item 5)

Requirement: the processor running **at least two T6 integration programs**,
with the result visible on LEDs, the seven-segment display or a terminal.

## Programs and what the board shows

| Program | Build `IMAGE` | LEDs LD7..LD0 | 7-seg | LD15 (halted) |
|---|---|---|---|---|
| T36 multiply 13 × 7 | `T36_multiply.hex` | `0101 1011` = 0x5B (91) | blank | on |
| T37 popcount of 0xB7 | `T37_popcount.hex` | `0000 0110` = 6 | blank | on |
| T38 bubble sort | `T38_bubble_sort.hex` | `0000 0001` (smallest) | `9` on digit 0 (largest) | on |
| T39 max / min | `T39_max_min.hex` | `1111 1110` = 0xFE (max) | `00` on digits 1–0 (min) | on |
| Self-test: buttons echo | `tb/data/buttons_echo.hex` | follows the buttons {U,D,L,R,C} | blank | off (never halts) |

T36, T37 and T38 are the recommended programs for the demonstration. T36 and
T38 are simulated end-to-end on `dsd8_top` by `tb/tb_dsd8_top.v`
(together with the buttons echo).

## Building the bitstream (Vivado, Basys 3 assumed)

1. `make conformance` — produces `build/conformance/<test>.hex` for every test.
2. New RTL project, part `xc7a35tcpg236-1`. Add every file in `rtl/` (not `sim/`, not `tb/`).
   Top module `dsd8_top`. Add constraints `fpga/basys3.xdc`.
3. Copy the chosen `.hex` into the project directory (or use an absolute path) and set the
   generic/parameter `IMAGE` of `dsd8_top` in *Settings → General → Generics/Parameters*,
   e.g. `IMAGE="T36_multiply.hex"`. Add the `.hex` to the project as a memory-initialisation
   file so synthesis can find it.
4. Synthesise, implement, check *Report Timing Summary*: the core runs on the generated
   25 MHz `cpu_clk` (decision D7). If the `create_generated_clock` line warns that
   `cpu_clk_reg/Q` was not found, use the name shown by `get_cells -hier *cpu_clk*`.
5. Generate the bitstream and program the board.

## Running it

1. SW15 **down** = reset. Set SW0–SW7 as needed (only programs that `IN 0x00` read them).
2. SW15 **up** = run. The programs finish in microseconds; LD15 lights when HLT retires.
3. To re-run: SW15 down, then up. (Data memory is *not* re-cleared by a second reset —
   decision D3 — so re-run programs that read never-written memory after reprogramming.
   T36/T37/T38/T39 write before they read, so they re-run correctly.)

## Script for the demo (two minutes)

1. Show `make all` passing (lint, 12 unit testbenches, 42 conformance, 17 extra).
2. Program T36: LEDs show 0x5B = 91 = 13 × 7; point at LD15 (halted).
3. Program T38: LEDs show 1, display shows 9 — smallest and largest of the sorted array.
4. Open `build/conformance/T38_bubble_sort.dut.trace` next to the `.gold.trace`: identical,
   518 lines.
