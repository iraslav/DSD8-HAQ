#!/usr/bin/env bash
# lint.sh -- static checks on rtl/, using Verilator's lint-only mode.
#
# This is the first CI job (Section on the CI pipeline in the deck):
# it catches inferred latches, width mismatches and other synthesis
# hazards *before* anything is simulated. "No inferred latches" is a
# named criterion under Design quality in the mark allocation -- do
# not silence a real warning here, fix it.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v verilator >/dev/null 2>&1; then
    echo "verilator not found -- install it (apt-get install verilator, or see"
    echo "https://verilator.org/guide/latest/install.html) before running lint."
    exit 1
fi

# Lint from BOTH roots: dsd8_top (board build) and dsd8_cpu (the core the
# conformance harness instantiates). Linting dsd8_top alone silently skipped
# the whole core while dsd8_top was still a stub -- see doc/bug_log.md #3.
for top in dsd8_top dsd8_cpu; do
    echo "Linting rtl/*.v with: verilator --lint-only -Wall --top-module $top"
    verilator --lint-only -Wall --top-module "$top" rtl/*.v
done
echo "lint: clean"
