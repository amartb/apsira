<!-- army:doc type=handoff -->
# Packages unit T2 — backups through APSIRA, and the add-ons APSIRA carries: kickoff

Written by the APSIRA v1 conductor, 2026-10-31, while M1 runs (rolling planning). The `apsira` lane's unit for the
shared tag **T2**, before APSIRA's M2 (`master-app/docs/03-roadmap.md` §Shared tags; `07-phase-plans.md` rows K2-01,
K2-02, K2-T). Binding: `docs/agent-rules.md`, `docs/decisions.md`, and for the interface
`master-app/docs/contracts/app-link.md` §5 (backups, schedule, restore) and `contracts/atrium-offload.md` §3.

## Base and lanes

- Base: `session/packages-t1` @ `f69b793`, the branch of PR #11 (T1 = `apsira-v0.5.0`). Once the operator merges PR
  #11 and cuts the tag, T2's integration branch is the same history; nothing is rebased.
- The tag is **`apsira-v0.6.0`**: every package moves to 0.6.0 with its CHANGELOG section. Cut by the operator's
  `tool/release.sh` from `main` once this unit is merged; asked for at that gate.
- Lanes: the repository's 3 across every live unit (APSIRA's P1 holds most of them); the T2 planner runs now, its
  tasks start as lanes free.

## The rows

| Task | What | Reads |
|---|---|---|
| K2-01 | `apsira_storage`: the **APSIRA adapter of `BackupTarget`** (`ApsiraBackupTarget`), mapped method by method as `app-link.md` §5.1: `pickFolder` → the virtual `apsira:<package>` folder after a good `hello`; `write` → `backup_begin`, stream, `backup_commit` with the plain SHA-256; `list`/`read` serve queued and shipped; `delete`/`rename` act on the queue only (a shipped backup is never deleted, D-008); every failure is `unavailable`, never an error that stops the app; its fake in `testing.dart` | `app-link.md` §5; D-APK-015 (the port, unchanged) |
| K2-02 | `apsira_link`: the **backup calls** on APSIRA (`backup_space`, `backup_begin`, `backup_commit`, `backup_rename`, `backup_list`, `backup_delete`, `restore_open`) with `ParcelFileDescriptor` streams; the **app-side provider** that answers APSIRA's `backup_now` and `restore_offer` (D-034) by handing them to the app's own code; the **archive calls** ATRIUM uses (`archive_put`, `archive_state`, `archive_list`, `archive_fetch`, `archive_release`, `atrium-offload.md` §3). Before the first state-changing call: T1's deferred **F-2** (`LinkClient`'s worker queue) and **F-3** (the check-then-call window) are closed (`docs/sessions/PACKAGES-T1-REPORT.md`) | `app-link.md` §4–§5, §8–§10; `atrium-offload.md` |
| K2-03 | `apsira_tools`: a **network-holding app's manifest knob** (an app's declared `INTERNET` admitted when its tools config says it holds network by charter, D-APK-024), and a **candidate mode** in the shared `local_release.sh` (`-rc.N` versions, the `.notes.md` sidecar, D-035), so APSIRA drops its two thin add-ons (APSIRA P0 rulings R-2, R-4) | APSIRA `tool/privacy/guards.dart`, `tool/release/local_release.sh` (read with `git show`) |
| K2-04 | `apsira_core`: a **pure-Dart `SystemClock`** (APSIRA's hub has no Flutter; P0-03's proposal), if it changes no consumer; else a `Needs ruling:` | `apsira_core`, `apsira_app`'s `SystemClock` |
| K2-05 | `apsira_link`: expose T1's **APK signer check** for files (single signer, digest, never `CN=Android Debug`), which APSIRA's P1-08 re-derives today | `apsira_link` Kotlin `LinkTrust`; APSIRA P1-08's `ArchiveInspector` |
| K2-T | versions 0.6.0, CHANGELOGs, README §5, `D-APK-nnn` entries for each change, `tool/check.sh` `check: PASS` | D-APK-007 |

Out of T2: the gateway and policy calls (T3); any app repository (adoption briefs follow T2, `07` row A-*-1).

## Done when

All rows integrated; the final validation runs `tool/check.sh` once with `check: PASS`; the example app proves a
backup handed over and a restore offered against a fake APSIRA (the M2 device session uses it, D-035); no device
check claimed.
