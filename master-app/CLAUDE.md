# CLAUDE.md — working on APSIRA (the master app)

APSIRA is the Apsira ecosystem's **master app**: a Flutter app on the Android phone and tablet plus a Dart **hub**
on amb811, which together carry the Apsira apps' backups home, install the operator's own releases, fetch internet
data for apps without network, govern their notifications and (from v2) sync them (D-001, D-006). Claude Code
writes the code; Alejandro rules, tests on his phone and merges. It lives in the `apsira` repository under
`master-app/`, beside the `apsira_*` packages.

**Read before any work**, in this order: `docs/01-vision-and-scope.md`, `02-decision-log.md`, `03-roadmap.md`,
`04-data-model.md`, `05-architecture.md`, `06-ux-and-screens.md`, `07-phase-plans.md`, `08-testing-and-ci.md`,
`09-security-model.md`, the contract your task touches (`docs/contracts/`), and the unit's
`docs/sessions/P<n>-KICKOFF.md`. Hub work also reads `10-hub-runbook.md`. When this file and a doc disagree, **the
doc wins**; fix this file in the same commit.

## 1. Non-negotiables

Breaking one is a bug, even if the tests pass. `docs/agent-rules.md` carries them into every army brief.

1. **The network bar** (D-005). In v1 the app talks to one host: the paired hub, over mutual TLS. Planned fetches
   (releases, holidays, rates, timetables) are the hub's, never the phone's. No real-time source exists until one is
   ruled.
2. **Never lose what is kept** (D-008). The store is append-only for the hub account; only `apsira-store` prunes.
   Backups and offloaded documents are sealed on the device with the vault key; the hub never holds it (D-028).
   App schema changes ship with a migration, a `drift_schemas/` dump and a migration test; soft deletes only.
3. **Trust on every call** (D-015, D-016). Device ↔ hub: mutual TLS pinned from the QR pairing. App ↔ APSIRA: the
   caller's package and signing-certificate fingerprint, on every call, as `docs/contracts/app-link.md`; only apps with
   their own release key are trusted, never a debug certificate (D-031).
4. **The apps stay standalone.** Every client path treats APSIRA missing as "unavailable", never as an error that
   stops the app (D-012, D-016).
5. **Shared code goes in the packages** (D-017). What an app needs to talk to APSIRA lives in `apsira_*`; nothing
   is copied into an app or into APSIRA.
6. **Always locked** (D-018). The lock cannot be disabled; install, restore, pair and revoke re-confirm.
7. **No secrets in records.** Keys (device, sync, vault), the store password, the GitHub token, pairing codes and device certificates
   never enter a log, a ledger, a report or a commit.
8. **Hub tests are sandboxed.** Never act on the real host's accounts, groups, systemd units, firewall, store or
   `~/projects/*-builds/`; tests use scratch directories and fakes.
9. **Single write path** in the app: only `lib/app/services/` write, one transaction per user action.
10. **The domain is pure Dart.** Time and ids only from `Clock` and `IdGen`.
11. **Both languages.** Every string in `app_en.arb` and `app_es.arb` in the same commit.
12. **Design tokens only.** `apsira_ui`; dark by default; colour as an accent; a border on every card. The icon is
    the Apsira symbol, unchanged (D-002).
13. **The release key and the GitHub token never enter a session** (D-002, D-007); RCs are signed by the release
    script outside any session, the conductor builds `dev` APKs only (D-035).
14. **The camera is for pairing only** (D-029): no other screen opens it, nothing is saved.

## 2. How a task is done

The build runs as project-agents army units, one slice per unit (D-026), configured by the lane P0 sets up, with
`docs/agent-rules.md` and `docs/assurance-rules.md`. Package work runs in the `apsira` lane under the repository's
own `docs/agent-rules.md`; each app's adoption runs in that app's repository.

1. Find the task in the unit's `01-plan.md` (from `docs/07-phase-plans.md`); read the doc sections it names.
2. Work on its lane; never on `main`. Each task lands as one squash commit `<type>(P<n>-<nn>): <summary>`.
3. Implement with tests (`08`); run format, analyze and your own tests only.
4. Update the docs and decision entries your change affects in the same commit (append-only log).
5. Note any on-device or on-host check as `Device check:` or `Host check:` in your report.

## 3. Architecture quick reference

`docs/05-architecture.md` is the authority (interfaces: `docs/contracts/`; the hub host: `10-hub-runbook.md`; D-032); P0 confirms the layout. The app follows the folio layout:

```
master-app/
  lib/app/       bootstrap, router, theme, l10n, services/ ← the only write path
  lib/core/      ports (Clock, IdGen, HubClient, Installer, AppLink, …)
  lib/domain/    pure Dart: shelf, backups, gateway, regime, sync core
  lib/data/      db/ (Drift), hub/ (channel to the Kotlin mutual-TLS client, D-027), link/, install/
  lib/features/  <feature>/ui + state; no cross-feature imports
  android/…/apsira/  link/ (content provider via ContentResolver.call, fingerprint check), hubclient/, installer/, keystore/, scanner/
  hub/           the Dart hub service on amb811 (D-014)
```

Import rules as the folios', enforced by `apsira_tools:layering_lint`.

## 4. Commands

Toolchain on PATH: Flutter 3.47.7 (`~/sdk/flutter/bin`), `JAVA_HOME=~/sdk/jdk-17`, `ANDROID_HOME=~/sdk/android`.
P0 and P1 write the scripts; this section lists them as built (`08`).

| Command | Does |
|---|---|
| `flutter pub get` | resolves `pubspec.yaml`; the `apsira_*` packages by git at the shared tag |
| `dart format .` · `flutter analyze` · `flutter test <file>` | what a task runs on its own work |
| *(written in P0/P1)* | codegen, area tests, Kotlin unit tests, hub tests, the dev APK, the full check |
