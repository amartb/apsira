<!-- army:doc type=report -->
# Packages unit T1 — `apsira_lock` mandatory mode, `apsira_link` trust core: report

APSIRA v1 conductor, 2026-10-31. Ledger `.army/sessions/2026-10-31-packages-t1` (local). Kickoff
`docs/sessions/PACKAGES-T1-KICKOFF.md`. Branch `session/packages-t1` from `chore/army-config-v1` @ `5959ffe`.

## Verdict

Final validation **failed** on one finding, fixed after it (no second final, by rule). On `cdc7078`: 18 gates
pass, 0 fail; `tool/check.sh` once, fresh: **`check: PASS`** (118 ok, 0 FAIL); every acceptance criterion met;
negative controls F1–F3 and F7 each failed as they must (a release picking the dev check, a trusted debug certificate,
a self-confirming signing shadow, a mandatory lock that opens). Design fit: fit (option A).

## What landed (7 squash commits)

| Task | Commit | What |
|---|---|---|
| K1-F1 | `0419fdf` | `apsira_db`/`apsira_exchange` test hook at Fedora's `/usr/lib64/libsqlite3.so.0` (baseline red since the host moved off Ubuntu) |
| K1-02a | `23b543a` | `apsira_link` (new): Dart API, `LinkHello`, failures, the dev switch, the example consumer |
| K1-02b | `f5c897b` | its Kotlin trust core (`LinkTrust`, `LinkClient`), 32 Robolectric tests, the example's Android host, the release-manifest helper |
| K1-01 | `ab1904e` | `apsira_lock` mandatory mode (`LockPolicy`), `LockController.reconfirm` |
| K1-T | `cdc7078` | every package at 0.5.0, CHANGELOGs, README §5/§9, D-APK-026 addendum, app-link §3.3 |
| F1 | `e586ab2` | **fix:** a background during a re-confirm prompt was lost, so the app came back unlocked (validator's finding F-1, major) |
| F2 | `9997272` | app-link's Status says what exists at `apsira-v0.5.0` |

## Rulings (conductor, routine; `rulings.md` in the ledger)

R-1/R-4 mandatory mode never opens unlocked (a device without a screen lock keeps the cover; re-confirm refuses) ·
R-2/R-5 the relaxed dev check needs both a `.dev` id and a dev-source manifest switch, proven absent from release ·
R-6 app-link stays 1.0 (clarified) · R-8 no peer pack (no security floor then; P0-06 adds one for later units).

## Deferred, with triggers

- F-2, F-3 (`LinkClient`'s worker queue; the check-then-call window): before T2's first state-changing link call.
- F-8: the lock example's Gradle daemons; when that Android project is next touched.
- Candidates for T2: `apsira_tools`' manifest knob for network-holding apps and a candidate mode in
  `local_release.sh` (APSIRA's P0 carries thin add-ons until then); a pure-Dart `SystemClock` in `apsira_core`; the
  APK signer check (APSIRA P1-08 re-derives T1's private one).

## Owed

The operator's tag act: this branch merged to `main`, then `tool/release.sh` → **`apsira-v0.5.0`** (T1).
