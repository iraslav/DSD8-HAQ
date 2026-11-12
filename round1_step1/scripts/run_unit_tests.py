#!/usr/bin/env python3
"""
run_unit_tests.py -- runs every per-module unit testbench under tb/
(everything matching tb_*.v except tb_dsd8.v, which is the conformance
harness and is run separately by run_conformance.py).

Convention (see tb/README.md): a unit testbench prints exactly one of
    TESTBENCH: PASS
    TESTBENCH: FAIL (N errors)
on stdout before finishing. This script compiles each testbench against
every file in rtl/ (simplest thing that works for a project this size),
runs it, and greps for that line.

Exit code is non-zero if any testbench fails, is missing the expected
output line, or does not compile.
"""
import pathlib
import shutil
import subprocess
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
RTL = REPO_ROOT / "rtl"
TB_DIR = REPO_ROOT / "tb"
BUILD_DIR = REPO_ROOT / "build" / "unit"


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def main():
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    tb_files = sorted(p for p in TB_DIR.glob("tb_*.v") if p.name != "tb_dsd8.v")

    if not tb_files:
        print(f"no unit testbenches found under {TB_DIR} (expected tb_<module>.v files)")
        sys.exit(0)  # nothing to run yet is not a failure at M1

    for tool in ("iverilog", "vvp"):
        if shutil.which(tool) is None:
            print(f"error: '{tool}' is not installed or not on PATH.", file=sys.stderr)
            print("Install Icarus Verilog first, e.g.: sudo apt-get install iverilog", file=sys.stderr)
            sys.exit(3)

    # keep the program images the system testbenches load in step with their
    # sources: assemble tests/secure/*.asm into tb/data/*.hex first
    for asm in sorted((REPO_ROOT / "tests" / "secure").glob("*.asm")):
        r = run([sys.executable, str(REPO_ROOT / "tools" / "dsd8asm.py"), str(asm),
                 "-o", str(TB_DIR / "data" / (asm.stem + ".hex"))])
        if r.returncode != 0:
            print(f"error: could not assemble {asm.name}:\n{r.stdout}{r.stderr}", file=sys.stderr)
            sys.exit(2)
        # the assembler does not check the 512-word instruction memory size
        n_words = len((TB_DIR / "data" / (asm.stem + ".hex")).read_text().split())
        if n_words > 512:
            print(f"error: {asm.name} is {n_words} words; instruction memory holds 512", file=sys.stderr)
            sys.exit(2)

    rtl_sources = [str(p) for p in sorted(RTL.glob("*.v"))]
    # the reference peripheral models are needed by the system-level unit
    # testbenches (tb_dsd8_cpu.v); they are simulation-only, never linted
    rtl_sources += [str(p) for p in sorted((REPO_ROOT / "sim").glob("*.v"))]

    n_pass = 0
    results = []
    for tb_path in tb_files:
        sim_bin = BUILD_DIR / (tb_path.stem + ".vvp")
        # -s: elaborate only this testbench, not every unused top-level module
        # in rtl/ (dsd8_top, dsd8_secure_top would try to load their images)
        compile_cmd = ["iverilog", "-g2005", "-s", tb_path.stem, "-o", str(sim_bin)] + rtl_sources + [str(tb_path)]
        r = run(compile_cmd)
        if r.returncode != 0:
            results.append((tb_path.name, "ERROR", f"compile failed:\n{r.stdout}{r.stderr}"))
            continue

        r = run(["vvp", str(sim_bin)])
        output = r.stdout + r.stderr
        if "TESTBENCH: PASS" in output:
            results.append((tb_path.name, "PASS", None))
            n_pass += 1
        elif "TESTBENCH: FAIL" in output:
            fail_line = next((l for l in output.splitlines() if "TESTBENCH: FAIL" in l), "")
            results.append((tb_path.name, "FAIL", fail_line))
        else:
            results.append((tb_path.name, "ERROR",
                             "no TESTBENCH: PASS/FAIL line found -- see tb/README.md for the convention\n" + output))

    print()
    print(f"{'TESTBENCH':30s} RESULT")
    print("-" * 50)
    for name, status, detail in results:
        print(f"{name:30s} {status}")
        if detail:
            for line in detail.splitlines():
                print(f"    {line}")
    print("-" * 50)
    print(f"{n_pass} / {len(results)} passed")
    print()

    sys.exit(0 if n_pass == len(results) else 1)


if __name__ == "__main__":
    main()
