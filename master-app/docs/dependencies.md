# Dependencies

Every package in the app's and the hub's `pubspec.yaml`, every Android library, every external binary the hub runs
and every bundled asset: why it is here, its licence, who maintains it and whether it can do network I/O. APSIRA is
the one folio-class app that holds `INTERNET` (D-001, D-024), so the network column matters more here than anywhere:
**the app's only network path is the hub client**, and the hub's only outbound paths are the fetchers D-007 and D-011
name. Exact versions are pinned by the committed `pubspec.lock` files and the Gradle files.

A dependency added or removed changes its row here in the same task (`agent-rules.md`).

## 1. Decided

### 1.1 The Apsira packages (D-017, D-023)

All at one shared tag `apsira-vX.Y.Z` by git reference to `amartb/apsira`, never a committed path (D-APK-007),
even though the packages sit in the same repository. Licence proprietary (Apsira); maintained by Apsira Labs.

| Package | Used for | Network I/O |
|---|---|---|
| apsira_core | `Result`, `Failure`, log model, `Clock`, `IdGen`, canonical JSON; shared by the app and the hub | none |
| apsira_ui | tokens, theme, kit, fonts, the lockup and the symbol | none |
| apsira_app | error handlers, file log, start redirect, restartable root, per-install flags, About | none |
| apsira_l10n | the shared EN/ES strings, the language setting | none |
| apsira_onboarding | first-open intro, language step, Help | none |
| apsira_db | the database opener, snapshot, safe mode, migrations | none |
| apsira_lock | the lock, with the mandatory mode D-018 needs (a package change, D-017) | none |
| apsira_notify | APSIRA's own channels, the digest notification, the permission flow; the policy check's host side (D-012) | none |
| apsira_jobs | `BackgroundJobs` for the central backup schedule and the home check | none |
| apsira_storage | the ports APSIRA uses itself; the APSIRA `BackupTarget` adapter lives here for the apps (D-008) | none |
| apsira_link | **new** (D-017): the on-device link's shared types and the client the apps use | none (Android IPC) |
| apsira_tools | dev: layering lint, l10n check, coverage gate, deps and manifest checks | host tooling |
| apsira_test | dev: golden matrix, large-text check, a11y pass, property testing | none |

`apsira_exchange` and `apsira_zip` are not needed in v1; the cross-app overview (D-021) will take
`apsira_exchange`.

### 1.2 The stack

As the folios' (D-023): Drift, sqlite3, Riverpod, go_router, freezed, intl, flutter_localizations, path_provider,
flutter_lucide, workmanager (through `apsira_jobs`). Versions are those the newest folio pins; P0 records the rows
here with their versions, as ASTROLABE's `dependencies.md` §1.2 does.

## 2. Candidates to verify (each slice confirms, records the row, or rejects with a reason)

| Need | Candidates | Slice | What to verify |
|---|---|---|---|
| Hub runtime | Dart SDK (the version Flutter 3.47.7 ships), compiled with `dart compile exe` | 1 | runs as a system service without the Flutter SDK; licence BSD-3-Clause |
| Hub HTTPS with client certificates | `dart:io` `SecureServerSocket` with `requestClientCertificate` | 1 | mutual TLS with a pinned client set; no extra package |
| App HTTPS client with a client certificate from the Android Keystore | a Kotlin client (OkHttp or `HttpsURLConnection`) behind a `HubClient` port, since `dart:io` cannot use a non-exportable Keystore key | 1 | the private key never leaves the Keystore; pinning to the hub's certificate; OkHttp Apache-2.0 |
| Certificates | `pointycastle` or `basic_utils` on the hub for the device CA and device certificates | 1 | maintained, licences; no network path |
| Pairing QR decoder (D-029) | CameraX preview with a zxing-cpp-family on-device decoder (ATRIUM D-046's engine family, not ATRIUM's code); `mobile_scanner` only if it bundles no Google/ML Kit path | 1 | on-device only, no network path; nothing written; used by the pairing screen alone |
| Vault and sync key crypto (D-028) | Android Keystore wrapping (AES-GCM) with an authenticated stream cipher for the seals (e.g. libsodium secretstream or AES-GCM in chunks via `cryptography`) | 1 | streaming for large backups; the format named in `contracts/sync-envelope.md`; licences |
| APK checks before install | Android `PackageManager.getPackageArchiveInfo` with `GET_SIGNING_CERTIFICATES`; SHA-256 from `crypto` | 1 | the certificate is read from the archive before `PackageInstaller` is called |
| GitHub release fetch | `gh` CLI or the REST API over `dart:io` with a fine-grained read-only token | 1 | the token stays in the hub account's secret file, never in the process list or a log |
| Snapshot engine | **restic** (BSD-2-Clause), as an external binary | 2 | Fedora package version; encryption, deduplication; `restic forget --prune` behaviour under the thinning policy |
| Append-only server | **rest-server** (BSD-2-Clause) with `--append-only` | 2 | serves the repository on a local socket or loopback only; the hub account cannot delete; the store account prunes directly |
| Rate source | ECB euro reference rates (daily XML) | 3 | terms of use; format stability |
| Holiday source (D-030) | **OpenHolidays API** (open data with Spain's regions), packs built in KAIROS's own format | 3 | coverage of his regions; licence of the data; the format's stability; live only once RELAY's thread accepts it in place of K-094 |
| GTFS source | Spain's National Access Point | 3 | per-feed licences; feed URLs and validity fields |

## 3. Rejected

| Candidate | Why |
|---|---|
| A hosted sync engine (PowerSync, ElectricSQL) | puts network access in every app (D-APK-023) |
| A CRDT database (cr-sqlite, Automerge) | cost unjustified; edits rarely clash (R2) |
| rclone's Proton backend | beta, no active maintainer (`sync-and-storage.md` §3.3); Proton is copied by hand in v1 |
| `knownSigner` permission, one shared signing key | D-016 |
| A notification listener | APSIRA reads no other app's notifications in v1 (D-012) |
