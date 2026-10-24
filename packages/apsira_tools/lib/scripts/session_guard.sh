# From lyceum tool/release/session_guard.sh @ 9f4ff27
# Sourced by the release scripts, never run: the one list of session markers
# (D-APK-011, and the app's own record in APSIRA_GUARD_RECORD).
# `refuse_in_session <script name>` exits 3 when any marker is present, so the
# release key never enters a Claude Code, agent or cloud session. Each release
# script calls it first, before its arguments, its settings or any file is
# read. test/scripts/session_guard_test.dart pins it, one test per marker.
#
# The markers: CLAUDECODE and any CLAUDE_CODE_* (Claude Code), AI_AGENT,
# CODESPACES, CLOUD_SHELL, ARMY_TREE and ARMY_TASK (the army's gates and
# lanes), and HOME=/home/user (cloud sandboxes).

refuse_in_session() {
  local script="$1" name shown
  local markers=()
  for name in CLAUDECODE AI_AGENT CODESPACES CLOUD_SHELL ARMY_TREE ARMY_TASK \
    $(compgen -v CLAUDE_CODE_ || true); do
    if [ -n "${!name:-}" ]; then markers+=("$name set"); fi
  done
  if [ "${HOME:-}" = /home/user ]; then markers+=("HOME is /home/user"); fi
  if [ "${#markers[@]}" -gt 0 ]; then
    shown="${markers[*]:0:3}"
    [ "${#markers[@]}" -le 3 ] || shown="$shown and $((${#markers[@]} - 3)) more"
    echo "$script: refused ($shown): this looks like a Claude Code, agent or cloud session. The release key never enters one (D-APK-011${APSIRA_GUARD_RECORD:+, $APSIRA_GUARD_RECORD}); run this on your own computer." >&2
    exit 3
  fi
}
