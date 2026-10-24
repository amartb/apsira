#!/usr/bin/env bash
# tool/check.sh — the full check of the Apsira packages. There is no CI: this script is
# the release check (packages/README.md, "Releasing") and the `check` gate.
#
# Every step runs on its own, whatever the steps before it did, and prints `ok <step>`
# or, after the tail of its output, `FAIL <step>`. The last line is exactly
# `check: PASS` (exit 0) or `check: FAIL` (exit 1).
#
#   bash tool/check.sh            every step
#   bash tool/check.sh --release  only the shared-tag release rules (D-APK-007)
set -u

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root" || exit 1

mode=full
case "${1:-}" in
  "") ;;
  --release) mode=release ;;
  *)
    echo "usage: bash tool/check.sh [--release]" >&2
    exit 64
    ;;
esac

# The one repository every apsira dependency names (D-APK-007).
url='git@github.com:amartb/apsira.git'

failed=0

# step <name> <command…> — run one step, print its verdict, keep going.
step() {
  local name="$1" out
  shift
  if out="$("$@" 2>&1)"; then
    echo "ok $name"
  else
    printf '%s\n' "$out" | tail -n 60
    echo "FAIL $name"
    failed=1
  fi
}

# in_dir <dir> <command…>
in_dir() {
  local dir="$1"
  shift
  (cd "$dir" && "$@")
}

# Every package, and every package's example/, by its pubspec.
packages=()
for pubspec in packages/*/pubspec.yaml; do
  [ -f "$pubspec" ] && packages+=("${pubspec%/pubspec.yaml}")
done
examples=()
for pubspec in packages/*/example/pubspec.yaml; do
  [ -f "$pubspec" ] && examples+=("${pubspec%/pubspec.yaml}")
done

version_of() {
  sed -n 's/^version:[[:space:]]*\([^[:space:]#]*\).*/\1/p' | head -n 1
}

# The shared version is the first package's; `versions equal` fails on any other.
version=""
[ "${#packages[@]}" -gt 0 ] && version="$(version_of <"${packages[0]}/pubspec.yaml")"
tag="apsira-v$version"

# apsira_deps <pubspec> <sections regex> — "<section> <name> <line>" for every apsira_*
# key directly under the matching top-level sections.
apsira_deps() {
  awk -v want="$2" '
    /^[^[:space:]#][^:]*:/ { section = $0; sub(/:.*/, "", section); next }
    section ~ want && /^[[:space:]]+apsira_[a-z0-9_]+[[:space:]]*:/ {
      name = $0; sub(/^[[:space:]]+/, "", name); sub(/[[:space:]]*:.*/, "", name)
      line = $0; sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line)
      print section " " name " " line
    }' "$1"
}

# closure <package dir> — every apsira package it resolves: its dependencies and
# dev_dependencies, then their dependencies, transitively; sorted, one per line.
# The package itself is left out: a dev_dependency that depends back on it
# (apsira_ui's apsira_test) is satisfied by the root, and pub refuses an
# override of the root package (D-APK-014).
closure() {
  local queue=() seen=" " name
  while read -r _ name _; do queue+=("$name"); done \
    < <(apsira_deps "$1/pubspec.yaml" '^(dependencies|dev_dependencies)$')
  while [ "${#queue[@]}" -gt 0 ]; do
    name="${queue[0]}"
    queue=("${queue[@]:1}")
    case "$seen" in *" $name "*) continue ;; esac
    seen="$seen$name "
    [ -f "packages/$name/pubspec.yaml" ] || continue
    while read -r _ dep _; do queue+=("$dep"); done \
      < <(apsira_deps "packages/$name/pubspec.yaml" '^dependencies$')
  done
  printf '%s\n' $seen | sed "/^$/d;/^${1##*/}\$/d" | sort
}

# versions_equal — every packages/*/pubspec.yaml carries the same version:.
versions_equal() {
  local status=0 dir v
  [ -n "$version" ] || {
    echo "${packages[0]:-packages/}/pubspec.yaml has no version:"
    return 1
  }
  for dir in "${packages[@]}"; do
    v="$(version_of <"$dir/pubspec.yaml")"
    if [ "$v" != "$version" ]; then
      echo "$dir/pubspec.yaml says version '$v', ${packages[0]} says $version"
      status=1
    fi
  done
  return "$status"
}

# tag_matches — when the shared tag exists, every package at that tag has its version.
tag_matches() {
  local status=0 dir tagged
  git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1 || return 0
  for dir in $(git ls-tree -d --name-only "$tag" packages/); do
    git cat-file -e "$tag:$dir/pubspec.yaml" 2>/dev/null || continue
    tagged="$(git show "$tag:$dir/pubspec.yaml" | version_of)"
    if [ "$tagged" != "$version" ]; then
      echo "tag $tag carries $dir at version '$tagged', the pubspecs say $version"
      status=1
    fi
  done
  return "$status"
}

# changelog <dir> — CHANGELOG.md has the section of the shared version.
changelog() {
  grep -q "^## $version — " "$1/CHANGELOG.md" 2>/dev/null && return 0
  echo "$1/CHANGELOG.md has no '## $version — ' section"
  return 1
}

# git_form <dir> — every apsira dependency is exactly the git form at the shared tag;
# a path: dependency, another ref or url, a multi-line form or an override in the
# pubspec itself is a defect.
git_form() {
  local status=0 section name line want
  while read -r section name line; do
    want="$name: { git: { url: $url, ref: $tag, path: packages/$name } }"
    if [ "$section" = dependency_overrides ]; then
      echo "$1/pubspec.yaml overrides $name; path overrides live in pubspec_overrides.yaml"
      status=1
    elif [ ! -f "packages/$name/pubspec.yaml" ]; then
      echo "$1/pubspec.yaml depends on $name, which is not a package here"
      status=1
    elif [ "$line" != "$want" ]; then
      printf '%s/pubspec.yaml: %s\n  want: %s\n' "$1" "$line" "$want"
      status=1
    fi
  done < <(apsira_deps "$1/pubspec.yaml" '^(dependencies|dev_dependencies|dependency_overrides)$')
  return "$status"
}

# overrides <dir> — pubspec_overrides.yaml holds exactly `name: { path: ../name }` for
# the transitive closure, and nothing else; a package with no apsira dependency has none.
overrides() {
  local file="$1/pubspec_overrides.yaml" want have line name
  want="$(closure "$1")"
  if [ ! -f "$file" ]; then
    [ -z "$want" ] && return 0
    echo "$file is missing; it must override:" $want
    return 1
  fi
  have=""
  while IFS= read -r line; do
    case "$line" in "" | "#"* | "dependency_overrides:") continue ;; esac
    name="$(printf '%s\n' "$line" | sed -n 's/^  \(apsira_[a-z0-9_]*\): { path: \.\.\/\1 }$/\1/p')"
    if [ -z "$name" ]; then
      echo "$file: '$line' is not '  apsira_<pkg>: { path: ../apsira_<pkg> }'"
      return 1
    fi
    have="$have$name"$'\n'
  done < <(sed 's/[[:space:]]*$//' "$file")
  have="$(printf '%s' "$have" | sed '/^$/d' | sort)"
  [ "$have" = "$want" ] && return 0
  want="${want//$'\n'/ }"
  echo "$file overrides: ${have//$'\n'/ }"
  echo "the transitive closure is: ${want:-nothing (no override file)}"
  return 1
}

# pub_get <dir> <dart|flutter> — resolve from the local cache, the network only if needed.
pub_get() {
  in_dir "$1" "$2" pub get --offline || in_dir "$1" "$2" pub get
}

# sdk_of <dir> — flutter when the pubspec lists `sdk: flutter`, dart otherwise.
sdk_of() {
  if grep -Eq '^[[:space:]]+sdk:[[:space:]]*flutter[[:space:]]*$' "$1/pubspec.yaml"; then
    echo flutter
  else
    echo dart
  fi
}

analyze() {
  if [ "$2" = flutter ]; then
    in_dir "$1" flutter analyze
  else
    in_dir "$1" dart analyze --fatal-infos
  fi
}

# example_test <dir> — the consumer proof from a clean build/: a stale
# build/unit_test_assets keeps the asset set of an earlier pubspec.
example_test() {
  rm -rf "$1/build" && in_dir "$1" "$2" test
}

# Colour literals live only in apsira_ui/lib/src/colors.dart (docs/agent-rules.md). The
# word boundary keeps token names such as ApsiraLightColors.ground out of the match.
# apsira_tools is not scanned: its lint names the rule in its own messages and tests.
colour_literals() {
  local dirs=() dir hits
  for dir in packages/*/lib packages/*/example/lib; do
    case "$dir" in packages/apsira_tools/*) continue ;; esac
    [ -d "$dir" ] && dirs+=("$dir")
  done
  [ "${#dirs[@]}" -gt 0 ] || return 0
  hits="$(grep -rnE '\b(Color\(|Color\.from|Colors\.)' --include='*.dart' "${dirs[@]}" |
    grep -v '^packages/apsira_ui/lib/src/colors\.dart:')"
  if [ -n "$hits" ]; then
    printf '%s\n' "$hits"
    return 1
  fi
}

# Brand files are byte-identical to apsira-brand/ (the fonts it has, and the lockup).
brand_identical() {
  local status=0 font
  for font in apsira-brand/06-fonts/*; do
    cmp "$font" "packages/apsira_ui/lib/fonts/${font##*/}" || status=1
  done
  cmp apsira-brand/02-lockups/horizontal/png/apsira-labs-horizontal-reversed-1600w.png \
    packages/apsira_ui/lib/brand/apsira-labs-horizontal-reversed-1600w.png || status=1
  return "$status"
}

# The shared-tag release rules (D-APK-007).
step "versions equal ($tag)" versions_equal
step "tag $tag matches" tag_matches
for dir in "${packages[@]}"; do
  name="${dir##*/}"
  step "$name changelog" changelog "$dir"
  step "$name apsira dependencies at $tag" git_form "$dir"
  step "$name pubspec_overrides.yaml" overrides "$dir"
done

if [ "$mode" = full ]; then
  step "sha256 fonts" in_dir packages/apsira_ui/lib/fonts sha256sum -c --quiet SHA256SUMS
  step "sha256 brand" in_dir packages/apsira_ui/lib/brand sha256sum -c --quiet SHA256SUMS
  step "brand identical to apsira-brand/" brand_identical
  step "colour literals only in colors.dart" colour_literals
  step "format" dart format --output=none --set-exit-if-changed packages

  for dir in "${packages[@]}"; do
    name="${dir##*/}"
    sdk="$(sdk_of "$dir")"
    step "$name pub get" pub_get "$dir" "$sdk"
    step "$name analyze" analyze "$dir" "$sdk"
    [ -d "$dir/test" ] && step "$name test" in_dir "$dir" "$sdk" test
  done
  for dir in "${examples[@]}"; do
    name="${dir#packages/}"
    sdk="$(sdk_of "$dir")"
    step "$name pub get" pub_get "$dir" "$sdk"
    step "$name analyze" analyze "$dir" "$sdk"
    [ -d "$dir/test" ] && step "$name test" example_test "$dir" "$sdk"
  done
fi

if [ "$failed" -eq 0 ]; then
  echo "check: PASS"
  exit 0
fi
echo "check: FAIL"
exit 1
