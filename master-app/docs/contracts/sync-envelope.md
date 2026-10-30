# The sync envelope — the change format

Status: **1.0 draft, planned.** Decisions: D-APK-023 (the direction), D-013 (the core in v1, APSIRA's settings its
only client; folios in v2). The full rules it encodes are `apsira/docs/roadmap/sync-and-storage.md` §2.2–§2.4 (R10–
R14 and the 28 edge cases, cited here as `#n`).

A **language-neutral, documented** format (§2.2 of the roadmap note): the folios use a shared Dart implementation,
the PC's future desktop apps implement this text. The hub only stores and forwards it; it never decrypts it.

## 1. Overview

| Aspect | Value |
|---|---|
| Unit of change | One **change record**: one item's field group, in one app, made from known base versions (§2) |
| Unit of transport | One **batch** of records from one device and one app, encrypted as one **envelope** (§3, §4) |
| Attachments | Separate encrypted **blobs**, named by a keyed hash of their content (§5) |
| Key | One sync key shared by the paired devices; never on the hub in any form (§6, D-028) |
| Applying | Always the app's own logic, in one transaction per batch; idempotent (§7) |
| v1 client | APSIRA's settings only (§9) |

## 2. The change record

Canonical JSON (`apsira_core`), one object:

| Field | Type | Meaning |
|---|---|---|
| `change_id` | UUIDv7 | Also the **version id** this change creates |
| `app` | string | The app's package, e.g. `com.apsiralabs.apsira` |
| `schema` | integer | The app's schema version that wrote it (#18) |
| `table` | string | A table the app declares **shared** (§8) |
| `item_id` | UUIDv7 | The row's id (charter §1.4) |
| `op` | string | `upsert` · `delete` (soft: sets `deleted_at`) · `restore` · `purge` (a permanent delete marker, #8) · `set_add` · `set_remove` |
| `group` | string | The **field group** changed: one field, or a declared group that clashes as a unit (#3). Absent for `delete`, `restore`, `purge` |
| `values` | object | `upsert`: `field → value` for every field of the group. `set_add`/`set_remove`: `{"set": <field>, "element": <id>}` (#4) |
| `base` | array of UUIDv7 | The version ids of this item-and-group the device had when the edit was made; empty for a creation |
| `device` | string | The device id from pairing |
| `hlc` | string | Hybrid logical clock: `<UTC ms ISO-8601>-<counter 4 digits>-<device>`; orders what is **shown first**, never what is kept (R12, #20) |
| `origin` | string | `user` · `migration` (never a clash, #19) · `resolution` (resolving a clash, R10) |

Rules the record carries:

- **Concurrency is by `base`, never by clock.** Two changes to one item and group are concurrent when neither is in
  the other's `base` ancestry. Both are kept; every device shows the one with the greater `hlc` with a
  "2 versions" badge (R10, R12).
- **Ordered lists** use sortable position keys (fractional-index strings) as ordinary values, so moves merge (#13).
- **An edit beats a concurrent delete** (R11, #7): the receiving app restores the item and flags it.
- **Values compare after the app's normalisation** (#2): identical normalised values are not a clash.
- Derived data never appears in a record (#5); it is rebuilt from the source on each device.

## 3. The batch

```json
{
  "format": "apsira.sync",
  "format_version": "1.0",
  "batch_id": "<UUIDv7>",
  "app": "com.apsiralabs.apsira",
  "schema": 1,
  "device": "<device id>",
  "created_hlc": "<hlc>",
  "changes": [ … ],
  "blobs": [ "<blob name>", … ]
}
```

`format` and `format_version` follow `apsira_exchange`'s envelope convention (`format`, `formatVersion`,
`schemaVersion`) in spirit; this is a sibling format, not an export bundle. `blobs` lists every attachment the
changes reference, so a receiver can fetch them before applying (#21).

## 4. The envelope

```
header (canonical JSON, UTF-8):
  {"v":1,"alg":"xchacha20-poly1305","key_id":"<id>","nonce":"<24 bytes, base64url>","batch_id":"<UUIDv7>"}
body:
  AEAD-seal(key = sync key[key_id], nonce, plaintext = batch JSON, associated data = header bytes)
wire: 4-byte big-endian header length ‖ header ‖ body
```

- A fresh random nonce per envelope. `batch_id` sits in the header so the hub can de-duplicate without decrypting;
  it reveals nothing else. The hub sees sizes and timing, never content.
- An envelope that fails to open is kept aside and reported; it is never dropped silently.

## 5. Attachments

- Each attachment is encrypted alone, with the same AEAD and its own nonce.
- Its **blob name** is `HMAC-SHA256(blob key, plaintext)` (the blob key derived from the sync key), so a file already
  on the hub is never sent twice and the hub cannot confirm a known file by its plain hash.
- Inside the encrypted change the attachment is referenced by its plain SHA-256 and its blob name.
- A replaced attachment is a new blob and a new version; the old one stays in history (#22).

## 6. The sync key and the vault key

- The **sync key** (this format) and the **vault key** (backups and archive items, D-028) are each 32 random bytes,
  created by the first device paired with the hub, kept in each device's Keystore-wrapped storage. They travel
  together.
- **A new device** pairs with the hub (`hub-protocol.md` §2), then an already-paired device, behind its lock,
  confirms it and seals both keys to the new device's public key (`POST /v1/keys/offer`); the new device fetches and
  opens them, and the hub deletes the sealed copy. The hub only relays it and **never holds either key in any form**:
  no recovery copy, no wrapped copy (D-028).
- **Recovery sheet** (R26, #26, D-028): one printed sheet carries both keys, offered when they are created; with no
  paired device left, the new device types them from it. Without the sheet and without a paired device, backups,
  archive items and the mailbox cannot be opened.
- **Revocation** (#25): the hub refuses the device; a key rotation (new `key_id`) is offered, and old envelopes keep
  their `key_id` so history stays readable.

## 7. Applying

- The receiving APSIRA opens the envelope and hands the batch to the app named in `app` (v1: itself).
- The app applies a batch in **one transaction**; a `change_id` already applied is a no-op (#23).
- **Schema gate (#18):** a batch whose `schema` is greater than the app knows is **held** in APSIRA, never dropped,
  and offered again after the app updates.
- After a batch, the app checks its cross-row rules (#6) and flags, never "fixes", a broken one.
- A device restored from an old backup rejoins as a **new device** (#24); delete markers keep deleted items deleted
  (#9).

## 8. The declaration each app makes

Each syncing app ships a **sync manifest** (canonical JSON, versioned with its schema): every table marked `shared`
or `device_only` (#16), each shared table's field groups, sets and ordered lists, and its normalisation rules. A
device-only table never produces a record. The manifest is part of the app's planning in v2.

## 9. The v1 client: APSIRA's settings

APSIRA's **personal settings** are the only synced data in v1 (D-013, D-033): the notification regime (quiet-hour
schedules, focus modes, per-app kind priorities, digest times), the per-app backup schedule choice, and device names.
Before slice 5 they are kept per device. The gateway's sources and cadences and the shelf's apps are **not** synced:
they are the hub's plain configuration (`hub-protocol.md` §7a). Each setting row is one item; each independent value is its own group; a schedule's days, start and
end form one group (#3). A clash shows the badge in APSIRA's settings and in its Conflicts list, which v2 widens to
every app.

## 10. Versioning

`format_version` is `MAJOR.MINOR`. Minor: new optional fields and new `op` or `origin` values that an older reader
of the same major holds rather than applies. Major: anything else; a reader refuses a major it does not know,
naming both, and holds the batch. Changes are APSIRA decisions with a `D-APK-nnn` entry, and shared test vectors
(batches, envelopes with a test key, expected applications) live beside this file when slice 5 builds it.
