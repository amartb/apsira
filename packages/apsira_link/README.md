# apsira_link

The app side of the on-device link to APSIRA, the central app (D-APK-026; the interface is
APSIRA's `master-app/docs/contracts/app-link.md`, version 1.0). One Flutter plugin: a Dart
port with typed failures over one method channel, and the package's own Kotlin, which
resolves APSIRA and checks its certificate before any call.

Dependencies: `apsira_core` (the git form at the shared tag, with the committed
`pubspec_overrides.yaml`, D-APK-007). Nothing else: the trust check is the package's Kotlin.

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
| `LinkErrorCode` | The six call errors of §8: `busy`, `away`, `storage_full`, `not_found`, `not_allowed`, `checksum_mismatch`; codes `linkBusy` … |
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

## The channel

Dart never selects a trust mode (ruling R-2). One method, `call`:

| Direction | Shape |
|---|---|
| Dart → Kotlin | `{method: String, version: String, extras: Map<String, Object?>}`, exactly these keys; `hello` sends `linkVersions.last` and empty extras |
| Kotlin → Dart, unavailable | `{unavailable: <reason wire>}` |
| Kotlin → Dart, call error | `{error: <§8 code>}` |
| Kotlin → Dart, answer | `{fields: Map, devUnverified: bool}` |
| No reply in 5 s, `PlatformException`, `MissingPluginException` | `no_answer` |
| `null` or any other shape | `unknown_error` |

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
| `LinkClient(context, …)` | `call(method, version, extras)`: resolve `peer + .link` (none: `not_installed`), its package exactly the peer and trusted (else `not_trusted`, nothing called), then `ContentResolver.call` with `contract` and `version`; `{error}`, `{fields, devUnverified}`, a throw or null bundle `no_answer` |
| `ApsiraLinkPlugin` | the `apsira_link/link` channel (`CHANNEL`, `METHOD` = `call`); `LinkClient` on one background thread, the reply on the main thread |

## Checks

From this directory: `flutter analyze` and `flutter test` (the `link` gate): the failure
codes and their wire names, hello and the version choice, and the adapter against a
mocked channel (every reply shape, a platform error, a missing plugin, a 6 s silence).
From `example/`: `flutter analyze` and `flutter test`, the consumer proof (APSIRA missing,
a hello, a call error, a dev link) against `FakeApsiraLink`, and `release_manifest_test.dart`.
`test/example_android_test.dart` holds the Kotlin names (channel, method, `F_APSIRA`,
`DEV_SWITCH`) and the plugin manifest (`<queries>` for both APSIRA builds, no switch) to the
Dart ones.

The Kotlin half, from this directory, under a build lease (the lease runs its argument as one
shell line; the debug build writes `example/android/gradlew`, which the tests need):

```sh
army lease run --kind build -- 'cd example && flutter build apk --debug'
army lease run --kind build -- 'cd example/android && ./gradlew --offline :apsira_link:testDebugUnitTest'
rm -rf example/build
```

`LinkTrustTest` and `LinkClientTest` run on Robolectric (`sdk=34`, cached) with ATRIUM's
`SigningShadow` and two public test certificates (`release-cert.der` `CN=Apsira Test`,
`debug-cert.der` the SDK debug subject; no keystore is committed). They are not a merge gate
(ruling A-4); a Kotlin change is unproven on a device until a release session.
