# The master app — roadmap note

Status: **brainstorm record, 2026-10-30** (thread "next apps after STYLUS"). Consolidates every capability of
the central Apsira app ("the master app") recorded so far across this repository and the app repositories, and
the rulings of this thread. Input to the master app's planning thread; nothing here is built or scheduled.
Rulings are Alejandro's; everything marked *Claude's call* is a recommendation planning may overturn.

---

## 1. Rulings (2026-10-30)

| # | Question | Ruling |
|---|---|---|
| M1 | Where does PC control (SSH to amb811 and amb8) live? | **In the master app family**, as its first slice, not as a folio with its own network exception. |
| M2 | What PC control does from the phone | **Health at a glance and one-tap actions.** No full terminal, no file or clipboard transfer. |
| M3 | The agent army from the phone | **Part of PC control**: watch runs, answer rulings, approve steps. Launching and stopping runs is out. |
| M4 | Reach | **Home network now, a self-run VPN later** (recorded, not built). Same as sync's R1 until then. |
| M5 | One app or split by privilege | **Two apps**: the master app (sync, backups, gateway and the slices in §3) and a separate **console** (PC control and the army companion). A compromise of one never reaches the other's keys. |
| M6 | Older recorded slices | **All kept**: build shelf, notification inbox, phone automation, cross-app overview (§3). |

**Consequence for the charter (to amend in planning):** §1.2 and D-APK-005 name one program with network access.
M5 makes it two Apsira apps: the master app and the console. Folios and tomes are unchanged.

---

## 2. The console (PC control and the army companion)

- **Machines:** amb811 (Fedora, the home hub) and amb8 (Ubuntu).
- **Health:** uptime, disk, memory, temperatures, failed units, backup and sync-mailbox status.
- **One-tap actions:** restart a service, run a backup, update, reboot, Wake-on-LAN.
- **Army companion:** live runs (stage, lane, liveness, gate results), ledgers and reports readable; pending
  rulings answered by picking an option; approve-list items ticked. Operator-typed privileged lines stay on the
  PC.
- *Claude's call:* actions are an **allowlist defined on the PC** (a restricted account with a forced command);
  the phone invokes entries by name and never sends free-form shell, so a lost phone cannot run arbitrary
  commands. Destructive entries ask for confirmation. The SSH key lives in Android's hardware keystore behind
  biometrics.
- Not KEYSTONE: what the console reads on amb811 is Apsira's own area (`sync-and-storage.md` R9, §3.2).

---

## 3. The master app — capabilities recorded so far

| Capability | What | Source |
|---|---|---|
| **Sync** | Change-log sync on the home network, mailbox on amb811, device-to-device fallback, end-to-end encryption, QR pairing, revocation, Conflicts list | D-APK-005, D-APK-023, `sync-and-storage.md` R1–R14 |
| **Backup home** | Every app's backups to amb811's own SSD, append-only snapshots, Proton Drive offsite, photo copy, documents archive | D-APK-023, `sync-and-storage.md` §3 |
| **Reaching the apps** | Android on-device IPC (bound service or content provider), locked to Apsira signers; a small background service on the PC for the tomes | `sync-and-storage.md` §2.6–2.7 |
| **Network gateway (fetcher)** | One place that fetches for apps without `INTERNET` and hands data over by link: KAIROS holiday packs, ASTROLABE currency rates, TRANSIT feeds and later live arrivals, on-device transcription models | RELAY K-046; ASTROLABE D-017; ATRIUM brief; `app-ideas.md` |
| **Mail for PRISM on the phone** | Through the gateway; Proton kept via Proton Bridge headless on amb811, or dropped from the phone version | `app-ideas.md` order §3; PRISM brief |
| **Export import** | Reads each app's `apsira_exchange` export bundle (LYCEUM, STYLUS, ASTROLABE, ATRIUM, RELAY) | LYCEUM roadmap; STYLUS roadmap; ASTROLABE D-025; ATRIUM D-023 |
| **Cross-app overview** | One search and a "today" view across the apps, built on the export bundles and links | `app-ideas.md` (homelab console row); M6 |
| **Build shelf** | Install and update his own Apsira APKs from amb811 builds, with versions and changelogs | `app-ideas.md`; M6 |
| **Notification inbox** | Rule-based triage of phone notifications | `app-ideas.md`; M6 |
| **Phone automation** | Rules as code (for example: home Wi-Fi → sync) | `app-ideas.md`; M6 |
| **Accounts** | Only if ever needed; no app holds them | LYCEUM D-018 |

The homelab console row of `app-ideas.md` (amb811 health, backups, sync mailbox) moves to the console (§2).

---

## 4. Open questions for planning

From `sync-and-storage.md` §4, unchanged: signing (one key or `knownSigner`); what runs on amb811 for the
mailbox; change capture per app; the device-to-device fallback; the photo route onto amb811; the documents
archive's master copy. Added here:

1. The charter amendment for two network-holding apps (§1), and the §1.1 wording on amb811 (`sync-and-storage.md` §3.2).
2. What the console and the master app share (signing, `apsira_*` packages) and what they must never share (keys, stores).
3. How the army exposes rulings and approve lists to the console: a read path into `build/sessions/` ledgers and a
   narrow write path for answers.
4. ATRIUM's "central-app hooks", recorded out of its v2 (ATRIUM D-040), to be named.
5. The VPN for M4: when, and what it exposes.
