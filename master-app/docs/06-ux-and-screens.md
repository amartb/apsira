# APSIRA — UX and screens

Status: **design by the APSIRA PLANNING thread, 2026-10-30** (living document). **No board exists yet.** A direction
board (the main screens at 100 % and 200 % text, EN and ES) is drawn in P0/P1 for the operator's approval, as every
sibling's was, and its renders are committed in `docs/board/`. Until then this document is the reference; once the
board is approved, the board wins on looks and this document on behaviour.

## 1. Visual language

- **Apsira, dark first** (charter §1.6, §3): the `apsira_ui` tokens, type scale and kit; Archivo Expanded 600 for
  titles and numerals, Archivo for body text, JetBrains Mono for fingerprints, versions and hashes. No colour
  literal outside `lib/app/theme/`.
- **APSIRA is the brand's own app** (D-002): the Apsira symbol, unchanged, is its icon and appears on the lock
  screen and in About. It has no family accents of its own: **Emerald** is the one primary action per screen;
  states use the kit's status colours (ok, attention, failure), always with an icon and a word, never colour alone.
- **Cards:** every grouped section is a card with the 1 px border on the dark ground (charter §1.6).
- **Infrastructure tone** (D-003): screens report state plainly — what happened, when, and the one next step. No
  dashboards of numbers for their own sake.

## 2. Navigation

- **Status** is the start screen after the lock. A drawer (`apsira_ui`'s drawer chrome) lists: Status, Shelf,
  Backups, Archive, Gateway, Notifications, Devices, Settings, Help, About.
- Every status tile opens its section. Sensitive acts (install, restore, pair, revoke) pass through the lock's
  re-confirmation sheet (D-018) before they run.
- Routes live in the app (go_router); deep links from APSIRA's own notifications open the matching section.

## 3. Screens

### 3.1 Lock (D-018)

`apsira_lock`'s cover in mandatory mode: the Apsira symbol, "Unlock" (biometric, then device PIN). No setting turns
it off; Settings shows the lock as always on, with only the timeout choice (Proposed: `0`, `1`, `5` minutes, default
`1`).

### 3.2 First open and pairing (D-015, D-028, D-029)

1. `apsira_onboarding`'s intro with the Apsira symbol and the language step.
2. **Pair with your hub:** what the hub is (one line), and "At home, on amb811 run `apsira-hub pair` and scan the
   code". A camera preview with a frame; nothing is saved from the camera. This is the only screen that opens the
   camera (D-029); Android's camera permission is asked here, at the moment it is needed.
3. **Checking:** the hub's name and fingerprint (short form, JetBrains Mono) to compare with the hub's screen.
4. **Paired:** this device's name (editable), then **the keys**:
   - the first device ever: the **recovery sheet** (R26, D-028) carrying the sync key and the vault key, shown once,
     to print; "I have saved it" is required to continue, with a line saying every backup is unreadable without it
     if every device is lost;
   - a later device: "Approve on your other device" (the sealed hand-over), or "Type from the recovery sheet".
5. A device with no Apsira apps installed is then offered **New phone in one go** (§3.5.3).

Errors: code expired (scan a new one), hub not reachable (are you home? is Proton VPN allowing LAN connections?),
fingerprint mismatch (stop; never "continue anyway").

### 3.3 Status (D-019)

- **Banner** (Proposed), above everything when the hub cannot be reached: "Hub not reachable — last contact
  <time>". With it, every tile shows its last known state, marked as such.
- **Backup health** tile: one row per app — last backup home (relative time), `central`/`own`, an overdue mark
  (Proposed: overdue after 2 missed schedule windows or 3 days for `own`). While the store is on the system disk, a
  line "Backups are not on an independent disk yet" (D-014).
- **Shelf updates** tile: apps with a newer build, the version and a one-line changelog peek; RCs marked "RC".
- **Gateway freshness** tile: one row per source — data age, next fetch, last error if any.
- Nothing else in v1 (no disk space, no regime mode tile).

### 3.4 Shelf (D-007)

- **List:** every Apsira app in the fingerprint table (apps with their own release key, D-031), installed or not: name, installed version, the newest
  release, an RC if newer; a state pill (Up to date · Update · RC available · Not installed · Check failed).
- **App page:** versions newest first, each with channel (Release/RC), date, size, and its changelog rendered from
  Markdown; "Install" / "Update" on the selected build (Emerald). An RC carries a note that it is a candidate.
  "Check failed" builds show the reason (checksum or certificate) and no install button. An RC with no `.notes.md`
  reads "No notes" (D-035).
- **Install flow:** re-confirm → download progress → Android's own install dialog → result. Away from home the button
  reads "Available at home".

### 3.5 Backups (D-008, D-009, D-034)

#### 3.5.1 Overview

The central schedule card (window, while charging, at home only — fixed) and one card per app: mode
(`Central` · `Own schedule`), last backup, pending uploads (made away from home), "Back up now" (asks the app).

#### 3.5.2 App history

Snapshots newest first (date, device, size), grouped by month after the first 30 days so the thinning (D-008) reads
naturally. A snapshot → **Restore to <app>**: re-confirm, then APSIRA **offers** it to the app, whose own restore
confirmation and screen take over (D-034). A banner explains that the app's current data, settings included, is
replaced by that app's own restore rules.

#### 3.5.3 New phone in one go

Shown after the keys are in (§3.2). A checklist of apps that have snapshots: tick which to bring back. Then a step
list, one row per app: Install → Restore → Done, each waiting for Android's install dialog and the app's own restore confirmation. It can be left and
resumed; rows remember their step.

### 3.6 Archive (D-010)

A searchable list of documents offloaded by ATRIUM: name, type, size, when offloaded. A document → "Fetch back to
ATRIUM" (at home). APSIRA never opens or previews documents (all file handling is ATRIUM's).

### 3.7 Gateway (D-011)

- **Sources:** the sources he turned on, by kind (Holidays · Currency rates · Timetables); each with data age, next
  fetch, last error, and which apps took the latest version. "Add source" lists the three kinds; a kind may have
  several sources (two holiday regions). Sources are the hub's configuration, so phone and tablet show the same list
  (D-033). The holidays kind reads "Waiting for RELAY" until RELAY accepts the open-data source (D-030).
- **Source page:** its parameters (region for holidays; feeds picked from the National Access Point's list for
  timetables; nothing for rates), **cadence** (the kind's default, or Yearly · Every 6 months · Working days · Weekly
  · Every N days), enabled switch.
- Nothing is pre-added (no seeded source).

### 3.8 Notifications — the regime (D-012)

- Before M5 these settings are kept per device; from M5 they sync between phone and tablet (D-033).
- **Modes:** his quiet and focus modes, each with its schedules (days, start, end) and a manual "On until…" switch.
  Empty state: "No modes yet".
- **Priorities:** per app, the channels it has announced; per channel a level for "Outside modes" and per mode:
  Interrupt · Quiet · Digest. A line states what always breaks through: alarms (they never pass through the regime),
  reminders marked urgent in their app, APSIRA's own critical alerts.
- **Digest times:** a list of times and days.
- **The digest notification:** "Digest — <n> held" with entries (app, title); on the lock screen only the count.
  Tapping an entry opens its app.

### 3.9 Devices (D-015)

This device and every paired device: name, kind, paired, last seen. Another device → **Revoke** (re-confirm; the
explanation says the device loses hub access at once and must pair again). "Pair another device" shows how to start
pairing on the hub.

### 3.10 Settings

Language, theme (dark default), lock timeout, the hub (address, fingerprint, "Forget this hub" — re-confirm), the
recovery sheet with the sync and vault keys (shown again only after re-confirmation), export APSIRA's settings (`apsira_exchange`),
Help and About (`apsira_app`'s About with the Apsira Labs lockup).

## 4. Empty and error states

- **Not paired:** every section except Settings and Help shows "Pair with your hub first" with the pairing action.
- **Nothing yet:** each list has its own one-line empty state naming the first step (no modes, no sources, no app has
  handed a backup yet, nothing offloaded).
- **Away from home:** actions needing the hub read "Available at home"; nothing errors.
- **An app not allowed:** an app missing from the fingerprint table is listed nowhere; a failed caller check is
  never shown as an app's fault in its UI (it is a code in APSIRA's log).
- Failures name the next step, from the `Failure`'s `nextStep` (charter's `apsira_core` model).

## 5. Large text and languages

Every screen passes the layout check at 1.0–2.0 text scale, EN and ES, on 412 and 360 dp (`apsira_test`); no
fixed-height text box; fingerprints and hashes wrap rather than truncate (a truncated fingerprint can't be compared).
Every string in `app_en.arb` and `app_es.arb` in the same commit; shared strings come from `apsira_l10n`.
