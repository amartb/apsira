<!-- army:doc type=handoff -->
# Packages unit T1 — `apsira_lock` mandatory mode and `apsira_link`'s trust core: kickoff

Written by the APSIRA v1 conductor, 2026-10-31. The `apsira` lane's unit for APSIRA's first shared tag, **T1**
(`master-app/docs/03-roadmap.md` §Shared tags; `07-phase-plans.md` rows K1-01, K1-02, K1-T). Binding:
`docs/agent-rules.md` (this repository's), `docs/decisions.md`, and for the interface `master-app/docs/contracts/app-link.md`
§2–§4 and §8–§10. Runs in parallel with APSIRA's P0 (`master-app/docs/sessions/P0-KICKOFF.md`); neither waits on the other.

## Base and lanes

- Base: branch `chore/army-config-v1` @ `13b59e9` (the root `.army.toml` with a `link` gate for the new package and
  the corrected attribution). Same repository config as P0; at most **2 lanes across both units** while STYLUS is live.
- The tag is **`apsira-v0.5.0`**: every package moves to `version: 0.5.0` with a `## 0.5.0 — <date>` CHANGELOG section
  ("no change in behaviour" for the untouched ones), as D-APK-007 requires. `apsira-v0.4.0` stays where it is (STYLUS
  and the folios pin it).
- Cut by the operator's `tool/release.sh` from `main` after the integration branch is merged; the conductor asks for
  push, merge and tag at that gate. Nothing else rides on T1.

## The rows

| Task | What | Reads |
|---|---|---|
| K1-F1 | **Baseline fix, wave 1.** `tool/check.sh` on `main` `b1e7c05` is red on `apsira_db test` (180 failures) and `apsira_exchange test` (21): both `pubspec.yaml` set `hooks: user_defines: sqlite3: source: system` with `linux: /lib/x86_64-linux-gnu/libsqlite3.so.0`, the Ubuntu path; amb811 is Fedora 44 now and has `/usr/lib64/libsqlite3.so.0` (`sqlite-libs` 3.51.2; no `sqlite-devel`, so the hook's bare default name `libsqlite3.so` does not resolve). Point both at `/usr/lib64/libsqlite3.so.0`, say why in the comment, prove both packages green; tests only, consumers unaffected (hooks read the root package only). A line in each CHANGELOG's 0.5.0 section | `.army/baseline-check.log`; `sqlite3` 3.8.0 `lib/src/hook/compile/description.dart` (`LookupSystem`) |
| K1-01 | `apsira_lock`: a **mandatory mode** (APSIRA D-018, D-017): `LockSettings` read through a store that pins `enabled: true`; `LockSettingsSection` hides the switch in that mode and keeps the timeout choices APSIRA uses (0, 1, 5 min, default 1, D-018 addendum); a **re-confirm API** for sensitive acts (install, restore, pair, revoke) that prompts even when unlocked, never a lock-out (D-APK-016's rule); default behaviour unchanged for every current consumer | D-APK-016, `master-app/docs/06` §3.1 |
| K1-02 | `apsira_link` (**new package**, Flutter plugin with a small Kotlin side): the trust core only — resolve APSIRA's authority (`com.apsiralabs.apsira.link`, `.dev`), the caller-side check (exact package + `hasSigningCertificate(…, CERT_INPUT_SHA256)` against `F_APSIRA`), the provider-side `CallerCheck` against a recorded **fingerprint table type** (`package → SHA-256`), the `hello` shape, `unavailable` with its reasons (`not_installed`, `not_trusted`, `unsupported_version`, …) and the error codes of §8 as `Failure`s; release never trusts a debug certificate, the dev relaxed check is reachable only from a dev-flavour build and a test proves a release build cannot select it (KAIROS §2.3); `F_APSIRA` is a build-time constant that stays **unset** (no APSIRA trusted) until APSIRA's `release-signing.md` §2 records it. Its `example/` app is the consumer every APSIRA milestone is proven with (D-035): in T1 it shows `hello`/unavailable only | `contracts/app-link.md`; RELAY `docs/kairos/05-link-contract.md` §2–§3 and ATRIUM `android/…/files/CallerCheck.kt` + `StylusContractTest.kt` (read with `git show`, never edited) |
| K1-T | Versions, CHANGELOGs, `packages/README.md` and charter §5/§9 (`apsira_link` added), `D-APK-026` → Decided with the API as built (append-only: a Status note plus an addendum), `tool/check.sh` covering the new package; the full check `check: PASS` | D-APK-007, D-APK-026 |

Out of T1: the backup, schedule, restore, archive, gateway and policy calls (T2, T3); any change in an app repository.

## Done when

All three rows integrated; the final validation runs `tool/check.sh` once (`APSIRA_FULL_CHECK=1`) with `check: PASS`;
the Kotlin side of `apsira_link` and `apsira_lock` is proven by Robolectric/unit tests and the example's debug build
compiles (D-APK-016's lesson: mocked channels cannot see a Dart/Kotlin mismatch); no device check is claimed.
