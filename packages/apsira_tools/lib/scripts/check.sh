#!/usr/bin/env bash
# The step runner of viaticum tool/check.sh @ 78d38e0 and lyceum tool/check.sh
# @ 9f4ff27, as a skeleton driven by the app's APSIRA_CHECK_STEPS (D-APK-011):
# the app's full host check (format, analyze, tests and the rest), each step
# run to the end whatever the others did. The app's tool/check.sh sets the
# list and runs this file through `dart run apsira_tools:script_path check`
# (README, "Scripts").
#
# Usage: check.sh [<args>…]    every argument reaches every step as "$@"
#
# APSIRA_CHECK_STEPS holds one step per line, `<name>: <command>`.
# Each step ends with `ok <name>` or `FAIL <name>`; the last line is
# `check: PASS` (exit 0), `check: FAIL (<steps>)` (exit 1) or
# `check: FAIL (settings)` (exit 2, a bad list).
# test/scripts/steps_test.dart pins this.
set -uo pipefail

case "${1:-}" in
  -h | --help)
    cat <<'USAGE'
usage: check.sh [<args>…]

Runs every step of APSIRA_CHECK_STEPS (one per line, <name>: <command>) in
APSIRA_ROOT (default: the current directory), each to the end whatever the
others did, with these arguments as "$@". The last line is the verdict:
check: PASS, or check: FAIL (<steps>).
USAGE
    exit 0
    ;;
esac

# shellcheck source=_run_steps.sh
. "$(dirname "${BASH_SOURCE[0]}")/_run_steps.sh"
run_steps check APSIRA_CHECK_STEPS "$@"
