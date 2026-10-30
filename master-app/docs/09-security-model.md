# APSIRA — Security model

Status: **written by the APSIRA PLANNING thread, 2026-10-30** (living document)

What APSIRA protects, from whom, where the trust boundaries run, and which keys exist and how each is recovered.
The decisions are in `02-decision-log.md`; the host steps are in `10-hub-runbook.md`; the wire rules are in
`contracts/`. Where this file and a decision disagree, the decision wins; fix this file in the same commit.

Priority order for every trade-off (operator's standing rule): security and operational sustainability, then
quality, then data protection, then robustness, then speed.

---

## 1. Assets

| Asset | Where | Why it matters |
|---|---|---|
| App backups (every folio's data) | Sealed on the device with the vault key (D-028), then the snapshot repository on the hub (D-008); copied by hand to Proton | His whole personal record, in one place |
| Offloaded documents | Sealed on the device (D-028), then the archive on the hub (D-010) and its snapshots | Once offloaded, **the phone holds no copy** |
| The power to install apps | APSIRA on the device (`REQUEST_INSTALL_PACKAGES`, D-007) | Code execution on the phone |
| The camera | APSIRA's pairing screen only (D-029) | A capture surface; nothing is saved |
| Device keys | Android Keystore on each paired device (D-015) | They open the hub |
| Hub TLS key, device CA key | The hub's state area | Impersonating the hub; minting device certificates |
| Vault key and sync key | Each paired device; the printed recovery sheet; **never the hub** (D-028) | Open every backup, archive item and mailbox envelope |
| Repository password | `/etc/apsira/` on the hub, plus the operator's recovery copy | Opens the restic layer only; what it holds is already sealed |
| GitHub read-only token | `/etc/apsira/` on the hub (D-007) | Reads the app repositories' contents, source included |
| Release keys (every app's, APSIRA's) | The operator's own folders and password manager, **never the hub** | Signing what the shelf trusts |
| Gateway data | Hub cache, then the apps | Public data; integrity matters, secrecy does not |
| Hub configuration (sources, cadences, shelf apps) | Plain on the hub (D-033) | Low; no personal content |
| APSIRA's personal settings | Synced through the core from slice 5 (D-013, D-033) | Low; a wrong regime mutes notifications |

## 2. Trust boundaries

| Boundary | Who is on each side | What crosses | What enforces it |
|---|---|---|---|
| Device ↔ hub | APSIRA on a paired device; the `apsira` account on amb811 | Backups, restores, archive items, shelf APKs, gateway data, sync envelopes | Mutual TLS pinned both ways (D-015); LAN-only firewall rule; the hub never initiates; tier 1 and 2 only at home (D-005) |
| APSIRA ↔ an Apsira app | Two app sandboxes on one device | Backup streams, restore streams, policy answers, gateway payloads, offload items | Per-call package name **and** certificate-fingerprint check on both sides (D-016, `contracts/app-link.md`); every call scoped to the caller's own data |
| APSIRA ↔ any other app | — | Nothing | The same check refuses it; no exported surface without it |
| Hub ↔ internet (tier 2) | The `apsira` account; named sources | Outbound HTTPS only: release assets, open holiday data (D-030, dark until RELAY agrees), rates, GTFS feeds | Host allowlist in the hub's config (`10` §8.3); TLS validation; size limits; payloads parsed as untrusted (§5.6). No inbound path from the internet |
| Phone ↔ internet (tier 3) | APSIRA; an approved real-time source | Nothing in v1 | When ruled per source: Proton VPN, one host, a pinned certificate (D-005) |
| Hub service ↔ store | `apsira` (writer) ↔ `apsira-store` (owner) | New snapshots | `rest-server --append-only` on loopback with its own password; `apsira` has no file permission on the store (D-014) |
| Operator login ↔ hub | `alejandro` ↔ `apsira`, `apsira-store` | Read-only: the store and the archive, both ciphertext, for the Proton copy | The `apsira-read` group, no write bit; services run with `ProtectHome=yes`, so they cannot see `/home` |
| Hub ↔ builds folders | `apsira` ↔ `~/projects/<app>-builds/` | RC APKs and their `.sha256` | Read-only bind mounts under the data root, one per app, with no traversal of the operator's home (`10` §4.3) |
| APSIRA ↔ console | Two apps, two sandboxes, two keys | Nothing | Separate apps (D-020); the console uses its own SSH account and forced-command allowlist; APSIRA holds no SSH key and runs no command on amb811 |
| Apsira ↔ KEYSTONE on amb811 | Different accounts, different services | Nothing | No shared database, port, proxy, container or account; charter §1.1 as amended (R9) |

## 3. Keys and their recovery

| Key | Created by | Held where, readable by | If lost | If compromised |
|---|---|---|---|---|
| Device key (per device) | APSIRA at pairing | Android Keystore, hardware-backed, non-exportable; usable for background work without a fresh authentication (D-015 addendum); APSIRA's lock gates the screens and the sensitive acts (D-018) | Re-pair the device (QR at home) | Revoke the device from another device or on the hub (D-015) |
| Hub TLS key and certificate | The operator at P0 (`10` §5) | `/var/lib/apsira-data/hub/tls/`, `apsira` only | New certificate; every device re-pairs (its pin changes) | Same, then review the hub account (§5.4) |
| Device CA key | `apsira-hub init` at P0 (`10` §5) | `/var/lib/apsira-data/hub/tls/`, `apsira` only | New CA; every device re-pairs | Same; a minted certificate still cannot open a sealed backup (D-028) |
| Vault key and sync key | The first device paired with the hub (`contracts/sync-envelope.md` §6) | Each paired device's Keystore-wrapped storage; the **printed recovery sheet**; sealed to a new device through the hub and deleted there once fetched; **never held by the hub in any form** (D-028) | From another paired device, or typed from the sheet. With neither, **every backup, archive item and envelope is lost** — the sheet is printed before the first backup | New keys from a trusted device; new backups sealed with them; old snapshots treated as exposed |
| Repository password | The operator at P0 (`10` §6) | `/etc/apsira/restic-password`, group `apsira-keys` (`apsira`, `apsira-store`); recovery copy in the password manager entry **APSIRA hub** | The restic layer cannot be opened; the recovery copy is mandatory before the first backup | Rotate with `restic key add` / `key remove`; contents stay sealed by the vault key, so exposure reveals sizes and timing only |
| `rest-server` password | The operator at P0 | `/etc/apsira/rest.htpasswd` (hash, `apsira-store`), the plain value in `/etc/apsira/rest-password` (`apsira` only) | Set a new one | Set a new one; it grants appending only |
| GitHub token | The operator on github.com (`10` §7), never in a session | `/etc/apsira/github-token`, `apsira` only | Create a new one | Revoke it on GitHub; it reads repository contents (source and releases) of the selected repositories only, and writes nothing |
| Release keys | The operator, per app (each `release-signing.md`) | Never on the hub or a device; the shelf holds only their **public fingerprints**, compiled into APSIRA (D-016) | As each app's `release-signing.md` | Outside APSIRA: the app's own thread; APSIRA's fingerprint table changes only by an APSIRA release |

## 4. Append-only guarantees

- The hub service writes snapshots through `rest-server --append-only`: it can add packs, indexes and snapshots and
  read them, never delete or overwrite (D-008, D-014).
- Pruning (thinning, D-008) runs only as `apsira-store`, from its own timer, against the repository path directly.
- The operator's login reads the store through `apsira-read`; no write bit, so malware running as the operator
  cannot erase the history either.
- Confidentiality does not rest on the store: every backup and archive item is sealed on the device before it
  arrives (D-028), so the repository password and the `apsira` account open ciphertext only (§5.4).
- Not guaranteed: a root compromise of amb811 (§7); a disk failure (the SSD and the Proton copy answer that).

## 5. Threats

### 5.1 Lost or stolen device

| Step | Effect |
|---|---|
| APSIRA is always locked (D-018) | Opening APSIRA needs biometrics or the PIN; install, restore, pair and revoke re-confirm |
| Device key in the Keystore | Non-exportable; usable in the background (D-015 addendum), so a thief with the powered-on phone **inside the house** could let background jobs reach the hub, but cannot open APSIRA's screens or run an install, restore, pair or revoke |
| Hub reachable from the LAN only | Away from home the device cannot reach the hub at all |
| Revocation (D-015) | From the other device or on the hub: the hub refuses the device's certificate from then on |
| Mailbox and vault | Envelopes already pulled stay on the device; new ones are not served; rotate the sync and vault keys if the device was unlocked |

The apps' own data on the device is the phone's and each app's concern (their locks, Android's file encryption).

### 5.2 A compromised Apsira app

An exploited folio still passes the fingerprint check, because it is the real app. It can do only what that app may
do: push its own backups, request its own restores, read public gateway data, ask the notification policy, and (ATRIUM
only) offload and fetch its own archive items. Every call is scoped to the caller's package
(`contracts/app-link.md`); it can never list or read another app's backups or archive items.

### 5.3 Any other app on the device

Fails the package-and-fingerprint check on every call and receives `not_authorised` with no data
(`contracts/app-link.md`). APSIRA exports nothing that skips the check.

### 5.4 A compromised hub account (`apsira`)

| It can | It cannot |
|---|---|
| Read the hub's state (device registry, hub configuration, gateway cache) and the sizes and timing of everything | Delete or rewrite snapshots (§4) |
| Open the restic layer, since it holds the repository password | Read a backup, an archive item or a mailbox envelope: all sealed on the devices with keys it never holds (D-028) |
| Serve false gateway data | Make a device install an APK not signed by that app's recorded release key (§5.5) |
| Offer a stale or wrong shelf catalogue | Reach `/home` (`ProtectHome=yes`), KEYSTONE's services, or log in (no shell) |
| Withhold or drop new uploads (availability) | Mint a device certificate that opens anything: the content keys are not on the hub |

Containment: no login shell, LAN-only listener, `ProtectSystem=strict`, `NoNewPrivileges`, a minimal set of address
families, and nothing else running as `apsira`.

### 5.5 A malicious APK on GitHub or in a builds folder (D-007)

Three independent checks before and during an install:

1. **SHA-256 against the `.sha256` file.** Catches a corrupted or truncated download; not authenticity, since an
   attacker who can replace one can replace both.
2. **The signing certificate against the app's recorded release fingerprint**, compiled into APSIRA (D-016).
   Catches any APK not signed by the app's own key. A mismatch is shown, never installed.
3. **Android's own update rule:** an update must carry the installed app's certificate. On a fresh phone ("new
   phone in one go", D-009) only check 2 stands, which is why the table ships inside APSIRA and not on the hub.

The shelf also refuses a lower `versionCode` than the installed one. Check 2 holds only because the table lists
**release certificates only** (D-031): a release APSIRA never trusts a debug certificate, so VIATICUM (signed with
the SDK debug key every dev build on amb811 shares) is absent until it has its own release key, and dev trust exists
only between `dev` flavours (`contracts/app-link.md` §3.3). RCs are signed by each app's release script outside any
session (D-035), so nothing built in a session carries a trusted certificate. A forged APK therefore needs the app's
release key, which never leaves the operator's own folders.

### 5.6 False or hostile gateway data

Gateway payloads are public data from named hosts. The hub checks host, TLS, content type and size limits before
caching; the receiving app parses the payload as untrusted input against its contract
(`contracts/app-link.md`, gateway calls). A bad payload costs freshness, never an app's data.

### 5.7 Malware running as the operator

It can read the store and the archive through `apsira-read`, both ciphertext (D-028), and write to the builds
folders. It cannot erase snapshots (§4). An RC it drops there fails the fingerprint check unless it also holds that
app's release key, which is outside APSIRA's scope (§7).

### 5.8 Data at rest on amb811

- Observed 2026-10-30 (`lsblk`): amb811's system disk (`nvme0n1p3`, btrfs for `/` and `/home`) has **no LUKS
  layer**. The roadmap's "unlocking at boot" (`sync-and-storage.md` §3.2) does not hold on this hardware.
- Backups, archive items and the mailbox are sealed on the devices (D-028), so a stolen tower exposes no content.
  The hub's own state (device registry, hub configuration, gateway cache, its TLS and CA keys) sits unencrypted on
  the system disk until the backup SSD arrives with LUKS (`10` §11): a stolen tower before then exposes the hub's
  keys (re-pair every device) and public data, never a backup or a document.

### 5.9 The camera (D-029)

APSIRA opens the camera only on the pairing screen, decodes the QR on the device and saves nothing. No other screen,
job or call reaches it; a test proves the camera is opened from one route only.

## 6. Detection

| Signal | Where it shows |
|---|---|
| A backup overdue, the store unreachable, the store nearly full | APSIRA's status screen; a breakthrough alert after days (D-012) |
| An APK failing a check | The shelf, with which check failed |
| A device certificate refused | The hub's journal (`journalctl -u apsira-hub`), with the device's id, never content |
| A refused link caller | APSIRA's log: the code only, nothing about the caller (KAIROS pattern) |
| A fetch error | The status screen's gateway tile (D-019) |

Content is never logged anywhere (charter §1.2): no file names, document titles or payload text in a log line.

## 7. Out of scope

- Root compromise of amb811, and physical attacks on the running tower.
- An attacker with the phone unlocked and APSIRA's PIN.
- Compromise of an app's release key or of the operator's password manager.
- Proton's own security (Drive, VPN); GitHub's.
- The supply chain of Flutter, pub and Gradle dependencies (`dependencies.md` records each).
- The console's own threats (its thread, D-020).

## 8. Ruled points

- Backups are encrypted on the device before upload (D-028): a compromised `apsira` account sees only ciphertext.
- The archive is encrypted on the device too (D-028), so the disk without LUKS exposes no document before the SSD.
