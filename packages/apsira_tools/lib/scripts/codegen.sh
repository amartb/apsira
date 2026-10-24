#!/usr/bin/env bash
# The step runner of relay tool/codegen.sh @ 09b28810 (and VIATICUM's and
# LYCEUM's copies), as a skeleton driven by the app's APSIRA_CODEGEN_STEPS
# (D-APK-011): gen-l10n, build_runner, the Drift schema steps and the format
# of the generated files, each step run to the end whatever the others did.
# The --check comparison (back up, regenerate, compare, restore) stays in the
# app's own step. The app's tool/codegen.sh sets the list and runs this file
# through `dart run apsira_tools:script_path codegen` (README, "Scripts").
#
# Usage: codegen.sh [<args>…]    every argument reaches every step as "$@"
#
# APSIRA_CODEGEN_STEPS holds one step per line, `<name>: <command>`.
# Each step ends with `ok <name>` or `FAIL <name>`; the last line is
# `codegen: PASS` (exit 0), `codegen: FAIL (<steps>)` (exit 1) or
# `codegen: FAIL (settings)` (exit 2, a bad list).
# test/scripts/steps_test.dart pins this.
set -uo pipefail

case "${1:-}" in
  -h | --help)
    cat <<'USAGE'
usage: codegen.sh [<args>…]

Runs every step of APSIRA_CODEGEN_STEPS (one per line, <name>: <command>) in
APSIRA_ROOT (default: the current directory), each to the end whatever the
others did, with these arguments as "$@". The last line is the verdict:
codegen: PASS, or codegen: FAIL (<steps>).
USAGE
    exit 0
    ;;
esac

# shellcheck source=_run_steps.sh
. "$(dirname "${BASH_SOURCE[0]}")/_run_steps.sh"
run_steps codegen APSIRA_CODEGEN_STEPS "$@"
