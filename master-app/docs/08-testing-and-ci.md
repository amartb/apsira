# APSIRA — Testing, checks and release

Status: **seeded by the APSIRA PLANNING thread, 2026-10-30** (living document); §2–§5 are written as built from P0.

## 1. Principles

1. Tests prove the non-negotiables first: backups are never lost, the store is append-only for the hub account, the
   hub never sees content in the clear, trust is checked on every call, the apps work without APSIRA, the network
   bar holds (D-005, D-008, D-016, D-028).
2. Domain code is pure Dart and tested without Flutter; every platform and network piece is a port with a fake;
   Kotlin is tested with Robolectric.
3. **The hub is tested in a sandbox only** (§5). No test touches the real host's accounts, groups, systemd units,
   firewall, store, `~/projects/*-builds/` or GitHub.
4. Checks are designed (`assurance-rules.md`): analyze and codegen at merge, bundle validations scoped to their
   seams (`07` §3), delta checks for fixes and closes, the full check once at the v1 exit. No CI.
5. A failing test is fixed or quarantined with a reason, never deleted or weakened to get green.
6. Fixtures are synthetic: no real backup, document, token, key or fingerprint of a device is committed (the
   recorded **release** fingerprints are public and are the one exception, D-016).

## 2. Layers and areas

| Area gate | Folders | What |
|---|---|---|
| `t-domain` | `test/domain/`, `test/critical/domain/` | shelf selection, retention maths, cadences, the regime's decision function, the sync format and merge; coverage ≥ 90 % lines on `lib/domain/` (`coverage` gate) |
| `t-data` | `test/data/`, `test/app/services/`, `test/critical/data/` | DAOs, migrations (`drift_schemas/` chain), services, the hub client over a fake hub, backup and restore flows, sync client |
| `t-features` | `test/features/`, `test/critical/features/` | screens over fakes with the large-text layout check |
| `t-goldens` | `test/goldens/` | key screens EN/ES × dark/light × 100/200 % (`apsira_test` matrix) |
| `t-android` | `android/app/src/test/` (`tool/android_unit_tests.sh`) | the link's content provider with the fingerprint check, the Keystore key and the Kotlin TLS `HubClient`, the pairing scanner, the installer (Robolectric) |
| `t-hub` | `hub/test/` (`tool/hub_tests.sh`) | the hub's endpoints, pairing, registry, store driver, shelf and gateway fetchers, mailbox, all in the sandbox (§5) |
| `rest` (in `check` only) | every other `test/<dir>` | the scripts' contracts, identity, the pins |

`APSIRA_TEST_SCOPE` selects test paths (and Kotlin classes) inside an area, as the siblings' `*_TEST_SCOPE`; a scope
selecting nothing exits 0 with `no tests in scope`, a misspelt Kotlin class is red.

## 3. Critical suites (`test/critical/<area>/`, `hub/test/critical/`)

| Suite | Area | Proves | Milestone |
|---|---|---|---|
| `migration_chain_test` | data | every schema version migrates to the latest with data intact | M1 |
| `network_bar_test` | data | the manifest is exactly D-024's list with D-029's `CAMERA` (no location, no notification listener); `lib/` and `android/` open connections only through the `HubClient` adapter, and only to the paired hub; a planted second host fails it; only the pairing screen opens the camera | M1 |
| `pairing_test` | hub | a one-time code pairs once; expired or reused codes are refused; the QR payload carries the hub's fingerprint | M1 |
| `revocation_test` | hub | a revoked device's handshake and every later call are refused, from the device that revoked it and from the hub | M1 |
| `pinning_test` | data | the client refuses a hub whose certificate differs from the paired one | M1 |
| `fingerprint_refusal_test` (`LinkTrustTest.kt`) | android | a caller with the wrong package, an unrecorded certificate, a debug certificate or a dev certificate against a release build gets `not_authorised` and no data; nothing about it is logged beyond the code (D-031) | M1 |
| `shelf_integrity_test` | hub | a wrong SHA-256 or signing certificate is refused and never offered; `.dev` and debug-signed builds are never listed; RCs are recognised by `rc` in the version, marked, with notes from `.notes.md` or none (D-035) | M1 |
| `key_handover_test` | data + hub | the recovery sheet is shown once; a new device receives the sync and vault keys sealed to its device key, or typed; no hub path ever holds either key (D-028) | M1 |
| `mandatory_lock_test` | features | the lock has no off switch; install, restore, pair and revoke re-confirm | M1 |
| `backup_never_lost_test` | data + hub | a hand-over becomes exactly one snapshot whose restore, decrypted on the device, equals the source byte for byte; a cut stream leaves the app's copy and is retried; a duplicate is a no-op | M2 |
| `hub_blind_test` | hub | everything written to the store and the archive is ciphertext under the vault key; the hub's files, logs and database hold no key that opens it (D-028) | M2 |
| `append_only_test` | hub | on a scratch repository, the hub account cannot forget, prune or overwrite; only the store account's prune removes snapshots, only outside the retention | M2 |
| `retention_test` | domain | on a synthetic year: every snapshot within the last 30 days kept, then one a week for a year, then one a month (D-008, D-032) | M2 |
| `restore_new_phone_test` | data | against fakes: keys received, every shelf app reinstalled and offered its latest snapshot (`restore_offer`), restored through its own path (D-034); one app's failure does not stop the others | M2 |
| `archive_roundtrip_test` | hub | an offloaded document is `secured` only once a snapshot holds it, and is fetched back identical by checksum | M2 |
| `gateway_cadence_test` | hub | each source fetches on its cadence on a fake clock; a failure keeps the previous data; an invalid payload is never offered; a source edited by one device is read back by the other; two instances of one kind are kept apart (D-033) | M3 |
| `policy_fallback_test` | data | with APSIRA missing, not answering or past the deadline of `contracts/app-link.md` §6.1, `apsira_notify` posts as before (run in the apsira lane too) | M4 |
| `regime_property_test` | domain | over generated schedules and kinds: inside quiet hours only breakthroughs interrupt; digests hold each item once | M4 |
| `sync_core_rules_test` | domain | on settings: R10 both kept, R11 edit beats delete, R12 newest shown everywhere with the badge, R14 suggestion never applied; clashes found by bases, never clocks | M5 |
| `mailbox_ciphertext_test` | hub | the mailbox holds only ciphertext; a revoked device is refused | M5 |

## 4. Gates

- **Merge (static, by path):** `format`, `codegen`, `l10n`, `analyze`, `layering`, `deps`, `manifest`, and
  `hub-analyze` for `hub/`.
- **Bundle validation (validator, `APSIRA_VALIDATION=1`):** the bundle's area gates with `APSIRA_TEST_SCOPE` set
  to its scope (`07` §3).
- **Delta check (fixes, milestone closes):** `analyze` and the tests touching the changed files.
- **v1 exit (`APSIRA_FULL_CHECK=1`):** `check` once, plus `coverage`.
- **`tool/check.sh`:** `apsira_tools`' step runner with APSIRA's steps (`format`, `codegen`, `analyze`,
  `layering`, `l10n`, `deps`, `manifest`, `keystore` and `secrets` (no signing material, token or key tracked),
  the areas, `t-hub`, `coverage`); last line `check: PASS` or `check: FAIL (<steps>)`.
- **Privacy and secrets:** the manifest guard against D-024's list; `deps_check` with a row in `dependencies.md` for
  every dependency; a secrets scan of the tree and of the hub's log output in `t-hub`.

## 5. The hub sandbox

Every `t-hub` test runs inside a scratch root the test creates and removes:

- **Store:** a scratch restic repository and a `rest-server` bound to a loopback port the test picks, started as
  the test's own user; the "accounts" are two credential sets on that server, not system accounts. Where the real
  binaries are absent, the fake binaries from P0-03 stand in and the test says so.
- **systemd and the firewall:** a fake `systemctl` and a fake firewall tool on `PATH` that record calls; the
  install script's tests assert the calls, never run them.
- **Builds and GitHub:** a scratch builds folder with synthetic APKs signed by a test key; a fake GitHub Releases
  server on loopback. No test reads the real token or the real `~/projects/*-builds/`.
- **Resources:** bounded (one hub test process at a time, `agent-rules.md` §This host); every fixture is removed at
  the end, a leftover fails the run.

The **real** hub is exercised only by the operator's acts and the device session (§6).

## 6. Releases and device sessions

- Each milestone ends in `v0.<n>.0-rc.<k>`, built and signed by APSIRA's release script in candidate mode **outside
  any session** (D-035), into `~/projects/apsira-builds/` with its `.sha256` and `.notes.md`; then **one device
  session** on it (≤ 20 minutes, the operator, phone and tablet, at home), with `apsira_link`'s example app as the
  consuming app; then the signed release (D-025). The conductor builds only `dev` APKs (`building.md`), which the shelf
  never offers. Device checks a task names (`Device check:`) are
  bundled into that session; there is no per-task device check.
- **No phone in any release step:** the release script signs, checks the certificate against
  `release-signing.md`'s fingerprint, and publishes the private GitHub Release; it refuses inside a session.
- Fixes from a session go to the newest open release and a new RC.

The session's core items, per milestone (the full checklist is `docs/sessions/M<n>-DEVICE-CHECKLIST.md`):

| Milestone | Device session covers |
|---|---|
| M1 | pair the phone at home with Proton VPN on and print the recovery sheet; pair the tablet, receiving the keys from the phone; revoke and re-pair the tablet; away from home the shelf says the hub is unreachable; install an RC and a release from the shelf |
| M2 | the example app's central-schedule backup overnight; an own-schedule backup shipped when home; restore the example app from a picked snapshot; the "not independent" flag |
| M3 | rates and a timetable reach the example app; data age shown; a source added on the tablet appears on the phone |
| M4 | a quiet mode holds the example app's notification; one sent as urgent breaks through; a digest arrives and opens its app |
| M5 | a settings change on the phone reaches the tablet; a clash on the same setting shows both versions; the recovery sheet restores the keys on a re-paired device |

Ecosystem items (RELAY's holidays, ASTROLABE's rates, real apps' backups) join the session of whichever release
follows that app's adoption (`01` §4.2).
