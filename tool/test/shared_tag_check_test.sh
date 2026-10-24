#!/usr/bin/env bash
# tool/test/shared_tag_check_test.sh — proves the shared-tag release rules of
# tool/check.sh (D-APK-007) on scratch package trees, and that a package whose
# apsira dependency points at a tag that does not exist yet still resolves
# offline through its committed pubspec_overrides.yaml. A vendored package
# (packages/third_party/<name>, D-APK-021) takes the same git form and
# override, and travels in the closure of every package above it.
#
# Each case copies a passing base tree, breaks one rule, and runs
# `tool/check.sh --release`; the step named for the rule must print FAIL and
# the verdict line must be `check: FAIL`. The last line is
# `shared-tag rules: PASS` (exit 0) or `shared-tag rules: FAIL` (exit 1).
set -u

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
scratch="$HOME/.army/scratch/apsira-check-test"
url='git@github.com:amartb/apsira.git'
version='9.9.9' # a tag that never exists: resolution must not need it
failed=0

rm -rf "$scratch"
mkdir -p "$scratch"
trap 'rm -rf "$scratch"' EXIT

ok() { echo "ok $*"; }
bad() {
  echo "FAIL $*"
  failed=1
}

# git_dep <name> — the exact inter-package form at the shared tag.
git_dep() {
  echo "  $1: { git: { url: $url, ref: apsira-v$version, path: packages/$1 } }"
}

# package <tree> <name> [<dependency line>…] — a pure-Dart package at $version.
package() {
  local dir="$1/packages/$2" name="$2"
  shift 2
  mkdir -p "$dir"
  {
    echo "name: $name"
    echo "version: $version"
    echo "publish_to: none"
    echo "environment:"
    echo "  sdk: ^3.13.0"
    if [ "$#" -gt 0 ]; then
      echo "dependencies:"
      printf '%s\n' "$@"
    fi
  } >"$dir/pubspec.yaml"
  printf '# %s changelog\n\n## %s — 2026-10-24\n\nScratch.\n' "$name" "$version" >"$dir/CHANGELOG.md"
}

# overrides <tree> <name> <dependency>… — the committed path overrides.
overrides() {
  local file="$1/packages/$2/pubspec_overrides.yaml" dep
  shift 2
  {
    echo "# Path overrides for the transitive closure (D-APK-007)."
    echo "dependency_overrides:"
    for dep in "$@"; do echo "  $dep: { path: ../$dep }"; done
  } >"$file"
}

# The base tree: apsira_core ← apsira_ui ← apsira_test, a chain whose last link
# needs both overrides (the transitive closure), each package at $version.
base="$scratch/base"
mkdir -p "$base/tool"
cp "$repo/tool/check.sh" "$base/tool/check.sh"
package "$base" apsira_core
package "$base" apsira_ui "$(git_dep apsira_core)"
overrides "$base" apsira_ui apsira_core
package "$base" apsira_test "$(git_dep apsira_ui)"
overrides "$base" apsira_test apsira_core apsira_ui
git -C "$base" init -q
git -C "$base" add -A
git -C "$base" -c user.name=t -c user.email=t@t commit -q -m base

# release <tree> — tool/check.sh --release, its whole output.
release() {
  (cd "$1" && bash tool/check.sh --release 2>&1)
}

# expect_fail <case> <step> <edit command…> — the edit breaks <step>.
expect_fail() {
  local case="$1" step="$2" tree out
  shift 2
  tree="$scratch/$case"
  cp -a "$base" "$tree"
  (cd "$tree" && "$@")
  out="$(release "$tree")"
  if printf '%s\n' "$out" | grep -qxF "FAIL $step" &&
    [ "$(printf '%s\n' "$out" | tail -n 1)" = "check: FAIL" ]; then
    ok "$case fails at '$step'"
  else
    printf '%s\n' "$out" | tail -n 20
    bad "$case did not fail at '$step'"
  fi
}

unequal_versions() { sed -i 's/^version: .*/version: 9.9.8/' packages/apsira_ui/pubspec.yaml; }
wrong_ref() { sed -i 's/ref: apsira-v9.9.9/ref: apsira_core-v9.9.9/' packages/apsira_ui/pubspec.yaml; }
wrong_url() { sed -i 's#url: git@github.com:amartb/apsira.git#url: https://github.com/amartb/apsira.git#' packages/apsira_ui/pubspec.yaml; }
missing_override() { sed -i '/apsira_core: { path/d' packages/apsira_test/pubspec_overrides.yaml; }
extra_override() { overrides . apsira_core apsira_ui; }

# vendor — the base tree with a vendored package that apsira_ui depends on in
# the git form; apsira_ui and apsira_test (through apsira_ui) override it.
vendor() {
  local dir=packages/third_party/vendored_plugin
  mkdir -p "$dir"
  printf 'name: vendored_plugin\nversion: 22.3.2\nenvironment:\n  sdk: ^3.0.0\n' >"$dir/pubspec.yaml"
  echo "  vendored_plugin: { git: { url: $url, ref: apsira-v$version, path: $dir } }" \
    >>packages/apsira_ui/pubspec.yaml
  echo '  vendored_plugin: { path: ../third_party/vendored_plugin }' \
    | tee -a packages/apsira_ui/pubspec_overrides.yaml >>packages/apsira_test/pubspec_overrides.yaml
}
vendored_path_dependency() {
  vendor
  sed -i 's#^  vendored_plugin: { git: .*#  vendored_plugin: { path: ../third_party/vendored_plugin }#' \
    packages/apsira_ui/pubspec.yaml
}
vendored_missing_override() {
  vendor
  sed -i '/vendored_plugin/d' packages/apsira_test/pubspec_overrides.yaml
}
path_dependency() {
  sed -i 's#^  apsira_core: .*#  apsira_core: { path: ../apsira_core }#' packages/apsira_ui/pubspec.yaml
}

expect_fail unequal-versions "versions equal (apsira-v9.9.9)" unequal_versions
expect_fail wrong-ref "apsira_ui apsira dependencies at apsira-v9.9.9" wrong_ref
expect_fail wrong-url "apsira_ui apsira dependencies at apsira-v9.9.9" wrong_url
expect_fail missing-override "apsira_test pubspec_overrides.yaml" missing_override
expect_fail extra-override "apsira_core pubspec_overrides.yaml" extra_override
expect_fail path-dependency "apsira_ui apsira dependencies at apsira-v9.9.9" path_dependency
expect_fail vendored-path-dependency "apsira_ui apsira dependencies at apsira-v9.9.9" vendored_path_dependency
expect_fail vendored-missing-override "apsira_test pubspec_overrides.yaml" vendored_missing_override

out="$(release "$base")"
if [ "$(printf '%s\n' "$out" | tail -n 1)" = "check: PASS" ] && ! printf '%s\n' "$out" | grep -q '^FAIL '; then
  ok "base tree passes the release rules"
else
  printf '%s\n' "$out" | tail -n 20
  bad "base tree does not pass the release rules"
fi

if out="$(cd "$base/packages/apsira_test" && dart pub get --offline 2>&1)"; then
  ok "offline override resolves without the tag"
else
  printf '%s\n' "$out" | tail -n 20
  bad "offline override does not resolve without the tag"
fi

vendored="$scratch/vendored"
cp -a "$base" "$vendored"
(cd "$vendored" && vendor)
out="$(release "$vendored")"
if [ "$(printf '%s\n' "$out" | tail -n 1)" = "check: PASS" ] && ! printf '%s\n' "$out" | grep -q '^FAIL '; then
  ok "a vendored dependency in the git form, overridden through the closure, passes"
else
  printf '%s\n' "$out" | tail -n 20
  bad "a vendored dependency in the git form does not pass the release rules"
fi
if out="$(cd "$vendored/packages/apsira_test" && dart pub get --offline 2>&1)"; then
  ok "the vendored override resolves offline without the tag"
else
  printf '%s\n' "$out" | tail -n 20
  bad "the vendored override does not resolve offline without the tag"
fi

if [ "$failed" -eq 0 ]; then
  echo "shared-tag rules: PASS"
  exit 0
fi
echo "shared-tag rules: FAIL"
exit 1
