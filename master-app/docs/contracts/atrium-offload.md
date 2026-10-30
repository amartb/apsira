# The ATRIUM offload contract

Status: **1.0 draft, planned.** Decisions: D-010 (the documents archive) and its addendum, D-028 (sealed on the
device), D-036 (an ask of ATRIUM's thread). APSIRA's side is built in slice 2
(D-006). ATRIUM's side is **ATRIUM's thread's to rule**: this file names what APSIRA offers and records ATRIUM's
part as proposals (§6). It is one of the "central-app hooks" ATRIUM D-040 left to be named.

## 1. Overview

| Aspect | Value |
|---|---|
| Direction | ATRIUM → APSIRA. APSIRA never reads ATRIUM's store and never calls ATRIUM for this. |
| What crosses | One kept document's bytes and the metadata in §3, out to the archive and back on demand. |
| Transport | The app link (`app-link.md`): ATRIUM calls APSIRA's provider; bytes as `ParcelFileDescriptor` streams. APSIRA forwards to the hub's archive (`hub-protocol.md` §6). |
| Trust | The app link's per-call fingerprint checks (`app-link.md` §3); only `com.apsiralabs.atrium` may call these methods. |
| Where | **At home only** (D-005 tier 1): every call that moves bytes answers `away` when the hub is not reachable. Nothing is queued on the phone, so an offload never doubles the phone's storage. |
| Sealing | APSIRA seals each document **and** its `display_name` and `mime_type` with the vault key before it leaves the device (D-028). The hub stores ciphertext and sees only the owner, the sealed size and hash, and `kept_utc`. A future ATRIUM tome holds the vault key to read the archive. |
| Purpose | Free the phone: offloaded documents leave the phone and come back on demand. A future ATRIUM tome reads the same archive (D-010). |

## 2. States and the guarantee

```
on phone ──put──▶ stored ──(next hub snapshot)──▶ secured ──ATRIUM may remove its local bytes
                    │                                 │
                    └──── fetch back at any state ◀───┘
```

- `stored`: the hub wrote the bytes to the archive and verified their SHA-256.
- `secured`: a snapshot of the append-only store holds them (D-008).
- **ATRIUM removes its local bytes only at `secured`.** Until then the document is on the phone and in the archive.
- An offloaded document is then held by the archive, its snapshots, and the operator's manual Proton copy (D-008),
  all ciphertext; ATRIUM's own backups stop carrying its bytes (§6). This is the known risk until Proton upload is
  automated (D-021). Losing the vault key with no recovery sheet loses every offloaded document (D-028).

## 3. Methods (on APSIRA)

| Method | `extras` in | Bundle out |
|---|---|---|
| `archive_put` | `item_id` (ATRIUM's id), `display_name`, `mime_type`, `size`, `sha256`, `kept_utc` | `fd` (write end); after the stream, `state` = `stored` |
| `archive_state` | `item_id` | `state`: `stored` · `secured` · `absent` |
| `archive_list` | `since` (UTC, optional) | `items`: `item_id`, metadata, `state` |
| `archive_fetch` | `item_id` | `fd` (read end), `sha256`, `size` |
| `archive_release` | `item_id` | — (ATRIUM purged the document; the hub removes it from the live area, snapshots keep it per retention) |

`sha256` and `size` here are of the plain document, as ATRIUM states and receives them; APSIRA seals and opens.
`display_name` and `mime_type` are content: APSIRA never logs them, and they reach the hub only inside the seal.

## 4. Errors

The app link's codes (`app-link.md` §8), plus:

| `error` | Meaning | ATRIUM does |
|---|---|---|
| `away` | The hub is not reachable | Keeps the document as it is; offers "fetch at home" |
| `checksum_mismatch` | The bytes did not match `sha256` (either direction) | Nothing changes state; retries |
| `store_full` | The hub's area is full | Keeps the document on the phone; says so |
| `not_found` | `archive_fetch` of an item the archive does not hold | Shows the item as missing from the archive (never silently deleted) |

## 5. Versioning

Part of the app link's version (`app-link.md` §9); the methods are additive in 1.x. A change is an APSIRA decision
noted in ATRIUM's planning before ATRIUM builds against it.

## 6. ATRIUM's side — proposals for ATRIUM's thread

Recorded for ATRIUM's planning; none of it is decided for ATRIUM here.

1. **An "offloaded" state** for kept items: the record, its name, family, dates, tags and a small thumbnail stay on
   the phone and searchable; only the bytes leave.
2. **What may be offloaded:** chosen by hand, and/or by a rule ATRIUM defines (for example, not opened for N months).
   *Proposed:* standing items and vault-guarded items (ATRIUM D-018, D-058) are never offloaded; ATRIUM's thread
   rules it (D-036).
3. **Removing local bytes only at `secured`** (§2), checked by `archive_state`.
4. **Fetch back:** opening an offloaded item at home fetches it (and verifies its SHA-256); away, it says "at home".
   Whether a fetched item stays on the phone or is offloaded again is ATRIUM's choice.
5. **Backups and export:** ATRIUM's backup keeps the offloaded records but not their bytes; its export bundle marks
   them offloaded. A restore on a new phone brings the records back and the bytes stay in the archive.
6. **Purge:** purging an offloaded item calls `archive_release`.
