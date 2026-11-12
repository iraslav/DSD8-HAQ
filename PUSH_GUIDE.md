# Push guide — B: Hitesh Kumar

You push 47 of the project's 141 changed or new files: one third.
The eleven frozen modules keep the A/B/C split of spec §4.2; the rest of the
project is divided by subject. Each step folder mirrors the repository
layout, so copying it into the repository puts every file in the right
place. Do not rename anything: the spec freezes module and port names.

## Push order for the whole team

| Step | Who | Folder | GitHub's checks after merging |
|---|---|---|---|
| 0 | Afzal Khan (C) | `C_Afzal_Khan/step0_baseline` | lint clean; `tb_alu_example` still fails (starter's placeholder ALU, expected -- the starter's tb/README.md says so) |
| 1 | Hitesh Kumar (B) | `B_Hitesh_Kumar/round1_step1` | lint clean, 4 / 4 testbenches pass |
| 2 | Afzal Khan (C) | `C_Afzal_Khan/round1_step2` | lint clean, 7 / 7 testbenches pass |
| 3 | Abdul Qadeer (A) | `A_Abdul_Qadeer/round1_step3` | lint clean, 11 / 11 testbenches, conformance 18 / 18 -- **the processor runs** |
| 4 | Hitesh Kumar (B) | `B_Hitesh_Kumar/round2_step4` | lint clean, 12 / 12 testbenches, conformance 26 / 26 |
| 5 | Afzal Khan (C) | `C_Afzal_Khan/round2_step5` | lint clean, 14 / 14 testbenches, conformance 42 / 42 |
| 6 | Abdul Qadeer (A) | `A_Abdul_Qadeer/round2_step6` | lint clean, 19 / 19 testbenches, conformance 42 / 42, extra 17 / 17 -- **finished** |

Rules:
- Each step starts only after the previous step is **merged into `main`**
  (`git checkout main` and `git pull` first).
- This exact sequence was simulated on a fresh copy of the starter
  repository: every step gave the result shown, and after step 6 the
  repository is identical to the finished, fully tested project.
- Files the team never changed from the starter (assembler, simulator,
  harness, peripheral models, templates, `instr_memory.v`) are already in the
  repository and are not pushed by anyone.

## Your steps: 1, 4

### One-time setup (Windows Command Prompt, Git for Windows installed)
```bat
REM get the team repository -- use your team's real URL
git clone https://github.com/<organisation>/<team-repository>.git
cd <team-repository>
REM commit under YOUR name so GitHub credits you
git config user.name "Hitesh Kumar"
git config user.email "<the email of your GitHub account>"
```

### Step 1 — folder `round1_step1` (8 files)
- `rtl/alu.v`
- `rtl/register_file.v`
- `rtl/flags_reg.v`
- `tb/tb_alu_example.v`
- `tb/tb_alu_random.v`
- `tb/tb_register_file.v`
- `tb/tb_flags_reg.v`
- `scripts/run_unit_tests.py`

```bat
REM start from the latest main
git checkout main
git pull
git checkout -b B-datapath

REM copy this step's files in (change the path to where you saved the folder)
xcopy "C:\path\to\B_Hitesh_Kumar\round1_step1" . /E /Y /H /I

REM check: only this step's files may show as new or modified
git status

REM test before pushing (Icarus Verilog 12)
python scripts\run_unit_tests.py

git add -A
git commit -m "B: register_file, alu, flags_reg with self-checking and constrained-random testbenches; unit-test runner"
git push -u origin B-datapath
```
Then on GitHub: **Compare & pull request** into `main`, wait for the checks,
get the approvals CODEOWNERS asks for, **Merge**, and tell the next person.
Expected after merging: lint clean, 4 / 4 testbenches pass.

### Step 4 — folder `round2_step4` (39 files)
- `rtl/rsa_modexp.v`
- `tb/tb_rsa_modexp.v`
- `tb/data/rsa_vectors.hex`
- `tests/conformance/T15_add_carry_boundary.asm`
- `tests/conformance/T16_sub_borrow.asm`
- `tests/conformance/T17_signed_overflow.asm`
- `tests/conformance/T18_logic_flags.asm`
- `tests/conformance/T19_shift_carry.asm`
- `tests/conformance/T20_shr_logical.asm`
- `tests/conformance/T21_cmp_no_write.asm`
- `tests/conformance/T22_arithmetic_shift.asm`
- `tests/extra/R00001_random.asm`
- `tests/extra/R00002_random.asm`
- `tests/extra/R00003_random.asm`
- `tests/extra/R00007_random.asm`
- `tests/extra/R00011_random.asm`
- `tests/extra/R00042_random.asm`
- `tests/extra/R00099_random.asm`
- `tests/extra/R00123_random.asm`
- `tests/extra/R02026_random.asm`
- `tests/extra/R31337_random.asm`
- `tests/extra/X01_alu_flag_corners.asm`
- `tests/extra/X02_memory_roundtrip.asm`
- `tests/extra/X03_branch_both_sides.asm`
- `tests/extra/X04_io_slow_readback.asm`
- `tests/extra/X05_not_pseudo.asm`
- `tests/extra/X06_every_register_every_position.asm`
- `tests/extra/X07_pc_wrap.asm`
- `scripts/gen_random_program.py`
- `scripts/gen_rsa_vectors.py`
- `scripts/mutation_check.py`
- `scripts/check_enclave_keys.py`
- `doc/verification_report.md`
- `doc/mutation_results.md`
- `doc/bug_log.md`
- `doc/conformance_report.txt`
- `doc/DELIVERABLES_PLAN.md`
- `doc/defence_prep.md`
- `doc/design_review.md`

```bat
REM start from the latest main
git checkout main
git pull
git checkout -b B-verification-crypto

REM copy this step's files in (change the path to where you saved the folder)
xcopy "C:\path\to\B_Hitesh_Kumar\round2_step4" . /E /Y /H /I

REM check: only this step's files may show as new or modified
git status

REM test before pushing (Icarus Verilog 12)
python scripts\run_unit_tests.py

git add -A
git commit -m "B: RSA modexp engine, ALU conformance group T3, extra and random programs, verification scripts and reports"
git push -u origin B-verification-crypto
```
Then on GitHub: **Compare & pull request** into `main`, wait for the checks,
get the approvals CODEOWNERS asks for, **Merge**, and tell the next person.
Expected after merging: lint clean, 12 / 12 testbenches, conformance 26 / 26.

## Notes
- `tb/tb_alu_example.v` is the instructor's example testbench with the one-line Verilog-2005 fix (bug log #1).
- From step 4 you own the verification report, bug log and mutation results: keep them up to date.

## Pre-push hook
Install it only after step 6 (Git Bash: `bash scripts/install_hooks.sh`); earlier it would block pushes while other members' files are missing.

## For your oral defence
Study `doc/defence_prep.md`, section "Member B (Hitesh Kumar)".
