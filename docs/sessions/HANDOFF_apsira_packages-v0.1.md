# Handoff — Apsira shared packages v0.1.0 (unit closed 2026-10-21)

**Ledger:** `.army/sessions/2026-10-21-packages-v0-1` (local). **Branch:** `phase/packages-v0.1` (the integration
branch `session/packages-v0-1` fast-forwarded onto it at the close). **Verdict:** complete-accepted
(`04-validation.md`): 5 gates pass on a fresh checkout, every acceptance criterion met, design fit, no fix findings.

## What exists now
- `packages/apsira_core` 0.1.0 — `Result`/`Failure`, log model, `Clock`, `IdGen`, `testing` fakes. Pure Dart. 37 tests.
- `packages/apsira_ui` 0.1.0 — `ApsiraTheme`, `ApsiraThemeData.build(tokens, extensions:)`, typography (package-qualified
  fonts), shape, `ApsiraIcons`, `ApsiraBrand` (lockup, licences), fonts and brand with `SHA256SUMS` and the provenance
  test, a token-sheet golden, an `example/` consumer whose test proves the fonts load. 80 tests.
- `packages/apsira_tools` 0.1.0 — `layering_lint`, `l10n_check`, `coverage_gate`, `deps_check`, `manifest_check` as
  `bin/`s over `tool/apsira_tools.yaml`; RELAY's fixtures as tests (105). `disabled_rules` already in v0.1.
- `tool/check.sh` — the full check; last line `check: PASS`. `docs/decisions.md` D-APK-001…006 (006 records what the
  extraction settled: no inter-package dependency in v0.x, barrel-import shims, fonts layout, `--l10n-config`).
- Source: RELAY `5f606e9`. RELAY's and VIATICUM's working trees were not touched (porcelain unchanged).

## Rulings this unit (conductor, routine): R-1 plan approved · R-2 assurance (C1 non-gating + full final) ·
R-3/R-4 `decisions_dir` moved off `docs/` so the decision log is not checked as an ADR (army reads `.army.toml`
from the primary checkout) · docs gaps D-1/D-2 fixed at the close with "amended by D-APK-006" pointers.

## Deferred, with trigger
- `l10n_check` exits 255 (stack trace) when `lib/app/l10n/l10n.yaml` is absent — RELAY parity; harden in
  apsira_tools v0.2 or at the first consumer without l10n.
- Minor doc items m1, m2, m6 of `04-validation.md` §3 (plan-label pointers, a CHANGELOG wording not in a D-entry, the
  tools README citing few decisions) — next docs pass.
- Squash subjects of the feature commits read `docs(Tn)` (C1 F-5) — cosmetic; history unchanged.

## Operator acts (in this order)
1. Push the branch and the three tags, from `~/projects/apsira` on `phase/packages-v0.1` (its HEAD holds the packages):
   `git tag apsira_core-v0.1.0 && git tag apsira_ui-v0.1.0 && git tag apsira_tools-v0.1.0 && git push origin phase/packages-v0.1 --tags`
2. Merge `phase/packages-v0.1` into `main` (PR or fast-forward) when convenient. Consumers pin the tags, not `main`.

## Next
LYCEUM P0 (`lyceum-folio/docs/sessions/P0-KICKOFF.md`) consumes `apsira_tools-v0.1.0`; P1/P2 consume all three.
RELAY and VIATICUM adopt in their own sessions through the barrel shims named in D-APK-006.
