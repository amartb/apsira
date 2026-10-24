# Sourced by check.sh and codegen.sh, never run: `run_steps <label> <setting>
# <args…>` runs the app's step list the way the Apsira repository's
# tool/check.sh runs its steps (D-APK-011). Every step runs whatever the
# others did, so one failure never hides another; its output is shown as it
# comes, then `ok <step>` or `FAIL <step>`. The last line is the verdict,
# `<label>: PASS` (exit 0) or `<label>: FAIL (<steps>)` (exit 1); a bad step
# list is `<label>: FAIL (settings)` (exit 2). Callers read the last line.
#
# The step list is the setting's value, one step per line, `<name>: <command>`
# (blank lines and `#` lines are skipped). Each command runs in its own
# `bash -c`, in APSIRA_ROOT (default: the current directory), with the
# script's arguments as "$@", so `--long` or `--check` reaches every step.

run_steps() {
  local label="$1" setting="$2" line name command
  shift 2
  local names=() commands=() failed=()
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
    if ! [[ "$line" =~ ^[[:space:]]*([A-Za-z0-9_.-]+):[[:space:]]*(.*[^[:space:]])[[:space:]]*$ ]]; then
      echo "$label: $setting: '$line' is not '<name>: <command>'" >&2
      echo "$label: FAIL (settings)"
      exit 2
    fi
    name="${BASH_REMATCH[1]}"
    command="${BASH_REMATCH[2]}"
    if [[ " ${names[*]} " == *" $name "* ]]; then
      echo "$label: $setting names the step $name twice" >&2
      echo "$label: FAIL (settings)"
      exit 2
    fi
    names+=("$name")
    commands+=("$command")
  done <<<"${!setting:-}"
  if [ "${#names[@]}" = 0 ]; then
    echo "$label: $setting holds no step; the app's wrapper sets it" >&2
    echo "$label: FAIL (settings)"
    exit 2
  fi

  cd "${APSIRA_ROOT:-.}" || exit 1
  local i
  for i in "${!names[@]}"; do
    echo "== $label: ${names[$i]}"
    if bash -c "${commands[$i]}" "$label" "$@" 2>&1; then
      echo "ok ${names[$i]}"
    else
      echo "FAIL ${names[$i]}"
      failed+=("${names[$i]}")
    fi
  done
  if [ "${#failed[@]}" -gt 0 ]; then
    local list
    list="$(printf '%s, ' "${failed[@]}")"
    echo "$label: FAIL (${list%, })"
    exit 1
  fi
  echo "$label: PASS"
}
