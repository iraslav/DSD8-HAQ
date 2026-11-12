# Makefile -- the four commands that certify this repository.
#
#   make lint         verilator --lint-only on rtl/ (no inferred latches, etc.)
#   make test         every unit testbench under tb/ (tb_*.v except tb_dsd8.v)
#   make conformance  the full conformance suite (tests/conformance/*.asm)
#   make extra        the team's own directed + random programs (tests/extra/*.asm)
#   make report       conformance + extra, results written to doc/conformance_report.txt
#   make all          lint + test + conformance + extra, in that order
#
# CI (.github/workflows/ci.yml) runs these same targets, so what passes
# here passes there. The pre-push hook (githooks/pre-push, installed by
# scripts/install_hooks.sh) runs `lint` and `test` before every push.

PYTHON ?= python3

.PHONY: all lint test conformance extra report clean

all: lint test conformance extra

lint:
	bash scripts/lint.sh

test:
	$(PYTHON) scripts/run_unit_tests.py

conformance:
	$(PYTHON) scripts/run_conformance.py

extra:
	$(PYTHON) scripts/run_conformance.py --dir tests/extra

report:
	$(PYTHON) scripts/run_conformance.py --report build/conformance_suite.txt; \
	$(PYTHON) scripts/run_conformance.py --dir tests/extra --report build/extra_suite.txt; \
	cat build/conformance_suite.txt build/extra_suite.txt > doc/conformance_report.txt

clean:
	rm -rf build
