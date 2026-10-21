#!/usr/bin/env bash
# tool/check.sh — the full check of the Apsira packages. There is no CI: this script is
# the release check (packages/README.md, "Releasing a package") and the `check` gate.
#
# Every step runs on its own, whatever the steps before it did, and prints `ok <step>`
# or, after the tail of its output, `FAIL <step>`. The last line is exactly
# `check: PASS` (exit 0) or `check: FAIL` (exit 1).
set -u

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root" || exit 1

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

# pub_get <dir> <dart|flutter> — resolve from the local cache, the network only if needed.
pub_get() {
  in_dir "$1" "$2" pub get --offline || in_dir "$1" "$2" pub get
}

# example_test — the consumer proof from a clean build/: a stale
# build/unit_test_assets keeps the asset set of an earlier apsira_ui pubspec.
example_test() {
  rm -rf packages/apsira_ui/example/build &&
    in_dir packages/apsira_ui/example flutter test
}

version_of() {
  sed -n 's/^version:[[:space:]]*\([^[:space:]#]*\).*/\1/p' | head -n 1
}

# release_ready <pkg> — the pubspec version has its CHANGELOG section, and when the tag
# apsira_<pkg>-v<version> exists, the pubspec at that tag carries the same version.
release_ready() {
  local pkg="$1" version tag tagged
  version="$(version_of <"packages/$pkg/pubspec.yaml")"
  if [ -z "$version" ]; then
    echo "packages/$pkg/pubspec.yaml has no version:"
    return 1
  fi
  if ! grep -q "^## $version — " "packages/$pkg/CHANGELOG.md"; then
    echo "packages/$pkg/CHANGELOG.md has no '## $version — ' section"
    return 1
  fi
  tag="$pkg-v$version"
  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1; then
    tagged="$(git show "$tag:packages/$pkg/pubspec.yaml" | version_of)"
    if [ "$tagged" != "$version" ]; then
      echo "tag $tag carries version '$tagged', the pubspec says $version"
      return 1
    fi
  fi
}

# Colour literals live only in apsira_ui/lib/src/colors.dart (docs/agent-rules.md). The
# word boundary keeps token names such as ApsiraLightColors.ground out of the match.
# apsira_tools is not scanned: its lint names the rule in its own messages and tests.
colour_literals() {
  local hits
  hits="$(grep -rnE '\b(Color\(|Color\.from|Colors\.)' --include='*.dart' \
    packages/apsira_core/lib packages/apsira_ui/lib packages/apsira_ui/example/lib |
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

step "sha256 fonts" in_dir packages/apsira_ui/lib/fonts sha256sum -c --quiet SHA256SUMS
step "sha256 brand" in_dir packages/apsira_ui/lib/brand sha256sum -c --quiet SHA256SUMS
step "brand identical to apsira-brand/" brand_identical
step "colour literals only in colors.dart" colour_literals
step "format" dart format --output=none --set-exit-if-changed packages

for pkg in apsira_core apsira_tools; do
  step "$pkg version, changelog and tag" release_ready "$pkg"
  step "$pkg pub get" pub_get "packages/$pkg" dart
  step "$pkg analyze" in_dir "packages/$pkg" dart analyze --fatal-infos
  step "$pkg test" in_dir "packages/$pkg" dart test
done

step "apsira_ui version, changelog and tag" release_ready apsira_ui
step "apsira_ui pub get" pub_get packages/apsira_ui flutter
step "apsira_ui analyze" in_dir packages/apsira_ui flutter analyze
step "apsira_ui test" in_dir packages/apsira_ui flutter test
step "apsira_ui/example pub get" pub_get packages/apsira_ui/example flutter
step "apsira_ui/example analyze" in_dir packages/apsira_ui/example flutter analyze
step "apsira_ui/example test" example_test

if [ "$failed" -eq 0 ]; then
  echo "check: PASS"
  exit 0
fi
echo "check: FAIL"
exit 1
