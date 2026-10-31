# apsira_link — requests from APSIRA

The app side of APSIRA's calls on the app (contract `app-link.md` §2, §5.3, §5.4; D-034):
`AppLinkProvider`, which each adopting app declares, and `package:apsira_link/requests.dart`,
where the app takes a restore offer. Back to the [README](../README.md).

## Declaring the provider

The library manifest declares no provider, so no app gains an exported component by a package
bump. An adopting app adds it to its own manifest (its adoption lane, contract §10):

```xml
<provider
    android:name="com.apsiralabs.apsira_link.AppLinkProvider"
    android:authorities="${applicationId}.apsira"
    android:exported="true"
    android:grantUriPermissions="false" />
```

No `permission`, `readPermission` or `writePermission`: trust is the check on every call.
`query`, `insert`, `update`, `delete` and `openFile` throw `UnsupportedOperationException`;
`call` is the only entry point.

## Every call

1. The caller (`getCallingPackage`) must be exactly `com.apsiralabs.apsira`, signed with the
   recorded `F_APSIRA` and no SDK debug signer (`LinkTrust.forPeer`); in a dev build
   (own id `.dev` and the `DEV_LINK` switch) exactly `com.apsiralabs.apsira.dev`, by name.
   Anything else: `{error: not_authorised}` and nothing more, nothing logged. While `F_APSIRA`
   is unset a release app answers no APSIRA.
2. `contract` must be `apsira.app_link` and the major of `version` `1`; else, and for an
   unknown method, `{error: unsupported_version}`.

## `backup_now` (the central schedule, §5.3)

The app opts in with meta-data naming its Dart backup job:

```xml
<meta-data android:name="com.apsiralabs.apsira_link.BACKUP_JOB" android:value="appBackup" />
```

The provider then sends an explicit in-app broadcast to `apsira_jobs`' non-exported
`com.apsiralabs.apsira_jobs.RunJobReceiver` (extra `job`), which queues that job once through
WorkManager, and answers `accepted = true`. Without the meta-data, or without `apsira_jobs` in
the app (the receiver does not resolve), it answers `accepted = false`: the app is on its own
schedule. The two packages have no compile edge; the names are pinned on both sides.

## `restore_offer` (§5.4)

A whole offer (`name`, `snapshot`, `made_utc` an ISO UTC instant, `size` ≥ 0, `reason` `user`
or `new_device`) is written to `noBackupFilesDir/apsira_link/restore_offer.json` (a `.tmp` file
renamed over the old one: the newest offer replaces an older one), every attached engine is told,
and the answer is `accepted = true`. A malformed offer is `{error: not_found}` and keeps the
older one.

| Symbol (`requests.dart`) | What it is |
|---|---|
| `AppLinkRequests` | `offers` (a stream of offers taken while listened to) and `takePendingOffer()` (reads and clears; call at start and on resume); no method throws |
| `ChannelAppLinkRequests` | The adapter, channel `apsira_link/requests` (`takePendingOffer`; Kotlin pushes `offer`); one per app |
| `RestoreOffer` (+ `fromWire`) | `name`, `snapshot`, `madeUtc`, `sizeBytes`, `reason`; `toString` names no backup |
| `RestoreReason` | `user`, `newDevice` (`wire` `new_device`) |
| `AppLinkNames` | `providerClass`, `authoritySuffix`, `backupNow`, `restoreOffer`, `backupJobMetaData`, `runJobReceiver`, `runJobExtra` |
| `FakeAppLinkRequests` (`testing/fake_app_link_requests.dart`) | `offer(o)` reaches a listener, else waits in `pending` for one take |

The app shows its own confirmation and on yes restores through its own path, reading the
snapshot through its `BackupTarget`.

## Checks

`test/app_link_requests_test.dart` (the offer's wire form, the channel, the push, the fake) and
`test/provider_names_test.dart` (the Kotlin names against the Dart ones) run in the `link` gate.
`AppLinkProviderTest` runs with the Kotlin suite (README §Checks): the refusals (an unknown
package, a wrong certificate, a debug certificate, a dev caller in release, no caller), the dev
selection, the version check, `backup_now` with and without the meta-data and the receiver,
the inbox (atomic, replaced, taken once, corrupt), the push and the throwing entry points. A
device has not run it: the binder's calling package is Android's, shadowed here.
