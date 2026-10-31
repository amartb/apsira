# apsira_link

The app side of the on-device link to APSIRA, the central app (D-APK-026; the interface is
APSIRA's `master-app/docs/contracts/app-link.md`, version 1.0). One Flutter plugin: a Dart
port with typed failures over one method channel, and the package's own Kotlin, which
resolves APSIRA and checks its certificate before any call and carries the byte streams.

Dependencies: `apsira_core` (the git form at the shared tag, with the committed
`pubspec_overrides.yaml`, D-APK-007) and `crypto` (already in its closure) for the streams'
SHA-256. Nothing else: the trust check is the package's Kotlin.

```yaml
dependencies:
  apsira_link: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.5.0, path: packages/apsira_link } }
```

## What it holds

| Symbol | What it is |
|---|---|
| `ApsiraLink` | The port: `hello()` → `Result<LinkHello, LinkFailure>`; no method throws |
| `ChannelApsiraLink` | The adapter: `const ChannelApsiraLink()`, channel `apsira_link/link` (`channelName`) |
| `LinkHello` (+ `fromReply`) | `version` (chosen), `versions`, `appVersion`, `locked`, `devUnverified` |
| `chooseLinkVersion` | The highest `MAJOR.MINOR` both sides speak, compared numerically; malformed ignored |
| `linkContract`, `linkVersions`, `linkControlDeadline` | `apsira.app_link`, `['1.0']`, 5 s (contract §4, §8, §9) |
| `LinkFailure` (sealed `Failure`) | `LinkUnavailable` (`reason`; `theirs`, `ours` for a version mismatch) or `LinkCallFailed` (`error`); `wire` is the contract's name |
| `LinkUnavailableReason` | `not_installed`, `not_trusted`, `not_authorised`, `unsupported_version`, `no_answer`, `unknown_error`; codes `linkNotInstalled` … |
| `LinkErrorCode` | The six call errors of §8: `busy`, `away`, `storage_full`, `not_found`, `not_allowed`, `checksum_mismatch`, and `store_full` (atrium-offload §4); codes `linkBusy` … |
| `LinkStreamException` | How a byte stream ends when it fails: carries its `LinkFailure`; a short, long or altered stream is `LinkCallFailed(checksumMismatch)` |
| `linkFailureFromWire` | An `error` value → its failure; an unknown code is `unknown_error` (unavailable) |
| `linkDevSwitch` | `com.apsiralabs.apsira_link.DEV_LINK`, the development switch (below) |
| `FakeApsiraLink` (`testing.dart`) | Answers `hello` with a fixed result, by default `not_installed`; counts `helloCalls` |

`not_authorised` and `unsupported_version` are §8 codes; the other four reasons are the
client's own (ruling A-5).

## APSIRA missing is unavailable

Every app works alone (contract §1). APSIRA not installed, not trusted, refusing, on
another major version, silent past the deadline or answering in an unknown shape is an
`Err(LinkUnavailable(…))`, never a throw, and the app behaves as it does without APSIRA. A
`LinkCallFailed` means APSIRA is there and the call failed (§8 says what the app does).

## The trust model

Contract §3: per-call certificate checks both ways, no permission, no shared key. Before
every call the Kotlin resolves APSIRA's authority (`com.apsiralabs.apsira.link`), requires
its package to be exactly `com.apsiralabs.apsira` and `hasSigningCertificate` with
`F_APSIRA`; otherwise the reply is `not_trusted` and nothing is called. A release build
never trusts a debug certificate (D-031).

**`F_APSIRA` is unset** (`""`): it is recorded once APSIRA's `release-signing.md` §2
records its release certificate (contract §3.1, ruling A-7). Until then a release app
trusts no APSIRA and every call is `not_trusted`.

## Backups (contract §5.2)

`package:apsira_link/backups.dart`, its own library (an app imports only the calls it makes):
`ApsiraBackupLink`, the port of APSIRA's backup queue, and `ChannelApsiraBackupLink`, its
adapter over the channel. No method throws; the one exception is `restoreOpen` without
exactly one of `name` and `snapshot`, an `ArgumentError` (a programming error).

| Method | Wire call, extras → value |
|---|---|
| `backupSpace()` | `backup_space` → `int` (`free_bytes`) |
| `backupBegin(name, {size})` | `backup_begin` {`name`, `size` when known} → `LinkBackupTicket` (`ticket`, write-end `handle`) |
| `backupWrite(ticket, bytes)` | the write stream to its end → `LinkWritten` (`sha256`, `size` of what was written) |
| `backupCommit(ticket, sha256:, size:)` | `backup_commit` {`ticket`, `sha256`, `size`} → `LinkBackupState.queued` |
| `backupRename(from, to)` | `backup_rename` {`from`, `to`} → `LinkRenameOutcome`: `renamed` (no field), `exists` or `missing` (a true field of that name) |
| `backupList()` | `backup_list` → `List<LinkBackupEntry>` (`name`, `sizeBytes`, `madeUtc`, `state` queued · shipped, `snapshot` when shipped) |
| `backupDelete(name)` | `backup_delete` {`name`} → nothing |
| `restoreOpen({name, snapshot})` | `restore_open` {`name` or `snapshot`} → `LinkRestoreStream` (`bytes`, checked against its `sha256` and `size`) |

**A backup shipped home is never deleted by an app** (D-008): `backup_delete` removes only a
queued copy and succeeds on a shipped one, which the hub's retention governs. Every `{error}`
is its `LinkFailure` (`linkFailureFromWire`); a reply that is not the contract's is
`unknown_error`, and one holding a stream handle cancels it. `made_utc` is an ISO 8601 UTC
instant ending in `Z`; an entry with a malformed field is dropped, the rest kept. Names and
bytes are never in a `toString`.

`FakeApsiraBackupLink` (`package:apsira_link/testing/fake_backup_link.dart`) is an in-memory
queue with §5.2's rules: the stated SHA-256 and size checked on commit (`checksum_mismatch`,
the write discarded), `ship(name)` marks a backup shipped with a snapshot id, delete removes
only queued copies, a shipped restore is `away` while `away`, queued bytes past `queueCap`
are `storage_full`; `unavailable` fails every call, `failures` sets one call's failure, and
`calls` records each call.

## The channel

Dart never selects a trust mode (ruling R-2). `LinkChannel` (`lib/src/link_channel.dart`,
internal: the call libraries import it, the barrel does not export it) holds the one channel,
`apsira_link/link`. The control method, `call`:

| Direction | Shape |
|---|---|
| Dart → Kotlin | `{method: String, version: String, extras: Map<String, Object?>}`, exactly these keys; the version is `linkVersions.last`; `hello` sends empty extras |
| Kotlin → Dart, unavailable | `{unavailable: <reason wire>}` |
| Kotlin → Dart, call error | `{error: <§8 code>}` |
| Kotlin → Dart, answer | `{fields: Map, devUnverified: bool}`; an `fd` in the fields is `{stream: <handle>}`, an array or list of Bundles (`entries`, `items`) a list of maps |
| No reply in 5 s, `PlatformException`, `MissingPluginException` | `no_answer` |
| `null` or any other shape | `unknown_error` |

The stream methods, on a handle an answer gave (contract §4: the receiver reads or writes to
the end; §8: no deadline, the stream ends with the sender's stated size):

| Method | Arguments → reply |
|---|---|
| `write` | `{handle, bytes}` → `{}` |
| `read` | `{handle, max}` → `{bytes}` (at most `max`, at most 64 KiB) or `{end: true}` |
| `close` | `{handle}` → `{}`: the stream ended as it should |
| `cancel` | `{handle}` → `{}`: abandoned; the peer sees it short and discards it |
| any, unknown handle or malformed arguments | `{unavailable: unknown_error}`; an I/O failure is `no_answer` and closes the handle |

`LinkChannel.writeAll(handle, bytes)` writes a `Stream<List<int>>` in 64 KiB chunks
(`chunkSize`), closes the stream and returns `Ok((sha256:, size:))` of what it wrote, the
SHA-256 computed while writing, for the call that commits it to state. Any failure cancels the
stream and is the `Err`; a failing source is `unknown_error`.
`LinkChannel.readAll(handle, sha256:, size:)` reads to the end and closes; when what arrived
is not `size` bytes with that SHA-256 it ends with
`LinkStreamException(LinkCallFailed(checksumMismatch))` after the last chunk and before done
(at once, cancelled, when it runs past `size`). A failed read ends with its failure; a
listener that stops early cancels the stream. No method throws, and Dart never retries.

## Deadlines and the worker

Kotlin runs control calls off the main thread on a pool of `CONTROL_THREADS` (2), so a hung
call holds one thread and never delays the next past the deadline. Each call carries its
arrival time; at `CONTROL_DEADLINE_MS` (5 000, Dart's `linkControlDeadline`):

- a call still **queued** is dropped before it reaches APSIRA and answered `no_answer`: a call
  Dart has given up on is never sent afterwards;
- a call still **running** is answered `no_answer` by the watchdog; its late reply is
  discarded and every stream handle in it closed.

Each call is answered exactly once, on the main thread. Stream I/O runs on its own threads
(never the control pool) with no deadline. On engine detach the pools stop and every open
handle is closed. Dart's own 5 s timeout stays as the fallback.

## Development builds

A dev build talks only to a dev APSIRA (`com.apsiralabs.apsira.dev`) by package name
(contract §3.3; rulings R-2, R-5). A package has no flavours, so the relaxed check ships in
every build and is selected only when **both** conditions hold: the app's own id ends in
`.dev` **and** its merged manifest carries the `DEV_LINK` switch. Either alone selects
nothing. The app declares the switch in its **dev source set only**:

```xml
<application>
  <meta-data android:name="com.apsiralabs.apsira_link.DEV_LINK" android:value="true" />
</application>
```

Each app's release-manifest test proves the switch absent from its release manifests with
`declaresLinkDevSwitch` (`package:apsira_link/testing/link_release_manifest.dart`): true
only for an uncommented `<meta-data>` naming `linkDevSwitch` with `android:value="true"`.

```dart
expect(declaresLinkDevSwitch(File('android/app/src/main/AndroidManifest.xml').readAsStringSync()), isFalse);
```

`example/test/release_manifest_test.dart` is the model: the switch in `src/debug`, absent from
`main`, `profile` and the plugin's manifest. A dev link reaches the app as
`LinkHello.devUnverified`; show "dev link: unverified" where the link's state is shown.

## The archive (ATRIUM's offload)

The five calls of `atrium-offload.md` §3 (`package:apsira_link/archive.dart`), only for `com.apsiralabs.atrium`, at home only: [doc/archive.md](doc/archive.md).

## APK files

`ApkSignerCheck.kt` checks an APK file's signer by the link's own rule (D-031) before it is installed or offered: [doc/apk_files.md](doc/apk_files.md).

## The Kotlin side

Package `com.apsiralabs.apsira_link`. `LinkTrust.kt` is ATRIUM's `CallerCheck.kt` re-homed
(its header names the source and the changes).

| Symbol | What it is |
|---|---|
| `LinkConfig` | `F_APSIRA` (`""`), `APSIRA`, `APSIRA_DEV`, `AUTHORITY_SUFFIX` (`.link`), `CONTRACT`, `DEV_SWITCH` |
| `FingerprintTable` | package → 64 hex digits, colons allowed; `digest(pkg)` is null when unrecorded or malformed; `packages` |
| `Trust` | `trusts(pm, pkg)`, `devUnverified` |
| `CertificateTrust(table, sdkInt)` | `hasSigningCertificate` with the recorded digest; refuses any `.dev` package, below API 28, and a signer with the SDK debug subject (`CN=Android Debug`) even when its digest is recorded (D-031); a failure is "not trusted" |
| `DevNameTrust(packages)` | a dev build's trust: the listed `.dev` packages by name; `devUnverified` |
| `LinkTrust` | `devSwitchOn(context)` (the own `ApplicationInfo`'s `DEV_SWITCH`), `isDevBuild(own, switch)` (own id `.dev` **and** the switch), `peer`, `forPeer` (an app trusting APSIRA), `forCallers` (APSIRA trusting its table), `apsiraTable` |
| `CallerCheck.allows(pm, caller, trust)` | the provider's check on every call: a non-null caller its `Trust` trusts |
| `LinkClient(context, …, streams)` | `call(method, version, extras)` (T1's F-3): **acquire** an unstable `ContentProviderClient` for `peer + .link` (none: `not_installed`), **then** check its package is exactly the peer and trusted (else `not_trusted`, nothing called), **then** call through that client with `contract` and `version` and close it, **then** check again (a change discards the reply as `not_trusted`). `{error}`, `{fields, devUnverified}`; a throw or null bundle `no_answer`. A descriptor in a discarded reply is closed |
| `LinkStreams` | the open `ParcelFileDescriptor` ends by handle: `reply(bundle)` (an `fd` → `{stream: <handle>}`, Bundles → maps), `write`, `read` (`MAX_READ` 64 KiB), `close`, `cancel`, `release` (a discarded converted reply), `discard` (a raw one), `closeAll` |
| `ApsiraLinkPlugin` | the `apsira_link/link` channel (`CHANNEL`; `METHOD` = `call`, `WRITE`, `READ`, `CLOSE`, `CANCEL`); `CONTROL_THREADS`, `CONTROL_DEADLINE_MS`; the reply on the main thread |

## Checks

From this directory: `flutter analyze` and `flutter test` (the `link` gate): the failure
codes and their wire names, hello and the version choice, and the adapter against a
mocked channel (every reply shape, a platform error, a missing plugin, a 6 s silence), and
`LinkChannel`'s streams (chunking, the digest, a short, long or altered read, cancels), and
the archive calls (each method's extras, the put cancelled on a size or SHA-256 mismatch, AO
§4's errors, no content in a `toString`, the fake's rules).
From `example/`: `flutter analyze` and `flutter test`, the consumer proof (APSIRA missing,
a hello, a call error, a dev link) against `FakeApsiraLink`, and `release_manifest_test.dart`.
`test/example_android_test.dart` holds the Kotlin names (channel, methods, the deadline and
pool, `F_APSIRA`, `DEV_SWITCH`) and the plugin manifest (`<queries>` for both APSIRA builds, no switch) to the
Dart ones.

The Kotlin half, from this directory, under a build lease (the lease runs its argument as one
shell line; the debug build writes `example/android/gradlew`, which the tests need):

```sh
army lease run --kind build -- 'cd example && flutter build apk --debug'
army lease run --kind build -- 'cd example/android && ./gradlew --offline :apsira_link:testDebugUnitTest'
rm -rf example/build
```

`LinkTrustTest`, `LinkClientTest` (with `AcquireShadow`, which changes APSIRA between the
acquire and the check), `LinkStreamsTest` (real pipes) and `ApsiraLinkPluginTest` (the pool and
the deadline, with a short deadline injected) run on Robolectric (`sdk=34`, cached) with ATRIUM's
`SigningShadow` and two public test certificates (`release-cert.der` `CN=Apsira Test`,
`debug-cert.der` the SDK debug subject; no keystore is committed). They are not a merge gate
(ruling A-4); a Kotlin change is unproven on a device until a release session (a provider
replaced after the acquire killing the bound client is Android's behaviour, not shown here).
