# Sync and storage — roadmap note

Status: **brainstorm record, 2026-10-25** (thread "APSIRA ECOSYSTEM BRAINSTORM"). Input to the central
app's planning thread; nothing here is built or scheduled. Rulings are Alejandro's; everything marked
*Claude's call* is a recommendation the planning thread may overturn. Decision: D-APK-023.

Two future completions of the ecosystem, independent of which app is developed next:

1. **Sync between devices.** Today RELAY on the phone and RELAY on the tablet are separate worlds.
2. **A home for backups.** One always-on place every app's backups reach, with an offsite copy.

Both belong to the central app (charter §4, D-APK-005): it is the only Apsira program with network
access, it owns sync, and it manages the apps' backups centrally while each app keeps its own backup
settings.

---

## 1. Rulings (2026-10-25)

| # | Question | Ruling |
|---|---|---|
| R1 | Where does sync happen? | **Home network only.** No tunnel, nothing reachable from outside the house. |
| R2 | How often is one item edited on two devices before they sync? | **Practically never.** Simple merge rules; no CRDT. |
| R3 | Which devices hold synced copies? | **Android phone, Android tablet, Fedora PC.** |
| R4 | Buy a NAS? | **No, not now.** amb811 is the home hub; a NAS is an optional later upgrade (§5). |
| R5 | Offsite copy | **Proton Drive** (plan of 1 TB or more), automated, ciphertext only. |
| R6 | What else is kept besides app backups | **Phone photos and videos** (under 200 GB today) and a **documents archive**. |
| R7 | Photo route | **Proton's own Android photo backup**, plus a copy on amb811. |
| R8 | Extra storage in amb811 | **An SSD** in the free bay (no HDD). |
| R9 | Governance | Only Apsira's charter and decision logs govern this. amb811 also hosts KEYSTONE, but KEYSTONE's rules do not apply to Apsira's use of it. |

---

## 2. Sync

### 2.1 Options weighed

| Option | How it works | Verdict |
|---|---|---|
| Whole-backup hand-off | A device restores another's latest backup | Rejected as sync: last copy wins everything, data is lost. Kept only as "move to a new device" (already possible). |
| Hosted sync engine (PowerSync, ElectricSQL) | Each app's SQLite syncs with a Postgres server | Rejected: the engine lives inside every app with network access, against charter §1.2 and D-APK-005. |
| CRDT database (cr-sqlite, Automerge) | Every table merges automatically | Rejected for now: heavy, hard migrations, cr-sqlite's maintenance has stalled; unnecessary given R2. |
| **Change log, transport-agnostic** | Each app records its changes; the central app carries them between devices | **Chosen** (*Claude's call*, fits R1–R3 and §1.4 of the charter). |

### 2.2 The chosen shape

- **The apps record, the central app carries.** Each app keeps a log of its own row changes. The central
  app on the same device collects that log, encrypts it, and hands it to the other devices; on arrival it
  gives each app the changes for that app to apply. How a change applies is the app's logic, never the
  central app's.
- **Transport is a detail.** The same change files travel either through a **mailbox on amb811** (§3.2) —
  devices drop and pick up files while at home, so two devices never need to be on at the same time — or
  **directly between devices** on the home Wi-Fi as a fallback. Designing the protocol so it does not care
  which is what lets a NAS replace amb811 later without touching any app.
- **Encrypted end to end.** The mailbox stores ciphertext only; it never needs to understand the data.
- **Attachments travel separately**, named by the SHA-256 of their content, so a file already present is
  never sent again.
- **A language-neutral, documented format** (as `apsira_exchange` is for exports): the Fedora PC's tomes
  are not Flutter, so a Dart package alone cannot be the contract. A shared Dart implementation for the
  folios sits on top of the spec.

### 2.3 Merge rules (*Claude's call*, from R2)

- **Newest edit wins, per field**, not per row: a title changed on the phone and a tag changed on the
  tablet both survive.
- **Timestamps from a hybrid logical clock** rather than the wall clock alone, so a device whose clock is
  off cannot silently win or lose; `apsira_core`'s `Clock` port and monotonic UUIDv7 are the starting point.
- **Deletes are soft** (`deleted_at`) and travel like any other change.
- **Safety net for long text:** when an incoming change overwrites a note body or other long text, the
  replaced version is kept in history, not dropped. The rare clash stays recoverable without CRDT cost.

### 2.4 What the apps already have, and what they will need

- **Have** (charter §1.4, RELAY D-014/D-023): UUIDv7 ids, `created_at`, `updated_at`, `deleted_at` on
  every user-data row; a versioned full export.
- **Will need:** a change log (or equivalent change capture) per app; per-field timestamps or an
  equivalent; a way to apply incoming changes inside the app's single write path; and the endpoint the
  central app talks to (§2.5). Each app's planning thread rules its own shape.

### 2.5 How the central app reaches the apps on Android

An app without the `INTERNET` permission cannot open **any** socket, including one to `localhost` on the
same phone. So the central app cannot talk to RELAY over a local port. It must use Android's on-device
IPC: a **bound service** or a **content provider**, which keeps every other app network-free.

Locking that channel to Apsira apps needs a permission only Apsira apps hold. Two ways:

- one **signing key** for every Apsira app (today RELAY has its own release key, D-090, and VIATICUM
  signs with the SDK debug key, D-059); or
- a permission with the **`knownSigner`** protection level (Android 12+), which lists each app's
  certificate digest and lets the keys stay separate.

This is a decision to take before the central app is built. The KAIROS link contract
(`relay/docs/kairos/05-link-contract.md`) already does mutual verification between two apps and is prior art.

### 2.6 The Fedora PC

On the PC, the central app's role is a small background service the tomes talk to, speaking the same
format. Whether the folios also get PC builds is out of scope here.

---

## 3. Storage and backups

### 3.1 Three copies

| Copy | Where | Protects against |
|---|---|---|
| 1 — live | Phone, tablet, PC (each app's own data) | — |
| 2 — local | amb811, on its own SSD | Device loss, a bad migration, an accidental delete; fast restore at home |
| 3 — offsite | Proton Drive, encrypted | Fire, theft, flood, amb811's failure |

That is the 3-2-1 rule: three copies, two kinds of storage, one offsite.

### 3.2 amb811 as the home hub

- **Hardware:** a desktop tower with a 2 TB SSD in use and at least one free bay. A **second SSD** in the
  free bay holds Apsira's area (R8), so a failure of the system disk does not take the backups with it.
  At under 200 GB of photos plus app backups and the archive, a 2 TB SSD leaves years of room.
- **Roles:** the sync mailbox (§2.2), the receiver of every app's backups, the local photo copy, the
  documents archive, and the job that sends the encrypted offsite copy to Proton.
- **Append-only backups** (*Claude's call*, an idea borrowed from how restic can be configured, not a
  rule): the routine writer can add snapshots but not delete them; pruning runs separately. Malware or a
  mistaken command running as the user then cannot erase the backup history.
- **After a power cut** amb811 needs unlocking at boot; until then sync and backups wait. Acceptable at
  home-only sync (R1), and worth knowing.
- **Charter wording to amend:** §1.1 says an Apsira app "runs no service on the KEYSTONE host". With amb811
  as Apsira's hub, that line needs rewording to say Apsira keeps its own area on amb811, independent of
  KEYSTONE. Left to the central app's planning thread, which knows exactly what will run there.

### 3.3 Proton Drive as the offsite copy

- **Safe enough:** Proton Drive is end-to-end encrypted, and the upload is restic-encrypted on top, so
  Proton holds ciphertext twice over.
- **Tooling, as of October 2026:** an official **Proton Drive CLI** (v0.9.0, 2026-10-05, Linux x64/arm64)
  is the usable path for scheduled uploads from amb811. The rclone backend is beta with no active
  maintainer. Proton's own Linux client is promised before the end of 2026.
- **Not the sync mailbox:** Proton's Drive SDK does not yet support authentication for third-party apps,
  and the Android app has no general folder sync, so the central app cannot use Proton as its transport.
  Revisit if the SDK opens up.
- **Photos (R7):** Proton's Android app backs photos up offsite by itself. The copy on amb811 is to be
  settled in planning: pull from Proton through the CLI (to verify: whether the CLI reaches the Photos
  section), or the phone sends photos home on Wi-Fi.

---

## 4. Open questions for the central app's planning thread

1. Signing: one key for every Apsira app, or `knownSigner` (§2.5)?
2. What runs on amb811 for the mailbox: plain SSH/SFTP to a restricted account, or a small service of the
   central app's own (§3.2)? Then the charter amendment.
3. Change capture per app: a log table written in the same transaction, or triggers (§2.4)?
4. The device-to-device fallback: built at the start, or only the mailbox first?
5. The photo copy route onto amb811 (§3.3).
6. Where the documents archive's master copy lives: amb811 with Proton as offsite, or Proton with amb811
   as the local copy.

---

## 5. A NAS, if it comes back

Deferred by R4. Snapshot of the market for when it does (late 2026):

| Box | Strength | Watch out for |
|---|---|---|
| UGREEN DXP2800 / DXP4800 (under €400) | Value; x86, so TrueNAS installs cleanly | UGOS is young, with a short security track record |
| Synology DS225+ / DS425+ | Most polished appliance; immutable snapshots | DSM 7.3 relaxed the third-party HDD lock for 2025 models; M.2 still needs listed drives |
| Synology DS925+, UGREEN DXP4800 Plus/Pro (€400–700) | Mainstream 4-bay; the UGREEN has 10GbE | As above |
| Minisforum N5 Pro (higher) | A small server more than a NAS (Ryzen AI 9, ECC, 5 SATA + 3 NVMe) | Price, external power brick; you run TrueNAS or Linux |
| QNAP TS-464 | Features | Repeated ransomware campaigns (Qlocker, Deadbolt); not recommended here |

Hard drive prices rose through 2026 (AI data-centre demand; Western Digital reports 2026 capacity
essentially sold out). Because §2.2 keeps the transport a detail, a NAS later only replaces the mailbox
and the local copy on amb811; no app changes.

---

## 6. Watch list

- **Android developer verification.** Google's requirement that sideloaded apps come from verified
  developers starts in a few countries in 2026, wider in 2027; installs over ADB are reported exempt.
  Every Apsira folio is sideloaded, so its final shape matters to the whole roster.
- **Proton:** the Linux client and the Drive SDK's third-party authentication (§3.3).

## Sources

- Proton Drive CLI: <https://proton.me/download/drive/cli/index.html>; Linux status:
  <https://rafaelpfister.ch/en/blog/proton-drive-on-linux-status>; SDK:
  <https://proton.me/blog/drive-sdk-january-2026>; rclone backend: <https://github.com/rclone/rclone/issues/8873>
- Drift and sync engines: <https://drift.simonbinder.eu/examples/server_sync>
- Synology DSM 7.3 drive policy:
  <https://nascompares.com/2025/10/08/synology-dsm-7-3-nas-hdd-ssd-compatibility-in-the-plus-rs-xs-xs-sa-and-more/>
- UGREEN range: <https://wundertech.net/best-ugreen-nas/>; Minisforum N5 Pro:
  <https://www.servethehome.com/minisforum-n5-pro-review-an-awesome-nas-platform/>
- 4-bay overview: <https://www.starryhope.com/nas/best-4-bay-nas/>
- Drive prices: <https://www.tech4gamers.com/hard-drive-supply-shortages-get-even-worse/>,
  <https://www.10news.com/science-and-tech/hard-drive-maker-says-its-nearly-sold-out-for-2026>
- TrueNAS 2026: <https://www.truenas.com/blog/truenas-plans-for-2026>
