<!-- army:doc type=report -->
# Packages unit T2 — backups through APSIRA, and the add-ons APSIRA carried: report

APSIRA v1 conductor, 2026-10-31. Ledger `.army/sessions/2026-10-31-packages-t2` (local). Kickoff
`docs/sessions/PACKAGES-T2-KICKOFF.md`. Branch `session/packages-t2` from `session/packages-t1` @ `f69b793`
(T1's PR #11), so T1's commits sit under it.

## Verdict

Final validation **complete-accepted** on `c608895`: `tool/check.sh` once, fresh, **`check: PASS`** (118 ok, 0 FAIL);
the Kotlin suite from checkpoint C1 (88 tests; nothing under `android/` changed after it); every acceptance criterion
met; negative controls (a config default flipped, a signing value printed, a candidate not stopped before publish)
each turned their tests red. C1 (the six `apsira_link` tasks): complete-accepted, 10 negative controls red.

## What landed (11 squash commits)

| Task | What |
|---|---|
| K2-02a | the link transport: a worker that drops a call past its deadline (T1's F-2), acquire-check-call-recheck (F-3), byte streams |
| K2-04 | a pure-Dart `SystemClock` in `apsira_core`, re-exported by `apsira_app` |
| K2-03a | `apsira_tools`: `holds_network` for network-holding apps, `requestedPermissions` |
| K2-03b | `local_release.sh --candidate`: `-rc.<n>`, the `.notes.md` sidecar, never published |
| K2-05 | `ApkSignerCheck`: an APK file's signer by the link's own rule (D-031) |
| K2-02b | the backup calls (contract §5.2) and their D-008 fake |
| K2-02c | the archive calls for ATRIUM (squashed under a `docs(K2-02c)` subject: the conductor's README split was the lane's last conventional commit) |
| K2-02d | the provider each app declares (`backup_now`, `restore_offer`), `apsira_jobs`' run-job receiver |
| K2-01 | `ApsiraBackupTarget` **on `apsira_link`'s side** and the example that hands a backup over and takes a restore offer |
| K2-T | every package at 0.6.0, CHANGELOGs, D-APK entries (D-APK-026's per-consumer manifest table), the contracts' wire forms |
| F1 | the archive fake's `since`: store time, exclusive, as `atrium-offload.md` §3 |

## Rulings

**R-2 (operator, design):** the adapter lives on `apsira_link`'s side; only an app that adds `apsira_link` gains its
plugin and `<queries>`; T3's notify check follows the same direction. Conductor (routine): the T2 branch's config level
with the base; C1 over the link tasks, no peer pack; the README split into `doc/` pages under the 250-line cap.

## Deferred, with triggers

F-8: no test pins `apsira_app`'s `SystemClock` as core's (next edit of that file) · C1 F-1: `ApkSignerCheck` on API
28 (a device check) · two `apsira_link` candidates from APSIRA's M2 plan (`LinkClient` calling an app; `apsira_jobs`
with a charging constraint), for T3.

## Owed

The operator's acts: this branch to `main` after T1 (PR #11) and `apsira-v0.5.0`, then `tool/release.sh` →
**`apsira-v0.6.0`** (T2). Device checks for the M2 session: the provider replaced after acquire, the run-job broadcast,
`ApkSignerCheck` on real APKs.
