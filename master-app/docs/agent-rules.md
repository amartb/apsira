<!-- army:doc type=rules -->
# APSIRA (the master app) — standing rules for army agents

Every brief carries these, on top of the army's own. `../CLAUDE.md` is the guide; the docs win over both
(`02-decision-log.md`, `03-roadmap.md`, `00-brief.md`). Read the sections your task names. Package work under
`apsira/packages/` follows the repository's own `apsira/docs/agent-rules.md`, not this file.

## Non-negotiables (breaking one is a bug even when tests pass)
- **The network bar** (D-005): the app opens connections only to the paired hub, over mutual TLS pinned from the
  pairing (D-015). Planned fetches (GitHub releases, holiday packs, rates, timetables) are the hub's; the app never
  fetches them. No real-time source, no other host, no dependency doing network I/O except the hub client. The hub
  fetches only from the sources the decision log names, over TLS.
- **Never lose what is kept** (D-008, D-014): the hub account can add snapshots, never delete them; pruning belongs
  to `apsira-store` alone. App schema changes ship with a Drift migration, an updated `drift_schemas/` dump and the
  migration-chain test; soft delete only. Sync never discards an edit (D-APK-023).
- **Trust on every call** (D-016, `contracts/app-link.md`): the content providers (called only through
  `ContentResolver.call`, no bound service) check the caller's package and `hasSigningCertificate` on every call; no
  call is answered before the check; a refusal says `not_authorised` and logs nothing about the caller beyond the
  code. A dev build trusts only dev builds; a release build never trusts a debug certificate, and only apps with
  their own release key are in the table (D-031).
- **The apps stay standalone**: every client path in `apsira_link` treats APSIRA missing, locked or the hub
  unreachable as "unavailable"; an app never blocks on APSIRA.
- **Shared code comes from `apsira_*`** (D-017): pinned by the shared tag, never a committed `path:`. Nothing in
  `relay/`, `viaticum/`, `lyceum/`, `atrium/`, `astrolabe/`, `stylus/` or `project-agents/` is edited from this lane;
  they are read with `git show`. A package gap is a proposal in the report.
- **The hub never reads content** (D-028): backups and offloaded documents are sealed on the device with the vault
  key before they leave it; no hub path, file, log or test fixture holds the sync or vault key.
- **The camera is for pairing only** (D-029): no other screen or feature opens it; nothing is saved from it.
- **Secrets never enter records**: keys (device, sync, vault), the recovery sheet, the store password, the GitHub
  token, pairing codes, device certificates and private keys are never printed, logged, committed or written into a
  ledger or report. Content (file names,
  document titles, notification text) is redacted in logs.
- **The release key and the GitHub token never enter a session** (D-002, D-007): never generate, request, print or
  store them; never run the release script, in either mode. RCs are signed by it outside any session; a session
  builds `dev` APKs only (D-035).
- **Hub tests are sandboxed** (`08`): never create, change or remove a real account or group, a systemd unit, a
  firewall rule, the real store, the real archive or anything under `~/projects/*-builds/`; never start `restic` or
  `rest-server` against a real path. Tests use scratch directories, fake binaries or a throwaway repository under the
  lane's own temp area, disposed when the test ends. Host-acting steps are written into `10-hub-runbook.md` for the
  operator, never run.
- **Which document wins** (D-032): the decision log; then the contracts for interfaces, `10-hub-runbook.md` for the
  hub's host layout, `09` for threats and keys; `04`/`05` follow them.
- **At the plan's depth**: build what the plan and the decisions describe. A feature, setting or screen they do not
  name is a `Needs ruling:` line, never an addition. D-021 lists what is dropped; do not add it back. Third-party
  notifications, phone automation and restore drills are out.
- **Always locked** (D-018): no path shows data or acts before the lock; install, restore, pair and revoke
  re-confirm.
- **Large text**: every new or changed screen passes the layout check at 1.0–2.0 in EN and ES on 412 and 360 dp.
- **Both languages** (charter §1.7): every ARB key in `app_en.arb` and `app_es.arb` in the same commit.
- **Layers** (`05`): a feature never imports `data/`, another feature or a plugin; every platform touch is a port
  with a fake; `layering_lint` stays at zero.
- **UI** (`06`): colours, type and shapes from `apsira_ui`; no colour literal outside `lib/app/theme/`; the icon is
  the brand symbol, copied unchanged with its provenance (charter §3).

## How work is recorded here
- Task ids are the plan's (`P1-03`, split parts `P1-03a`). Intermediate lane commits start with `wip`; exactly one
  lane commit carries `<type>(<task id>): <summary>`, which the integrator's squash takes.
- Decisions go only in `docs/02-decision-log.md`, append-only: a new `D-nnn` supersedes; spike results and rulings
  are addenda. A package change is a `D-APK-nnn` in `apsira/docs/decisions.md`, made in the `apsira` lane.
- A dependency or hub binary added or removed changes its row in `docs/dependencies.md` in the same task.
- A contract change (`docs/contracts/`) bumps its version and says what a peer must change.
- Never skip, weaken or delete a failing test to make a gate pass.
- An on-device check goes in the report as `Device check:`; an on-host step as `Host check:`. The conductor
  gathers them into the slice's release session.

## Checks are proportionate (`docs/assurance-rules.md`)
- A task runs `dart format`, `flutter analyze` (`dart analyze` for the hub) and only the tests it wrote or changed.
  Never the whole suite, never the full check, never an APK build. Re-read your diff before you report.
- Area gates, the full check and coverage are validator-only.

## This host
- The operator's shared workstation (amb811), which is also the hub's host: other threads build other apps here.
  Builds and tests run under `army lease run` / `army gates run`; one full suite at a time host-wide; never signal a
  process you did not start; clean your lane's build output and scratch stores when done.
- The Android SDK is present, JDK 17; no emulator, no CI. Kotlin and manifest changes are proven by Robolectric and
  stay unproven on a device until the slice's release session: say so, never claim a build you did not run.
