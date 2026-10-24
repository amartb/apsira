#!/usr/bin/env bash
# From relay tool/release/local_release.sh @ 09b28810, with VIATICUM's debug-key
# signing and release check (viaticum tool/release/local_release.sh @ 78d38e0,
# VIATICUM D-059) and LYCEUM's session guard, versionCode and CHANGELOG notes
# (lyceum tool/release/local_release.sh @ 9f4ff27), driven by the app's
# APSIRA_* settings (D-APK-011). The app's tool/release/local_release.sh sets
# them and runs this file through `dart run apsira_tools:script_path
# local_release` (README, "Scripts").
#
# Usage: local_release.sh [--dry-run] v<major>.<minor>.<patch>
#            [--build-number <n>] [--issues <closed-issues.json>]
#
# Builds the app's signed prod release on the operator's own computer. Before
# anything else it refuses to run in a Claude Code, agent or cloud session
# (session_guard.sh, beside this file): the release key never enters one.
# Then, in order: the settings and the tag; the SDK and the signing values;
# the checkout (HEAD is the tag, nothing tracked changed, no signing material
# tracked); the versionCode; the CHANGELOG notes (APSIRA_NOTES=changelog); the
# release check (APSIRA_RELEASE_CHECK); the prod build; the merged-manifest
# check; the certificate (release key); the release files in
# build/release/<tag>/; the notes from the closed issues (APSIRA_NOTES=issues);
# and the commands that publish them. --dry-run prints the commands of the
# build instead, and reads, builds and creates nothing. It never prints, echoes
# or logs a password: Gradle reads the four signing values from the
# environment.
#
# Exit codes: 0 built and checked (or printed); 1 an input or a step failed;
# 2 usage or settings error; 3 refused in a session (nothing read, run or
# created). test/scripts/local_release_test.dart pins this; agents never run
# it but with --dry-run, and then only in a test's clean environment.
set -euo pipefail
set +x # never trace: a traced line could show a password

# 1. Never in a session (D-APK-011). Checked before the arguments, so nothing
#    is read, built or created there, not even --help. Without the guard the
#    script refuses too.
# shellcheck source=session_guard.sh
. "$(dirname "${BASH_SOURCE[0]}")/session_guard.sh" 2> /dev/null || {
  echo "local_release: refused: session_guard.sh is missing beside this script, so a session cannot be ruled out (D-APK-011)." >&2
  exit 3
}
refuse_in_session local_release

usage() {
  cat <<'EOF'
usage: local_release.sh [--dry-run] v<major>.<minor>.<patch> [--build-number <n>] [--issues <file>]

Run it on your own computer, from a clean checkout of the release tag on
main. It refuses to run in a Claude Code, agent or cloud session. --dry-run
prints the build's commands and reads, builds and creates nothing.

Settings, set by the app's wrapper:
  APSIRA_APP                the app's name in titles and notes (required)
  APSIRA_APP_ID             the release file's stem: <id>-<x.y.z>.apk (required)
  APSIRA_ROOT               the app's root (default: the current directory)
  APSIRA_FLAVOURS           "<dev> <release>" flavours (default: dev prod)
  APSIRA_SIGNING            release-key (default) or debug-key: Gradle signs
                            with the SDK's ~/.android/debug.keystore
  APSIRA_KEY_PREFIX         release-key: the signing values are
                            <prefix>_KEYSTORE_PATH, <prefix>_KEYSTORE_PASSWORD,
                            <prefix>_KEY_ALIAS and <prefix>_KEY_PASSWORD
  APSIRA_KEY_FINGERPRINT    release-key: the certificate's SHA-256, checked
                            with apksigner verify --print-certs, or
  APSIRA_FINGERPRINT_CHECK  release-key: a command given the APK and
                            --apksigner <path>
  APSIRA_SIGNING_DOC        where signing is documented
                            (default: docs/release-signing.md)
  APSIRA_GUARD_RECORD       the app's record of the session rule
  APSIRA_VERSION_CODE       commit-count (default; --build-number overrides)
                            or version-dart: dart run tool/release/version.dart
  APSIRA_VERSION_DEFINE     a --dart-define name that receives <x.y.z>
  APSIRA_RELEASE_CHECK      a check run before the build; its last line
                            must be check: PASS
  APSIRA_MANIFEST_CHECK     the merged-manifest check (default:
                            dart run apsira_tools:manifest_check --manifest)
  APSIRA_NOTES              issues (default): CHANGELOG-<x.y.z>.md from
                            dart run tool/release/changelog.dart --tag <tag>
                            --issues <file> (gh api, or --issues); or
                            changelog: notes-<x.y.z>.md from the CHANGELOG.md
                            section, dart run tool/release/changelog.dart <tag>,
                            before the build (no section, no build)

Before running, set ANDROID_HOME to the Android SDK folder and, for a release
key, the four signing values (read the passwords with `read -rs` so they stay
out of your shell history; they are never printed).
EOF
}

die() {
  echo "local_release: $1" >&2
  exit "${2:-1}"
}

# 2. The arguments.
tag=""
build_number=""
issues=""
dry=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --dry-run) dry=true ;;
    --build-number)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      build_number="$2"
      shift
      ;;
    --issues)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      issues="$2"
      shift
      ;;
    -*)
      usage >&2
      exit 2
      ;;
    *)
      [ -z "$tag" ] || { usage >&2; exit 2; }
      tag="$1"
      ;;
  esac
  shift
done

# 3. The settings.
app="${APSIRA_APP:-}"
app_id="${APSIRA_APP_ID:-}"
[ -n "$app" ] || die "set APSIRA_APP (the app's name) in the wrapper." 2
[[ "$app_id" =~ ^[a-z][a-z0-9_-]*$ ]] || die "set APSIRA_APP_ID (the release file's stem, lower case) in the wrapper." 2
signing="${APSIRA_SIGNING:-release-key}"
signing_doc="${APSIRA_SIGNING_DOC:-docs/release-signing.md}"
case "$signing" in
  release-key | debug-key) ;;
  *) die "APSIRA_SIGNING must be release-key or debug-key, got '$signing'." 2 ;;
esac
read -r -a flavours <<<"${APSIRA_FLAVOURS:-dev prod}"
[ "${#flavours[@]}" = 2 ] ||
  die "APSIRA_FLAVOURS must name two flavours, \"<dev> <release>\", got '${APSIRA_FLAVOURS:-}'." 2
prod="${flavours[1]}"
read -r -a manifest_check <<<"${APSIRA_MANIFEST_CHECK:-dart run apsira_tools:manifest_check --manifest}"
[ "${#manifest_check[@]}" -gt 0 ] || die "APSIRA_MANIFEST_CHECK is empty." 2
version_code_from="${APSIRA_VERSION_CODE:-commit-count}"
case "$version_code_from" in
  commit-count) ;;
  version-dart)
    [ -z "$build_number" ] || die "--build-number needs APSIRA_VERSION_CODE=commit-count; the tag gives the versionCode." 2
    ;;
  *) die "APSIRA_VERSION_CODE must be commit-count or version-dart, got '$version_code_from'." 2 ;;
esac
if [ -n "$build_number" ] && ! [[ "$build_number" =~ ^[1-9][0-9]*$ ]]; then
  die "--build-number must be a positive integer" 2
fi
notes_from="${APSIRA_NOTES:-issues}"
case "$notes_from" in
  issues) ;;
  changelog) [ -z "$issues" ] || die "--issues needs APSIRA_NOTES=issues." 2 ;;
  *) die "APSIRA_NOTES must be issues or changelog, got '$notes_from'." 2 ;;
esac
key_names=()
fingerprint="${APSIRA_KEY_FINGERPRINT:-}"
fingerprint_check=()
if [ "$signing" = release-key ]; then
  prefix="${APSIRA_KEY_PREFIX:-}"
  [[ "$prefix" =~ ^[A-Z][A-Z0-9_]*$ ]] ||
    die "set APSIRA_KEY_PREFIX (the signing values' prefix, upper case) for a release key." 2
  key_names=("${prefix}_KEYSTORE_PATH" "${prefix}_KEYSTORE_PASSWORD" "${prefix}_KEY_ALIAS" "${prefix}_KEY_PASSWORD")
  read -r -a fingerprint_check <<<"${APSIRA_FINGERPRINT_CHECK:-}"
  if [ -n "$fingerprint" ] && [ "${#fingerprint_check[@]}" -gt 0 ]; then
    die "set APSIRA_KEY_FINGERPRINT or APSIRA_FINGERPRINT_CHECK, not both." 2
  fi
  if [ -z "$fingerprint" ] && [ "${#fingerprint_check[@]}" = 0 ]; then
    die "a release key needs its certificate check: set APSIRA_KEY_FINGERPRINT or APSIRA_FINGERPRINT_CHECK." 2
  fi
  if [ -n "$fingerprint" ] && ! [[ "$fingerprint" =~ ^[0-9a-f]{64}$ ]]; then
    die "APSIRA_KEY_FINGERPRINT must be the certificate's SHA-256 in lower-case hex, as apksigner prints it." 2
  fi
fi

# 4. The tag.
if ! [[ "$tag" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  usage >&2
  die "the tag must be v<major>.<minor>.<patch>, got '${tag}'" 2
fi
version="${tag#v}"

$dry && echo "local_release: dry run of $tag for $app; nothing is read, built or created"

# 5. Inputs: the SDK and the signing values, named but never shown.
if ! $dry; then
  [ -n "${ANDROID_HOME:-}" ] || die "ANDROID_HOME is not set; point it at the Android SDK folder."
  [ -d "$ANDROID_HOME" ] || die "ANDROID_HOME ($ANDROID_HOME) is not a folder."
  missing=()
  for name in "${key_names[@]}"; do
    if [ -z "${!name:-}" ]; then missing+=("$name"); fi
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    die "set ${missing[*]} first ($signing_doc)."
  fi
  [ "${#key_names[@]}" = 0 ] || export "${key_names[@]}"
fi

root="$(cd "${APSIRA_ROOT:-.}" && pwd -P)"
if ! $dry && [ "${#key_names[@]}" -gt 0 ]; then
  keystore="${key_names[0]}"
  [ -f "${!keystore}" ] || die "$keystore does not name a file."
  keystore_dir="$(cd "$(dirname "${!keystore}")" && pwd -P)"
  case "$keystore_dir/" in
    "$root"/*) die "the keystore must live outside the repository ($signing_doc)." ;;
  esac
fi

# 6. The checkout: HEAD is the tagged commit, nothing tracked is changed and
#    no signing material is tracked.
cd "$root"
if ! $dry; then
  tagged="$(git rev-parse -q --verify "refs/tags/$tag^{commit}" || true)"
  [ -n "$tagged" ] || die "no tag $tag in this checkout; tag the release commit on main first."
  [ "$tagged" = "$(git rev-parse HEAD)" ] || die "HEAD is not $tag; check out the tag first."
  [ -z "$(git status --porcelain --untracked-files=no)" ] || die "tracked files have changes; release from a clean checkout."
  tracked="$(git ls-files '*.jks' '*.keystore' '*.p12' '*key.properties')"
  [ -z "$tracked" ] || die "signing material is tracked; remove it from git: $tracked"
fi

# 7. The versionCode: the commit count of HEAD (or --build-number), or
#    single-sourced from the tag by the app's tool/release/version.dart.
if [ -n "$build_number" ]; then
  version_code="$build_number"
elif $dry; then
  [ "$version_code_from" = commit-count ] || echo "dart run tool/release/version.dart $tag"
  version_code='<versionCode>'
elif [ "$version_code_from" = commit-count ]; then
  version_code="$(git rev-list --count HEAD)"
else
  version_code="$(dart run tool/release/version.dart "$tag" | tail -n 1)" || version_code=""
  [[ "$version_code" =~ ^[1-9][0-9]*$ ]] || die "tool/release/version.dart gave no versionCode for $tag."
fi
$dry || echo "local_release: $tag is version $version, versionCode $version_code"

dist="build/release/$tag"
$dry || { rm -rf "$dist" && mkdir -p "$dist"; }

# 8. CHANGELOG notes, before anything is built (no section, no release).
#    `dart run` may print its own lines first, so the notes are kept from
#    their `# <app>` title on.
if [ "$notes_from" = changelog ]; then
  notes="$dist/notes-$version.md"
  if $dry; then
    echo "dart run tool/release/changelog.dart $tag"
  elif ! dart run tool/release/changelog.dart "$tag" | sed -n "/^# $app /,\$p" > "$notes" ||
    ! [ -s "$notes" ]; then
    rm -rf "$dist"
    die "CHANGELOG.md has no notes for $version; give the release its ## [$version] section first (no section, no release)."
  else
    echo "local_release: notes in $notes"
  fi
fi

# 9. The release check; its last line decides.
if [ -n "${APSIRA_RELEASE_CHECK:-}" ]; then
  read -r -a release_check <<<"$APSIRA_RELEASE_CHECK"
  if $dry; then
    echo "${release_check[*]}"
  else
    "${release_check[@]}" 2>&1 | tee "$dist/check.log" || true
    [ "$(tail -n 1 "$dist/check.log")" = "check: PASS" ] ||
      die "${release_check[*]} did not end with check: PASS; see $dist/check.log."
  fi
fi

# run <command…> — run it, or print it in a dry run.
run() {
  if $dry; then echo "$*"; else "$@"; fi
}

# 10. Build, then check the merged release manifest and the certificate.
build=(flutter build apk --flavor "$prod" --release --build-name "$version" --build-number "$version_code")
[ -z "${APSIRA_VERSION_DEFINE:-}" ] || build+=("--dart-define=$APSIRA_VERSION_DEFINE=$version")
run "${build[@]}"

run "${manifest_check[@]}" "build/app/intermediates/merged_manifests/${prod}Release"

apk="build/app/outputs/flutter-apk/app-$prod-release.apk"
$dry || [ -f "$apk" ] || die "the build did not write $apk"
if [ "$signing" = release-key ]; then
  if $dry; then
    apksigner='<ANDROID_HOME>/build-tools/<newest>/apksigner'
  else
    # The newest build-tools, by numeric version (portable: no sort -V).
    tools="$(for dir in "$ANDROID_HOME"/build-tools/*/; do
      if [ -d "$dir" ]; then basename "$dir"; fi
    done | sort -t . -k 1,1n -k 2,2n -k 3,3n | tail -n 1)"
    [ -n "$tools" ] || die "no build-tools in $ANDROID_HOME; install them with sdkmanager."
    apksigner="$ANDROID_HOME/build-tools/$tools/apksigner"
  fi
  if [ "${#fingerprint_check[@]}" -gt 0 ]; then
    run "${fingerprint_check[@]}" "$apk" --apksigner "$apksigner"
  elif $dry; then
    echo "$apksigner verify --print-certs $apk"
  else
    certs="$("$apksigner" verify --print-certs "$apk")" ||
      die "apksigner could not verify $apk; it is not signed, or not signed correctly."
    digests="$(printf '%s\n' "$certs" | sed -n 's/^Signer #[0-9]* certificate SHA-256 digest: *//p')"
    count="$(printf '%s\n' "$digests" | grep -c . || true)"
    [ "$count" = 1 ] || die "the APK has $count signer certificates; a release has exactly one."
    [ "$digests" = "$fingerprint" ] ||
      die "the APK's certificate SHA-256 is $digests, not $app's release certificate ($signing_doc); check ${key_names[0]}."
    echo "local_release: signed by $app's release certificate"
  fi
elif ! $dry; then
  echo "local_release: signed with this computer's SDK debug key (~/.android/debug.keystore); keep it backed up ($signing_doc)"
fi

# 11. The release files.
name="$app_id-$version.apk"
if ! $dry; then
  cp "$apk" "$dist/$name"
  if command -v sha256sum > /dev/null; then
    (cd "$dist" && sha256sum "$name" > "$name.sha256")
  else
    (cd "$dist" && shasum -a 256 "$name" > "$name.sha256")
  fi
fi

# 12. Notes from the closed issues (gh api, or the file given with --issues).
assets="$dist/$name $dist/$name.sha256"
if [ "$notes_from" = issues ]; then
  notes="$dist/CHANGELOG-$version.md"
  assets="$assets $notes"
  if [ -z "$issues" ]; then
    issues="$dist/closed-issues.json"
    if $dry; then
      echo "gh api --paginate --slurp repos/{owner}/{repo}/issues?state=closed&per_page=100"
    else
      gh api --paginate --slurp \
        'repos/{owner}/{repo}/issues?state=closed&per_page=100' > "$issues"
    fi
  fi
  if $dry; then
    echo "dart run tool/release/changelog.dart --tag $tag --issues $issues"
  else
    dart run tool/release/changelog.dart --tag "$tag" --issues "$issues" > "$notes"
  fi
fi
$dry && exit 0

# 13. How to publish: the operator's act, from this computer.
cat <<EOF
Release $tag built, signed and checked in $root/$dist:
  $name
  $name.sha256
  ${notes##*/}

To publish it as a private GitHub Release, check that the repository is
private (the command prints PRIVATE), push the tag, then create the release
with the files and the notes:
  gh repo view --json visibility --jq .visibility
  git push origin $tag
  gh release create $tag --verify-tag --title "$app $version" --notes-file $notes $assets
EOF
