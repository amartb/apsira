# APSIRA — Brief

Compiled by the APSIRA PLANNING thread (2026-10-30). Unlike the siblings, APSIRA had no brief in `folios/` or
`tomes/`: its input was the operator's opening message of that thread together with the two roadmap notes it pointed
to, `docs/roadmap/master-app.md` (rulings M1–M7) and `docs/roadmap/sync-and-storage.md` (rulings R1–R14, D-APK-023).
This file states that input. It is not the design: the thread departed from it wherever the decision log
(`02-decision-log.md`) says so, most visibly in moving most of sync to v2 (D-013) and in setting a network bar the
notes did not have (D-005).

---

## 1. The ecosystem, as the operator put it

Apsira is a family of apps (RELAY, VIATICUM, LYCEUM, ATRIUM, ASTROLABE, and more planned) made for one person and
the way he likes things. It is not a commercial project, though an app may earn that promotion in the long term. It
is not cloning other apps: RELAY is a note-taking app, others exist, but RELAY is made exactly his way.

The ecosystem has a **master app, APSIRA**, that manages what the other apps deliberately do not: **internet
access, sync, centralised backups** and the like. Its code lives in the `apsira` repository under `master-app/`.
Shared, standardised code comes from the `apsira_*` packages in the same repository, so no app re-develops it.

The thread was asked to plan the master app — scope, infrastructure, functions, capabilities — through batches of
multiple-choice questions, free to explore beyond the roadmap notes and to reassess them; then to write the planning
documents in the set the sibling apps use, adding any document the master app needs. No development.

## 2. What the roadmap notes had recorded

**Rulings on the master app (`master-app.md`, 2026-10-30):** PC control and the army companion live in the master
app family (M1–M3) but in a **separate console app**, split by privilege (M5); reach is the home network now, a
self-run VPN later (M4); every older recorded slice is kept (M6); the sequence is STYLUS, then the master app, then
the console (M7).

**Capabilities recorded for the master app:** sync; backup home; reaching the apps through Android IPC; a network
gateway (fetcher) for apps without `INTERNET`; mail for PRISM on the phone; reading the apps' export bundles; a
cross-app overview; a build shelf; a notification inbox; phone automation; accounts only if ever needed.

**Sync and storage (`sync-and-storage.md`, D-APK-023):** home-network-only sync (R1) among the phone, the tablet
and the Fedora PC (R3), by a transport-agnostic change log the master app carries, merged per field and additively,
no edit ever discarded (R10–R14), no CRDT (R2); amb811 as the home hub on its own SSD (R4, R8) with Proton Drive as
the encrypted offsite copy (R5); photos and a documents archive kept besides app backups (R6, R7); only Apsira's
own rules govern its use of amb811 (R9).

**Open questions handed to planning:** signing (one key or `knownSigner`); what runs on amb811 for the mailbox;
change capture per app; the device-to-device fallback; the photo route; the documents archive's master copy; the
charter amendment for two network-holding apps; what the console and the master app share; ATRIUM's "central-app
hooks" (ATRIUM D-040); the VPN for M4.

Where each was answered: `02-decision-log.md` (D-001–D-036; signing is D-016, not `knownSigner` and not one key).
