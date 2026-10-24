#!/usr/bin/env bash
# tool/release.sh — the operator's tag act for the Apsira packages (D-APK-007): one
# version, one tag `apsira-v<version>` for every package. Run it on your own computer,
# never in a Claude Code, agent or cloud session (it refuses, exit 3).
#
#   bash tool/release.sh            check, tag, push the tag, prove a consumer resolves it
#   bash tool/release.sh --dry-run  the same checks; print the acts instead of running them
#
# It requires a clean `main` equal to `origin/main`, every package at the same version,
# a tag that does not exist yet, and a `check: PASS` from tool/check.sh that it runs
# itself. After the push, a scratch app under ~/.army/scratch/ pins every package at the
# tag and `flutter pub get` must exit 0. Exit 0 done, 1 a precondition or act failed,
# 3 refused in a session, 64 usage.
set -u

# The session markers (the union of VIATICUM's and LYCEUM's guards, D-APK-011):
# CLAUDECODE and any CLAUDE_CODE_* (Claude Code), AI_AGENT, CODESPACES, CLOUD_SHELL,
# ARMY_TREE and ARMY_TASK (the army's gates and lanes), and HOME=/home/user (cloud
# sandboxes). Checked first, before the arguments or any file is read.
refuse_in_session() {
  local name shown markers=()
  for name in CLAUDECODE AI_AGENT CODESPACES CLOUD_SHELL ARMY_TREE ARMY_TASK \
    $(compgen -v CLAUDE_CODE_ || true); do
    if [ -n "${!name:-}" ]; then markers+=("$name set"); fi
  done
  if [ "${HOME:-}" = /home/user ]; then markers+=("HOME is /home/user"); fi
  if [ "${#markers[@]}" -gt 0 ]; then
    shown="${markers[*]:0:3}"
    [ "${#markers[@]}" -le 3 ] || shown="$shown and $((${#markers[@]} - 3)) more"
    echo "release.sh: refused ($shown): this looks like a Claude Code, agent or cloud session. Tags and pushes are operator acts; run this on your own computer." >&2
    exit 3
  fi
}
refuse_in_session

usage() { echo "usage: bash tool/release.sh [--dry-run]"; }

dry=0
case "${1:-}" in
  "") ;;
  --dry-run) dry=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root" || exit 1

url='git@github.com:amartb/apsira.git'

die() {
  echo "release.sh: $*" >&2
  exit 1
}

# act <command…> — run it, or under --dry-run print it.
act() {
  if [ "$dry" -eq 1 ]; then
    printf '+ %s\n' "$*"
  else
    "$@" || die "failed: $*"
  fi
}

version_of() {
  sed -n 's/^version:[[:space:]]*\([^[:space:]#]*\).*/\1/p' "$1" | head -n 1
}

# consumer_proof <tag> — a scratch app pins every package at the tag; pub get resolves it.
consumer_proof() {
  local tag="$1" dir="$HOME/.army/scratch/apsira-release-consumer" pubspec name status
  rm -rf "$dir"
  mkdir -p "$dir"
  {
    echo "name: apsira_release_consumer"
    echo "publish_to: none"
    echo "environment:"
    echo "  sdk: ^3.13.0"
    echo "dependencies:"
    echo "  flutter: { sdk: flutter }"
    for pubspec in packages/*/pubspec.yaml; do
      name="${pubspec#packages/}"
      name="${name%/pubspec.yaml}"
      echo "  $name: { git: { url: $url, ref: $tag, path: packages/$name } }"
    done
  } >"$dir/pubspec.yaml"
  (cd "$dir" && flutter pub get)
  status=$?
  rm -rf "$dir"
  return "$status"
}

branch="$(git symbolic-ref --short -q HEAD)" || die "HEAD is detached; check out main"
[ "$branch" = main ] || die "on '$branch'; tags are cut from main"
[ -z "$(git status --porcelain)" ] || die "the tree is not clean: commit or remove $(git status --porcelain | head -n 1)"
act git fetch --quiet --tags origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse -q --verify origin/main)" ] ||
  die "main is not origin/main; push or pull first"

version=""
for pubspec in packages/*/pubspec.yaml; do
  v="$(version_of "$pubspec")"
  [ -n "$v" ] || die "$pubspec has no version:"
  [ -z "$version" ] && version="$v"
  [ "$v" = "$version" ] || die "$pubspec says $v, the others $version: one version for every package"
done
[ -n "$version" ] || die "no package under packages/"
tag="apsira-v$version"
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  die "tag $tag exists; bump every package's version first"
fi

if [ "$dry" -eq 1 ]; then
  echo "+ bash tool/check.sh"
else
  mkdir -p "$HOME/.army/scratch"
  log="$(mktemp "$HOME/.army/scratch/apsira-release-check.XXXXXX")" || die "no scratch file for the check log"
  bash tool/check.sh 2>&1 | tee "$log"
  last="$(tail -n 1 "$log")"
  rm -f "$log"
  [ "$last" = "check: PASS" ] || die "tool/check.sh did not end with 'check: PASS'"
fi

act git tag -a "$tag" -m "Apsira packages $version"
act git push origin "$tag"
if [ "$dry" -eq 1 ]; then
  echo "+ consumer proof: flutter pub get in ~/.army/scratch/apsira-release-consumer, every package at $tag"
  echo "release.sh: dry run; nothing was tagged or pushed"
  exit 0
fi
consumer_proof "$tag" || die "the scratch consumer did not resolve $tag; the tag is pushed, fix forward"
echo "release.sh: $tag tagged, pushed and resolved by a scratch consumer"
