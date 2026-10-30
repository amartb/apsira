# APSIRA — Proposed charter amendments

Status: **proposed by the APSIRA PLANNING thread, 2026-10-30; approved and applied by the operator, 2026-10-30.** The charter (`apsira/README.md`) and
the ecosystem log (`apsira/docs/decisions.md`) change only when the operator says go; then the text below is applied
in one commit on a branch, with the entries appended to the log (never rewriting an existing entry's body; an
amended entry gains a Status note only).

Why: the planning rulings make APSIRA one of two network-holding Apsira apps (M5, D-001) and give Apsira its own area
on amb811 (R9, D-014). The charter still says "one program with network access" and "runs no service on the
KEYSTONE host".

---

## 1. Charter §1.1 — Standalone

**Current:**

> 1. **Standalone.** It runs on its own, with no backend, no account and no shared
>    infrastructure. It is **not a KEYSTONE project**: it runs no service on the KEYSTONE
>    host, attaches to none of its shared services, and is not governed by KEYSTONE's
>    architecture or standards (VIATICUM D-001). Its `.army.toml` says `keystone = false`.

**Proposed:**

> 1. **Standalone.** It runs on its own, with no backend, no account and no shared
>    infrastructure: with the hub unreachable or the central app missing it works as
>    before. It is **not a KEYSTONE project**: it attaches to none of KEYSTONE's shared
>    services and is not governed by KEYSTONE's architecture or standards (VIATICUM
>    D-001). Its `.army.toml` says `keystone = false`. amb811, the home hub, also hosts
>    KEYSTONE; Apsira keeps **its own area** there — dedicated accounts, its own storage
>    and services, no port, database, proxy or container shared with KEYSTONE — governed
>    only by this charter and the Apsira decision logs (D-APK-023 R9, D-APK-025).

## 2. Charter §1.2 — Offline and private by construction

**Current:**

> 2. **Offline and private by construction.** A phone app ships with **no `INTERNET`
>    permission** (RELAY D-041); a PC app makes only explicit, user-triggered network
>    actions. No telemetry, no cloud, no AI features inside the apps. Content is never
>    logged.

**Proposed:**

> 2. **Offline and private by construction.** A phone app ships with **no `INTERNET`
>    permission** (RELAY D-041); a PC app makes only explicit, user-triggered network
>    actions. **Two apps hold network access by charter, not by exception:** the central
>    app, APSIRA (sync, backups, the network gateway, the build shelf), and the console
>    (control of the home PCs). Each reaches only the hosts its own decision log names
>    (APSIRA D-005), and they never share keys, stores or accounts (D-APK-024). No
>    telemetry, no cloud, no AI features inside the apps. Content is never logged.

## 3. Charter §2 — Classes of app

Replace the central app's row and add the console's:

| Class | Form | Reference | Members |
|---|---|---|---|
| **the central app** | The one Apsira-branded app that ties the roster together: sync, backups home, the network gateway, the build shelf, the notification regime (§4); an Android app plus its hub on amb811 | APSIRA | APSIRA |
| **the console** | The Apsira app that controls the home PCs (health, allowlisted actions) and follows the agent army; separate from the central app by privilege | — | planned after APSIRA |

## 4. Charter §4 — Sync and the central app

Append to the section:

> The central app is **APSIRA** (`master-app/` in this repository; its documents in
> `master-app/docs/`). Its v1 carries backups home, the build shelf, the gateway, the
> notification regime and the sync core; the folios adopt sync in its v2. Apps reach it
> through `apsira_link` (§5), and every app works without it. Backups and archived
> documents are **sealed on the device** before they leave it; the hub on amb811 never
> holds a key that opens them (APSIRA D-028).

## 4a. Charter §6 — Identity and the release key

**Current** (the last sentence of the "Identity" bullet):

> A release key is the
> app's choice (RELAY has one, D-090; VIATICUM signs with the SDK debug key, D-059).

**Proposed:**

> A release key is the
> app's choice (RELAY has one, D-090; VIATICUM signs with the SDK debug key, D-059), with
> one consequence: the central app trusts, and its build shelf offers, **only apps signed
> with their own release key**. An app signed with a debug key works alone but is outside
> the central app's link and shelf until it has one (APSIRA D-031, D-APK-027).

## 5. Charter §8 — Roster

Replace the central app's row and add the console's:

| App | Class | Repository | State |
|---|---|---|---|
| APSIRA | the central app | `amartb/apsira` (`master-app/`) | planned (2026-10-30): planning documents written; v1 is five slices (APSIRA D-006) |
| the console | the console | — | ruled (2026-10-30, M5): planned after APSIRA |

## 6. Charter §9 — Repository map

Add a row:

| Path | Contents |
|---|---|
| `master-app/` | APSIRA, the central app: the Android app, its hub (`hub/`) and its planning documents (`docs/`) |

and, once built, `apsira_link` in the `packages/` row and §5's package table (D-APK-026).

---

## 7. Draft ecosystem entries

Summary rows to add:

| ID | Decision | Status |
|---|---|---|
| D-APK-024 | The central app is APSIRA; two network-holding Apsira apps (APSIRA and the console), split by privilege | Decided |
| D-APK-025 | Apsira's own area on amb811, independent of KEYSTONE | Decided |
| D-APK-026 | `apsira_link` and the package changes the central app needs | Proposed |
| D-APK-027 | The central app trusts only apps signed with their own release key | Decided |

Status note on D-APK-005's summary row and entry: **"Decided as direction (2026-10-21); amended by D-APK-024."**

### D-APK-024 — The central app is APSIRA; two network-holding apps

- **Status:** Decided (2026-10-30; roadmap `master-app.md` M1–M7; APSIRA D-001, D-002, D-020).
- **Decision:** the central app of D-APK-004 and D-APK-005 is **APSIRA** (`com.apsiralabs.apsira`, the Apsira
  symbol unchanged as its icon), in this repository under `master-app/`. It is one of **two** Apsira apps that hold
  network access: APSIRA (sync, backups, the gateway, the build shelf, the notification regime) and the **console**
  (PC control and the army companion), split by privilege so that a compromise of one never reaches the other's
  keys. Every other app keeps no network (charter §1.2).
- **Amends D-APK-005:** sync still lives only in the central app; "one program with network access" becomes two,
  each limited to the hosts its own log names.
- **Consequences:** charter §1.2, §2, §4, §8, §9 as `master-app/docs/charter-amendments.md`.

### D-APK-025 — Apsira's own area on amb811

- **Status:** Decided (2026-10-30; D-APK-023 R9; APSIRA D-014).
- **Decision:** amb811 hosts APSIRA's hub: dedicated system accounts (`apsira`, `apsira-store`), its own data root
  and services, a LAN-only port. Nothing is shared with KEYSTONE, and KEYSTONE's rules do not govern it. An Apsira
  app never depends on the hub to work.
- **Consequences:** charter §1.1's "runs no service on the KEYSTONE host" is reworded (§1 above). The hub's steps are
  `master-app/docs/10-hub-runbook.md`.

### D-APK-026 — `apsira_link` and the package changes for the central app

- **Status:** Proposed (APSIRA D-016, D-017); becomes Decided when the apsira lane builds it at a shared tag.
- **Decision:**
  - A new package **`apsira_link`**: the client of the on-device link to APSIRA (content providers on both sides,
    called through `ContentResolver.call`), with the KAIROS trust pattern on every call (package name and
    signing-certificate SHA-256 against a recorded fingerprint; RELAY `docs/kairos/05-link-contract.md` §2, ATRIUM
    D-055). APSIRA missing is "unavailable", never an error. It also carries `F_APSIRA`, the gateway calls and the
    app-side `restore_offer` handler (APSIRA D-034).
  - **`apsira_storage`:** an APSIRA adapter of the unchanged `BackupTarget` port, so an app ships its backups home
    with no new backup code; APSIRA seals them with the vault key before they leave the device (APSIRA D-028).
  - **`apsira_notify`:** the `Notifier` asks APSIRA's notification policy before posting (quiet hours and focus,
    priority, digests); without APSIRA it behaves as today.
  - **`apsira_lock`:** a mandatory mode (the lock cannot be turned off) for APSIRA.
  - Gateway delivery as `apsira_link` calls, by kind and the app's own parameter (APSIRA D-033).
- **Rationale:** the client side of the central app is shared code by construction; nothing is copied into an app
  (D-APK-009's adoption lanes carry it into each app).
- **Consequences:** three shared tags, each before the APSIRA slice that first needs it (APSIRA D-017 addendum);
  each app adopts them in its own repository. The contract is `master-app/docs/contracts/app-link.md`.

### D-APK-027 — The central app trusts only apps with their own release key

- **Status:** Decided (2026-10-30; APSIRA D-031).
- **Decision:** the central app's fingerprint table, and so its link and its build shelf, hold only apps signed with
  **their own release key**. A release central app never trusts a debug certificate: on the operator's PC every dev
  build shares the SDK debug key, so trusting it would trust any of them. VIATICUM (D-059) is outside the link and the
  shelf until its own thread gives it a release key.
- **Consequences:** charter §6's identity bullet gains the sentence in §4a above. VIATICUM's thread is asked for a
  release key (APSIRA D-036).
