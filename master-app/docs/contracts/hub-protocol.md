# The hub protocol — devices ⇄ the hub on amb811

Status: **1.0 draft, planned.** Decisions: D-015 and its addendum (pairing and the link), D-027 (the client),
D-029 (the camera), D-014 (the hub), D-005 (the network bar), D-024 (home detection), D-007–D-011, D-013, D-028,
D-030, D-033 and D-035 (what crosses). Built from slice 1 (D-006). For every interface value here this file wins over
`04` and `05` (D-032).

This is the contract between APSIRA on a phone or tablet and the hub service on amb811. It runs only on the home
network (D-005 tier 1 and 2). The hub's own setup (accounts, paths, port, firewall) is `../10-hub-runbook.md`.

## 1. Overview

| Aspect | Value |
|---|---|
| Transport | HTTPS on the home LAN, TLS 1.3, **mutual**: the device presents its paired certificate, the hub its own; each pins the other (§2). |
| Address | The hub's LAN address and port, stored at pairing. amb811 holds a DHCP reservation (runbook). |
| Bodies | JSON (UTF-8, canonical JSON from `apsira_core` where a body is hashed); byte streams as `application/octet-stream` with `Content-Length` and an `X-Apsira-Sha256` header. |
| Identity | Every request is authenticated by its client certificate alone: no tokens, no cookies, no accounts. |
| Versioning | The major in the path (`/v1/`); minors additive (§9). |
| Never | Reachable from outside the house; the router forwards nothing to it. |

## 2. Pairing (at home)

1. On amb811 the operator runs `apsira-hub pair` (runbook). The hub creates a **one-time code** (128 bits, valid
   10 minutes, single use) and shows a QR code:
   `apsira-pair:` + base64url of canonical JSON
   `{"v":1,"hub":"https://<lan-address>:<port>","hub_fp":"<sha256 of the hub certificate, 64 hex>","code":"<code>","hub_name":"amb811"}`.
2. APSIRA (behind its lock, D-018) scans it with the camera — on the pairing screen only, nothing saved
   (D-029) — generates an EC P-256 key pair in the **Android Keystore**, and calls
   `POST /v1/pair` over TLS that pins `hub_fp` (no client certificate yet) with
   `{"code", "csr", "device_name", "platform": "android", "app_version"}`.
3. The hub checks the code, signs the CSR with its **device CA** (a CA private to the hub, never the system's), and
   answers `{"device_id", "device_cert", "hub_ca"}`. From then on every call is mutual TLS.
4. A second scan of the same code is refused (`code_used`).
5. If another device is already paired, it seals the sync and vault keys to the new device (§8,
   `sync-envelope.md` §6). The hub relays the sealed copy and never holds either key (D-028).

The device key is usable for background work without a fresh authentication, so nightly shipping runs while APSIRA
is locked; APSIRA's lock gates the screens and the sensitive acts — installing, restoring, pairing, revoking
(D-015 addendum, D-018). The client is Kotlin behind the `HubClient` port, because the key never leaves the Keystore
(D-027). The hub's server certificate (pinned by `hub_fp`) and its **device CA** (which signs device certificates)
are two separate keys, both in `hub/tls/` (runbook §5).

## 3. Home detection (D-024)

APSIRA is **home** when `GET /v1/hello` at the stored address completes a mutual-TLS handshake with the pinned hub
within 2 s. Nothing reads the Wi-Fi name; no location permission. With Proton VPN always on, the device must allow
LAN connections (runbook). Away, nothing is sent and nothing queues on the network: work waits in APSIRA.

## 4. The shelf (D-007)

| Call | Answer |
|---|---|
| `GET /v1/shelf` | `entries`: `app`, `package`, `channel` (`release` · `rc`), `version`, `artifact` (file name), `size`, `sha256`, `cert_ok` (the hub's check against the app's recorded release digest), `changelog` (markdown), `published_utc` |
| `GET /v1/shelf/{app}/{artifact}` | The APK bytes, with `X-Apsira-Sha256` |

The hub offers only entries whose `.sha256` matched and whose certificate is the app's recorded **release** one; a
mismatch is listed with `cert_ok: false` and its bytes are refused (`refused`). APSIRA re-checks both on the device
before it hands the APK to the package installer. Only apps in APSIRA's table appear (VIATICUM is absent until it
has a release key, D-031).

- **Releases:** the assets `<app>-<version>.apk` and `<app>-<version>.apk.sha256` of each app's private GitHub
  Release; `changelog` is the release's notes.
- **RCs** (D-035): a file in the app's builds folder whose version part contains `rc`, with its `.sha256` beside it
  (an APK without one is not listed). It must carry the app's release certificate, so only an RC built by the app's
  own release script in candidate mode, outside any session, passes; a `dev`-flavour APK never does. `changelog` is
  the `<artifact>.notes.md` sidecar when present, otherwise `null` (shown as "no notes").

## 5. Backups and restore (D-008, D-009)

| Call | Body / answer |
|---|---|
| `POST /v1/backups/{package}` | Stream: the backup **sealed on the device with the vault key** (D-028); headers `X-Apsira-Sha256` (of the sealed bytes as sent), `X-Apsira-Name`, `X-Apsira-Made` (UTC). The hub verifies the hash and stores it as a snapshot through the append-only store. Answer `{"snapshot", "stored_utc"}` |
| `GET /v1/backups/{package}` | `snapshots`: `snapshot`, `name`, `size`, `made_utc`, `device_id` |
| `GET /v1/backups/{package}/{snapshot}` | The sealed bytes; the device opens them |

The hub never sees a backup in plain form and holds no key that opens one. It never deletes a snapshot on a device's
request; there is no delete call. Retention is the store's own pruning (D-008): every snapshot within 30 days, then
weekly for a year, then monthly (D-032).

## 6. The archive (D-010)

| Call | Body / answer |
|---|---|
| `PUT /v1/archive/{item}` | Stream: the document and its content metadata (`display_name`, `mime_type`), **sealed on the device with the vault key** (D-028); plus `X-Apsira-Meta` (base64url canonical JSON of what the hub may see: `owner` = `com.apsiralabs.atrium`, `size`, `sha256` of the sealed bytes, `kept_utc`). Answer `{"state": "stored"}` |
| `GET /v1/archive/{item}/state` | `stored` (written and hash-verified) · `secured` (a snapshot holds it) |
| `GET /v1/archive?owner=…&since=…` | `items`: `item`, metadata, `state` |
| `GET /v1/archive/{item}` | The sealed bytes; the device opens them |
| `POST /v1/archive/{item}/release` | The owner no longer needs it: removed from the live area; snapshots keep it per retention |

`contracts/atrium-offload.md` builds on these.

## 7. Gateway (D-011)

| Call | Answer |
|---|---|
| `GET /v1/gateway` | `sources`: `source` (`<kind>.<slug>`), `kind`, `param`, `version`, `fetched_utc`, `next_fetch_utc`, `sha256`, `size`, `format`, `state` (`live` · `dark`), `last_error` |
| `GET /v1/gateway/{source}/{version}` | The payload bytes |

Fetching is the hub's job alone (tier 2), from the host allowlist in its configuration (runbook §8.3). Kinds,
instances and payloads are `app-link.md` §7. `kairos.holidays.*` is `dark` (configured, never fetched) until RELAY's
thread accepts D-030.

## 7a. Hub configuration (D-033)

| Call | Body / answer |
|---|---|
| `GET /v1/config` | `{"revision", "sources": [{"source", "kind", "param", "cadence", "enabled"}], "shelf": {"apps": [...]}}` |
| `PUT /v1/config` | The same document with the `revision` it was based on; `conflict` (409) when another device changed it first, and the device re-reads and re-applies |

**Operational settings** the hub acts on — the gateway's sources and cadences, the shelf's apps — are this plain
document over mutual TLS; they hold no personal content. Both devices read it, so phone and tablet share them from
slice 1. **Personal settings** (the regime, per-app schedule choices, device names) never cross here: they are the
sync core's client from slice 5 (`sync-envelope.md` §9) and per device before it.

## 8. Sync mailbox (D-013)

| Call | Body / answer |
|---|---|
| `PUT /v1/mailbox/{batch_id}` | One encrypted batch (`sync-envelope.md` §4). Idempotent: the same id twice is accepted once |
| `GET /v1/mailbox?after={cursor}` | `batches`: `batch_id`, `cursor`, `from_device`, `size` (never the device's own) |
| `GET /v1/mailbox/{batch_id}` | The ciphertext |
| `POST /v1/mailbox/ack` | `{"cursor"}`: this device has applied everything up to it |
| `PUT /v1/blobs/{name}` · `GET /v1/blobs/{name}` · `HEAD /v1/blobs/{name}` | Encrypted attachments by keyed name (`sync-envelope.md` §5) |
| `POST /v1/keys/offer` · `GET /v1/keys/pending` | The sync and vault keys sealed to a newly paired device (`sync-envelope.md` §6); deleted once fetched |

The hub stores ciphertext only and never holds the sync or vault key in any form (D-028). A batch is removed once every active device has acknowledged it; a revoked device
no longer counts.

## 9. Devices and status

| Call | Answer |
|---|---|
| `GET /v1/hello` | `versions`, `hub_name`, `hub_time_utc` |
| `GET /v1/devices` | `devices`: `device_id`, `device_name`, `paired_utc`, `last_seen_utc`, `revoked` |
| `POST /v1/devices/{device_id}/revoke` | The device's certificate is refused from then on (the hub keeps a revocation list; it never reuses an id) |
| `GET /v1/status` | `store_independent` (false while on the system disk, D-014), `store_free_bytes`, `last_prune_utc`, `last_snapshot_utc` |

## 10. Errors

Every error is a JSON body `{"error": "<code>", "detail": "<text, never content>"}` with an HTTP status:

| Code | HTTP | Meaning |
|---|---|---|
| `not_paired` / `revoked` | 401 / 403 | Unknown or revoked client certificate |
| `code_used` / `code_expired` | 409 / 410 | Pairing code |
| `unsupported_version` | 400 | No common major |
| `not_found` | 404 | Unknown package, snapshot, item, source or batch |
| `checksum_mismatch` | 422 | The stream did not match its stated hash; nothing kept |
| `conflict` | 409 | `PUT /v1/config` based on an old `revision` |
| `refused` | 422 | A shelf artifact failed its certificate or hash check |
| `store_full` | 507 | The hub's area cannot take the write |
| `busy` | 503 | The store is pruning or the hub is starting; retry with backoff |

## 11. Versioning

This is version **1.0** under `/v1/`. Within 1.x: new endpoints, new optional fields, new error codes; a reader
ignores unknown fields and treats an unknown code by its HTTP class. A breaking change is `/v2/`, served beside
`/v1/` until every paired device runs an APSIRA that speaks it. Changes are APSIRA decisions.

## 12. Tests

Hub: pairing (good code, used, expired, wrong `hub_fp`), revocation refuses at the TLS layer, every endpoint's
happy path and errors, idempotent mailbox puts, no delete path reaches the store, ciphertext only in the mailbox,
the store and the archive (a test greps stored bytes for a known plaintext), a debug-signed or `dev` APK never listed,
an RC without `.sha256` never listed, a dark source never fetched, config `conflict`, all run against a scratch store
in a sandbox, never the live one. Device: pinning refuses a substituted hub certificate; home detection on a fake
hub; the shelf re-check refuses a tampered APK; the device key signs in the background with APSIRA locked.
