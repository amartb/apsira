<!-- army:doc type=handoff -->
# P0 — Foundation: kickoff

Written by the APSIRA v1 conductor, 2026-10-31. The unit's input; `07-phase-plans.md` §2 (P0 rows) is the task
list, the decision log wins over this brief. Runs **in parallel** with the packages unit `docs/sessions/PACKAGES-T1-KICKOFF.md`
(K1-01, K1-02 → tag T1); P0 pins **apsira-v0.4.0** and does not wait for T1.

## Base and lane (P0-06, settled before the unit)

- Base: branch `chore/army-config-v1` @ `13b59e9` (one commit on `main` `b1e7c05`). Army reads only the repository
  root's `.army.toml` (`project-agents/army/config.py`, git toplevel), so `master-app/` has **no nested `.army.toml`**:
  it gains path-scoped gates `ma-format`, `ma-analyze`, `ma-hub-analyze` (unavailable until their pubspec exists),
  `master-app/docs/agent-rules.md` in `[rules] extra`, and its paths in `[assurance] subsystems`. Lane name stays
  `apsira`. The attribution no longer names a forbidden model.
- Lanes: repository `max_lanes = 3` for every unit together; while STYLUS holds 3 lanes on this host (to its V-M5),
  the conductor runs **at most 2 lanes** across P0 and T1. Every gate under `army lease`; one Flutter suite at a time.
- **P0-06 that remains for this unit:** wire master-app's other `tool/` steps (codegen, l10n, layering, deps,
  manifest) as merge gates and the area gates (`t-domain`, `t-data`, `t-features`, `t-goldens`, `t-android`, `t-hub`)
  as validator gates honouring `APSIRA_TEST_SCOPE`; and give master-app's full check its own switch: the repository's
  `check` gate already uses `APSIRA_FULL_CHECK` for `tool/check.sh` (packages), so `08` §4's name collides — rename
  master-app's (e.g. `APSIRA_APP_FULL_CHECK`) and fix `08`, `assurance-rules.md` and `CLAUDE.md` §4 in that commit.

## Conductor rulings for this unit (system internals, recorded here)

1. `master-app/shared/` stays a **local Dart package** of APSIRA (path dependency from the app and the hub; it is
   APSIRA's own code, not an `apsira_*` package under D-APK-007). It becomes a package only when a second consumer
   exists (v2 folios taking the sync envelope codec). P0-03 records this as a D-017 addendum.
2. **P0-07 (added): the runbook's `P0 verify` lines**, read-only or on scratch only: ports 8443 and 8100 free
   (`ss -ltn`), `dnf info rest-server`, `htpasswd` present, the LAN prefix and wired interface (`ip -4 -br addr`),
   restic 0.19.1's `--keep-within-weekly` and `--keep-monthly -1` and `g+r` pack files on a scratch repository under
   the lane's temp area (disposed). Lines that need root, the phone, the router or the network (bind mounts under
   `ProtectHome`, Proton VPN LAN, the GitHub asset redirect host, Proton Drive CLI) are marked **owed to the operator
   act O-1/O-3** in `10-hub-runbook.md`, never run. Results go into `10` §0–§8 and the `D-014` addendum where a value
   changes. No act on the real host.
3. The **release tooling** (P0-05) copies the ASTROLABE model, not a new design: read
   `~/projects/astrolabe-builds/v1-release.sh` and `astrolabe/tool/release/{local_release.sh,session_guard.sh,changelog.dart}`,
   and `apsira_tools`' `lib/scripts/` skeleton (D-APK-011). The in-repo script is a template the conductor copies to
   `~/projects/apsira-builds/v<N>-release.sh` at the first RC; candidate mode writes `.notes.md` (D-035). Its test
   runs a copy with every tool stubbed; nobody runs it for real in a session.
4. The direction board (`06` §0) is drawn in **P1** on real screens, not in P0. P0's screens are first open, About
   and the settings shell only.
5. The dev APK: the conductor builds one `dev` APK at P0's close (`tool/build_apk.sh`, under a lease, Gradle heap
   capped) into `~/projects/apsira-builds/` with its `.sha256`, as proof the skeleton, flavours and manifest build.
   Tasks never build an APK.

## Baseline (2026-10-31)

| What | Found |
|---|---|
| Newest shared tag | `apsira-v0.4.0` (no newer on `origin`); `packages/` and `tool/` unchanged since it; 16 docs commits on `main` |
| Package check | `tool/check.sh` on `main` `b1e7c05`: **`check: FAIL`** — `apsira_db test` and `apsira_exchange test` only, every other package green. Cause proven: their test-only `sqlite3` hook pins the Ubuntu library path; this host is Fedora (`/usr/lib64/libsqlite3.so.0`). Fixed in T1 (K1-F1). APSIRA's own pubspec uses the hook's default (prebuilt), as every sibling app does |
| Toolchain | Flutter 3.47.7 / Dart 3.13.5, JDK 17.0.20.1, build-tools 36.0.0 (`apksigner`), restic 0.19.1, `htpasswd`, `openssl`, `gh` authenticated; `rest-server` absent (O-1); `~/.android/debug.keystore` present again (the 2026-10-28 note is stale) |
| Builds folders | `astrolabe-builds`, `atrium-builds`, `stylus-builds` exist; `apsira-builds` does not yet (created with the first APK) |
| Host | 60 GB, `user-1001.slice` max 53 GB; STYLUS v1 live (≤ 3 lanes, P4–P5 validations ahead) |

## Done when

Every P0 row integrated on the unit's integration branch; the merge gates green; the dev APK built and copied with
its `.sha256`; `CLAUDE.md` §4 lists the commands as built; `dependencies.md` §1.2 carries the stack's rows with
versions. No device or host act is owed by P0 itself (O-1 and O-4 are asked at their gates).
