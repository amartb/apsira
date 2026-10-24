#!/usr/bin/env bash
# tool/test/release_sh_test.sh — proves tool/release.sh, the operator's tag act
# (D-APK-007): it refuses in a session (exit 3, one case per marker), refuses
# any precondition it does not meet (exit 1), and `--dry-run` on a clean scratch
# clone prints the check, `git tag` and `git push` lines without tagging.
#
# Every case runs on a scratch clone under ~/.army/scratch/apsira-release-test/
# (removed at exit) whose origin is a local bare repository. The last line is
# `release.sh: PASS` (exit 0) or `release.sh: FAIL` (exit 1).
set -u

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
scratch="$HOME/.army/scratch/apsira-release-test"
failed=0

rm -rf "$scratch"
mkdir -p "$scratch"
trap 'rm -rf "$scratch"' EXIT

ok() { echo "ok $*"; }
bad() {
  echo "FAIL $*"
  failed=1
}

g() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main "$@"; }

# package <tree> <name> <version>
package() {
  mkdir -p "$1/packages/$2"
  printf 'name: %s\nversion: %s\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\n' "$2" "$3" \
    >"$1/packages/$2/pubspec.yaml"
  printf '# %s changelog\n\n## %s — 2026-10-24\n\nScratch.\n' "$2" "$3" >"$1/packages/$2/CHANGELOG.md"
}

# clone <case> — a fresh clone on main, equal to its origin, two packages at 0.2.0.
clone() {
  local src="$scratch/$1-src" dst="$scratch/$1"
  mkdir -p "$src/tool"
  cp "$repo/tool/release.sh" "$repo/tool/check.sh" "$src/tool/"
  package "$src" apsira_core 0.2.0
  package "$src" apsira_ui 0.2.0
  g init -q "$src"
  g -C "$src" add -A
  g -C "$src" commit -q -m base
  g clone -q --bare "$src" "$scratch/$1.git"
  g clone -q "$scratch/$1.git" "$dst"
  echo "$dst"
}

# release <dir> <env assignment…> -- <args…> — release.sh in an environment holding
# only PATH, HOME and the given assignments; prints its output, returns its exit code.
release() {
  local dir="$1" envs=()
  shift
  while [ "$#" -gt 0 ] && [ "$1" != -- ]; do
    envs+=("$1")
    shift
  done
  shift
  (cd "$dir" && env -i PATH="$PATH" HOME="$HOME" "${envs[@]}" bash tool/release.sh "$@" 2>&1)
}

# expect <code> <label> <message pattern> <dir> <env…> -- <args…> — the exit code, and
# the output names the reason.
expect() {
  local code="$1" label="$2" pattern="$3" out rc
  shift 3
  out="$(release "$@")"
  rc=$?
  if [ "$rc" -eq "$code" ] && printf '%s\n' "$out" | grep -q -- "$pattern"; then
    ok "$label exits $code"
  else
    printf '%s\n' "$out" | tail -n 10
    bad "$label exits $rc, not $code"
  fi
}

base="$(clone base)"

# Session markers: each alone refuses with exit 3, before anything is read.
for marker in CLAUDECODE=1 AI_AGENT=x CODESPACES=true CLOUD_SHELL=true ARMY_TREE=x ARMY_TASK=T0 \
  CLAUDE_CODE_ENTRYPOINT=cli; do
  expect 3 "refusal with $marker" "refused (${marker%%=*} set)" "$base" "$marker" -- --dry-run
done
out="$(cd "$base" && env -i PATH="$PATH" HOME=/home/user bash tool/release.sh --dry-run 2>&1)"
rc=$?
if [ "$rc" -eq 3 ]; then ok "refusal with HOME=/home/user exits 3"; else bad "HOME=/home/user exits $rc, not 3"; fi

# The clean clone: the dry run prints the acts and leaves no tag.
out="$(release "$base" -- --dry-run)"
rc=$?
if [ "$rc" -eq 0 ] &&
  printf '%s\n' "$out" | grep -q '^+ bash tool/check.sh' &&
  printf '%s\n' "$out" | grep -q '^+ git tag -a apsira-v0.2.0 -m ' &&
  printf '%s\n' "$out" | grep -qx '+ git push origin apsira-v0.2.0' &&
  printf '%s\n' "$out" | grep -q '^+ consumer proof: flutter pub get .* apsira-v0.2.0' &&
  [ -z "$(git -C "$base" tag -l)" ]; then
  ok "dry run prints the check, tag, push and consumer proof, and tags nothing"
else
  printf '%s\n' "$out" | tail -n 20
  bad "dry run (exit $rc) did not print the acts, or tagged"
fi

# Preconditions: each broken alone refuses with exit 1.
dirty="$(clone dirty)"
echo x >"$dirty/untracked.txt"
expect 1 "a dirty tree" "not clean" "$dirty" -- --dry-run

branch="$(clone branch)"
g -C "$branch" switch -q -c phase/x
expect 1 "a branch other than main" "on 'phase/x'" "$branch" -- --dry-run

ahead="$(clone ahead)"
echo x >"$ahead/note.txt"
g -C "$ahead" add -A
g -C "$ahead" commit -q -m ahead
expect 1 "main ahead of origin/main" "main is not origin/main" "$ahead" -- --dry-run

unequal="$(clone unequal)"
sed -i 's/^version: .*/version: 0.2.1/' "$unequal/packages/apsira_ui/pubspec.yaml"
g -C "$unequal" commit -q -am unequal
g -C "$unequal" push -q origin main
expect 1 "unequal versions" "one version for every package" "$unequal" -- --dry-run

tagged="$(clone tagged)"
g -C "$tagged" tag -a apsira-v0.2.0 -m old
g -C "$tagged" push -q origin apsira-v0.2.0
expect 1 "an existing tag" "tag apsira-v0.2.0 exists" "$tagged" -- --dry-run

expect 64 "an unknown argument" "usage:" "$base" -- --tag

if [ "$failed" -eq 0 ]; then
  echo "release.sh: PASS"
  exit 0
fi
echo "release.sh: FAIL"
exit 1
