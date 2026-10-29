#!/usr/bin/env python3
"""
mutation_check.py -- measures how good the verification is, not the design.

Each mutation re-introduces one classic DSD-8 bug (spec Appendix C, guide
slide 38) into a scratch copy of the repository, then runs the unit
testbenches, the conformance suite and the extra suite. A mutation is
"killed" by a suite if that suite fails. A mutation that no suite kills is
a hole in the verification -- the closure argument in
doc/verification_report.md is built on this table.

Usage:  python3 scripts/mutation_check.py [--markdown out.md]
"""
import argparse
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent

# (id, file, original text, mutated text, description)
MUTATIONS = [
    ("M01", "rtl/control_unit.v",
     "(opcode >= OP_ADD && opcode <= OP_SHR);         // not CMP",
     "(opcode >= OP_ADD && opcode <= OP_CMP);",
     "rf_we asserted for CMP"),
    ("M02", "rtl/alu.v", "c   = sum9[8];", "c   = ~sum9[8];",
     "SUB/CMP carry = borrow (inverted convention)"),
    ("M03", "rtl/alu.v", "res = {1'b0, a[7:1]}", "res = {a[7], a[7:1]}",
     "SHR arithmetic instead of logical"),
    ("M04", "rtl/alu.v", "(a[7] == b_eff[7])", "(a[7] == b[7])",
     "overflow uses b instead of effective b (SUB V wrong)"),
    ("M05", "rtl/dsd8_cpu.v", "((opcode == OP_ST) || (opcode == OP_IO)) ? rd : rs2", "rs2",
     "Format M/P routing: read port 2 always rs2"),
    ("M06", "rtl/dsd8_cpu.v", "assign retire_flags    = flags_we ? alu_flags : flags_out;",
     "assign retire_flags    = flags_out;", "trace flags sampled before update (lag)"),
    ("M07", "rtl/dsd8_cpu.v", "assign retire_rf_addr  = rf_we  ? rd   : 3'd0;",
     "assign retire_rf_addr  = rd;", "no zero-forcing of rf_addr (R23)"),
    ("M08", "rtl/control_unit.v", "S_MEMIO:   next_state = io_ready ? S_FETCH : S_MEMIO;",
     "S_MEMIO:   next_state = S_FETCH;", "io_ready ignored for the state (no stall)"),
    ("M09", "rtl/control_unit.v", "                rf_we  = io_ready;            // commit only when the transfer completes\n                pc_en  = io_ready;\n                retire = io_ready;",
     "                rf_we  = 1'b1;\n                pc_en  = 1'b1;\n                retire = 1'b1;",
     "I/O commits without waiting for io_ready"),
    ("M10", "rtl/data_memory.v", "            mem[i] = 8'h00;", "            mem[i] = 8'hxx;",
     "data memory not cleared (R16)"),
    ("M11", "rtl/control_unit.v", "wire sets_flags  = (opcode >= OP_ADD && opcode <= OP_CMP);",
     "wire sets_flags  = (opcode >= OP_LD && opcode <= OP_CMP);", "LD and ST also write flags"),
    ("M12", "rtl/control_unit.v", "3'b010:  taken =  flag_c;", "3'b010:  taken = ~flag_c;",
     "BCS tests C = 0"),
    ("M13", "rtl/instr_decoder.v", "assign rs1    = instr[8:6];\n    assign rs2    = instr[5:3];",
     "assign rs1    = instr[5:3];\n    assign rs2    = instr[8:6];", "rs1 / rs2 slices swapped"),
    ("M14", "rtl/io_bus.v", "            default: local_rdata = 8'h00;", "            default: local_rdata = switches;",
     "unmapped low ports read the switches"),
    ("M15", "rtl/control_unit.v", "pc_en    = (opcode != OP_HLT);", "pc_en    = 1'b1;",
     "PC advances past HLT"),
    ("M16", "rtl/dsd8_cpu.v", "assign io_wdata = rd2;", "assign io_wdata = rd1;",
     "OUT sends R[rs1] instead of R[rd]"),
    ("M17", "rtl/register_file.v", "    assign rd1 = regs[ra1];", "    assign rd1 = (we && wa == ra1) ? wd : regs[ra1];",
     "write-through forwarding (violates R14)"),
    ("M18", "rtl/prog_counter.v", "pc <= pc_load ? branch_addr : pc + 9'd1;", "pc <= pc_load ? branch_addr : pc + 9'd2;",
     "PC increments by 2"),
    ("M19", "rtl/control_unit.v", "S_WB:      next_state = (opcode == OP_HLT) ? S_HALTED : S_FETCH;",
     "S_WB:      next_state = S_FETCH;", "HLT does not halt"),
    ("M20", "rtl/flags_reg.v", "        end else if (flags_we) begin", "        end else begin",
     "flags register ignores flags_we"),
]

SUITES = [("unit", ["make", "test"]), ("conformance", ["make", "conformance"]), ("extra", ["make", "extra"])]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--markdown", help="write the result table as markdown")
    args = ap.parse_args()
    rows = []
    with tempfile.TemporaryDirectory() as tmp:
        for mid, fname, old, new, desc in MUTATIONS:
            work = pathlib.Path(tmp) / mid
            shutil.copytree(ROOT, work, ignore=shutil.ignore_patterns("build", ".git"))
            f = work / fname
            text = f.read_text()
            if old not in text:
                print(f"{mid}: pattern not found in {fname} -- mutation table out of date", file=sys.stderr)
                sys.exit(2)
            f.write_text(text.replace(old, new, 1))
            killed = {}
            for name, cmd in SUITES:
                try:
                    r = subprocess.run(cmd, cwd=work, capture_output=True, text=True, timeout=90)
                    killed[name] = r.returncode != 0
                except subprocess.TimeoutExpired:
                    killed[name] = True
            rows.append((mid, desc, killed))
            print(f"{mid} {desc:48s} " + " ".join(f"{n}={'KILLED' if k else 'survived'}" for n, k in killed.items()),
                  flush=True)
    survivors = [r for r in rows if not any(r[2].values())]
    print(f"\n{len(rows) - len(survivors)} / {len(rows)} mutations killed by at least one suite")
    if args.markdown:
        out = ["| ID | Injected bug | Unit TBs | Conformance T01-T40 | Extra + random |", "|---|---|---|---|---|"]
        for mid, desc, k in rows:
            out.append(f"| {mid} | {desc} | " + " | ".join("**killed**" if k[n] else "survived" for n, _ in SUITES) + " |")
        out.append(f"\n{len(rows) - len(survivors)} / {len(rows)} mutations killed by at least one suite.")
        pathlib.Path(args.markdown).write_text("\n".join(out) + "\n")
    sys.exit(1 if survivors else 0)


if __name__ == "__main__":
    main()
