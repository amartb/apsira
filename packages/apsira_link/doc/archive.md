# apsira_link — The archive (ATRIUM's offload)

`package:apsira_link/archive.dart` (its own library, not in the barrel) holds the five calls of
`atrium-offload.md` §3 (AO). Only `com.apsiralabs.atrium` may call them: APSIRA refuses any
other app with `not_authorised` (`LinkUnavailable`). At home only: the calls that move bytes
answer `away` when the hub is not reachable, and nothing is queued on the phone.

| Symbol | What it is |
|---|---|
| `ApsiraArchiveLink` | The port; `ChannelApsiraArchiveLink` (`const`) its adapter over the one channel. No method throws |
| `archivePut(item, bytes)` | `archive_put` with `item.extras` (`item_id`, `display_name`, `mime_type`, `size`, `sha256`, `kept_utc`), writes `bytes` to the `fd` and closes it, then **one** `archive_state(item_id)`, whose answer is the result (`stored` expected; plan R-7's reading of "after the stream, state = `stored`") |
| `archiveState(id)` · `archiveList({since})` | `LinkArchiveState`: `stored` · `secured` · `absent`; `List<LinkArchiveEntry>` (`item`, `state`), `since` sent in UTC and omitted when null; a malformed item dropped, `items` not a list `unknown_error` |
| `archiveFetch(id)` · `archiveRelease(id)` | `LinkArchiveFetch` (`bytes` = `LinkChannel.readAll`, `sha256`, `size`); a malformed reply is `unknown_error` and its read end cancelled · `Ok` once APSIRA answers |
| `LinkArchiveItem` | The metadata of AO §3; `sha256` and `size` of the plain document; `kept_utc` ISO 8601 with `Z` |
| `FakeApsiraArchiveLink` (`testing/fake_archive_link.dart`) | An in-memory archive: put checks size and SHA-256, `secure(id)` stands in for the next snapshot, `away` (put, fetch), `storeFull`, `unavailable`, `not_found` on fetch; `calls` records wire names only |

`archivePut` watches the bytes against the item while `writeAll` sends them: past the item's
size it stops at once; short, or with another SHA-256, it stops at the end before the last
piece. Either way the write end is **cancelled**, never closed, APSIRA discards it, and the
result is `LinkCallFailed(checksumMismatch)`; a refused put never listens to the bytes. AO §4's
`away`, `store_full` and `not_found` are `LinkCallFailed` with `LinkErrorCode.away`,
`storeFull` and `notFound`. **`display_name` and `mime_type` are content** (AO §3): they travel
only in `archive_put`'s extras and appear in no `toString` (`LinkArchiveItem(<id>, <n> bytes)`).
