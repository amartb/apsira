#!/usr/bin/env bash
# From relay tool/build_apk.sh @ 09b28810, with VIATICUM's APK checks and named
# failures (viaticum tool/build_apk.sh @ 78d38e0) and LYCEUM's package check
# (lyceum tool/build_apk.sh @ 9f4ff27), driven by the app's APSIRA_* settings
# (D-APK-011). The app's tool/build_apk.sh sets them and runs this file
# through `dart run apsira_tools:script_path build_apk` (README, "Scripts").
#
# Usage: build_apk.sh [--dry-run] [debug|profile]      (default: debug)
#
# Builds the dev APK on this computer, in a session too: it builds no release
# and reads no key, so the conductor runs it. Steps, each stopping the script
# with `build_apk: FAIL (<step>)` on failure:
#   1. build     flutter build apk --flavor <dev> --<mode>
#   2. merge     ./gradlew :app:process<Prod>ReleaseManifest   (in android/)
#   3. manifest  $APSIRA_MANIFEST_CHECK on the merged <prod>Release manifest
#   4. apk       each of $APSIRA_APK_CHECKS on the APK
#   5. prints `APK: <path>` and `SHA-256: <digest>`, to send with the APK
# --dry-run prints the commands instead, and needs no SDK.
#
# Settings (environment):
#   APSIRA_ROOT            the app's root (default: the current directory)
#   APSIRA_FLAVOURS        "<dev flavour> <release flavour>" (default: dev prod)
#   APSIRA_MANIFEST_CHECK  the manifest check; the merged manifest folder is
#                          its last argument (default:
#                          dart run apsira_tools:manifest_check --manifest)
#   APSIRA_APK_CHECKS      more checks, one command per line; the APK is the
#                          last argument of each (default: none)
#
# Exit codes: 0 built and checked; 1 ANDROID_HOME is missing or a step failed;
# 2 usage or settings error. test/scripts/build_apk_test.dart pins this.
set -euo pipefail

usage() {
  cat <<'EOF'
usage: build_apk.sh [--dry-run] [debug|profile]

Builds the dev flavour (flutter build apk --flavor <dev> --debug, or
--profile for timing checks on the phone), merges the release manifest
(./gradlew :app:process<Prod>ReleaseManifest) and checks it, runs the APK
checks, and prints the APK's path and SHA-256. The mode defaults to debug.
--dry-run prints the commands and runs nothing.

Needs ANDROID_HOME set to the Android SDK folder. Settings:
  APSIRA_ROOT            the app's root (default: the current directory)
  APSIRA_FLAVOURS        "<dev> <release>" flavours (default: dev prod)
  APSIRA_MANIFEST_CHECK  the merged-manifest check (default:
                         dart run apsira_tools:manifest_check --manifest)
  APSIRA_APK_CHECKS      more checks on the APK, one command per line
EOF
}

die() {
  echo "build_apk: $1" >&2
  exit "${2:-1}"
}

mode=debug
dry=false
modes=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --dry-run) dry=true ;;
    debug | profile)
      mode="$1"
      modes=$((modes + 1))
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done
[ "$modes" -le 1 ] || { usage >&2; exit 2; }

read -r -a flavours <<<"${APSIRA_FLAVOURS:-dev prod}"
[ "${#flavours[@]}" = 2 ] ||
  die "APSIRA_FLAVOURS must name two flavours, \"<dev> <release>\", got '${APSIRA_FLAVOURS:-}'." 2
dev="${flavours[0]}"
prod="${flavours[1]}"
read -r -a manifest_check <<<"${APSIRA_MANIFEST_CHECK:-dart run apsira_tools:manifest_check --manifest}"
[ "${#manifest_check[@]}" -gt 0 ] || die "APSIRA_MANIFEST_CHECK is empty." 2
apk_checks=()
while IFS= read -r line; do
  [[ "$line" =~ [^[:space:]] ]] && apk_checks+=("$line")
done <<<"${APSIRA_APK_CHECKS:-}"

if ! $dry; then
  [ -n "${ANDROID_HOME:-}" ] || die "ANDROID_HOME is not set; point it at the Android SDK folder."
  [ -d "$ANDROID_HOME" ] || die "ANDROID_HOME ($ANDROID_HOME) is not a folder; point it at the Android SDK."
fi

root="$(cd "${APSIRA_ROOT:-.}" && pwd)"
cd "$root"

# step <name> <command…> — run one step (or print it), naming it on failure.
step() {
  local name="$1"
  shift
  if $dry; then
    echo "$*"
  elif ! "$@"; then
    echo "build_apk: FAIL ($name)" >&2
    exit 1
  fi
}

merge_release_manifest() { (cd android && ./gradlew "$1"); }

apk="build/app/outputs/flutter-apk/app-$dev-$mode.apk"
merged="build/app/intermediates/merged_manifests/${prod}Release"
task=":app:process${prod^}ReleaseManifest"

$dry && echo "build_apk: dry run of the $dev $mode APK in $root; nothing is built"

step build flutter build apk --flavor "$dev" "--$mode"
$dry || [ -f "$apk" ] || die "FAIL (build): the build did not write $apk"

# After the dev APK: that build writes android/local.properties and the
# Gradle wrapper, and warms the Gradle daemon.
if $dry; then
  echo "(cd android && ./gradlew $task)"
else
  step merge merge_release_manifest "$task"
fi

step manifest "${manifest_check[@]}" "$merged"
for line in "${apk_checks[@]}"; do
  read -r -a check <<<"$line"
  step apk "${check[@]}" "$apk"
done

$dry && exit 0
if command -v sha256sum > /dev/null; then
  digest="$(sha256sum "$apk" | cut -d ' ' -f 1)"
else
  digest="$(shasum -a 256 "$apk" | cut -d ' ' -f 1)"
fi
echo "APK: $root/$apk"
echo "SHA-256: $digest"
