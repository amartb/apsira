# apsira_lock

The app lock every Apsira app shares: RELAY's lock (D-APK-016) as one Flutter plugin. The
system biometric or screen-lock prompt at launch and after a timeout in the background,
behind a branded cover, with "hide in recent apps" beside it. It protects against casual
access to an unlocked phone; it is not encryption.

Dependencies: `apsira_core`, `apsira_l10n`, `apsira_ui` (the git form at the shared tag,
with the committed `pubspec_overrides.yaml`, D-APK-007), `flutter_riverpod ^3.1.0`,
`local_auth ^3.0.2` and `local_auth_android ^2.3.0` (ruling R-1). FLAG_SECURE is the
package's own Kotlin; there is no window-manager plugin.

```yaml
dependencies:
  apsira_lock: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.5.0, path: packages/apsira_lock } }
```

## Consumer requirements

- `MainActivity` is a `FlutterFragmentActivity` (`local_auth`'s BiometricPrompt needs a
  FragmentActivity).
- The manifest declares `<uses-permission android:name="android.permission.USE_BIOMETRIC" />`.
- `MaterialApp.localizationsDelegates` includes `ApsiraL10n.delegate`.

`example/` meets all three; `test/example_android_test.dart` checks them.

## Binding it

```dart
ProviderScope(overrides: [
  authenticatorProvider.overrideWithValue(LocalAuthAuthenticator()),
  screenPrivacyProvider.overrideWithValue(const FlagSecureScreenPrivacy()),
  lockClockProvider.overrideWith((ref) => ref.watch(clockProvider)),   // the app's Clock
  lockLogProvider.overrideWith((ref) => ref.watch(logProvider)),       // the app's Log
  lockSettingsStoreProvider.overrideWithValue(MyLockSettingsStore()),  // the app's keys
], child: MaterialApp(
  builder: (context, child) => LockShield(
    appTitle: 'Relay',
    promptReason: (context) => AppLocalizations.of(context).lockPromptReason,
    child: child!,
  ),
  …,
));
```

An unbound port never shuts the user out: no store or no authenticator leaves the lock off
(`lock.notEngaged`), no clock never shields in the background (`lock.clockUnreadable`),
and an unbound screen privacy logs `lock.recentsNotApplied`.

## Settings

`LockSettings(enabled, timeoutMinutes, hideInRecents)`, stored as RELAY's row:

```json
{"enabled":false,"timeoutMinutes":5,"hideInRecents":false}
```

`toJson` writes exactly that; `fromJson` reads a missing or mistyped field as its
default, so the lock is off until the user turns it on. The package never chooses a key:
the app's `LockSettingsStore` (`read`, `write`) keeps its own (RELAY the `lock` row,
LYCEUM `app_lock_enabled` and `auto_lock_minutes`), and `LockSettings.mergeInto(row)`
keeps the fields a later version wrote. `lockSettingsProvider` reads the store once; the
Settings rows write through `LockSettingsSetting.change`, which reads the store again,
writes, and only then follows the change (a failed write rethrows). An app that changes the
stored settings any other way (a restore) calls `ref.invalidate(lockSettingsProvider)`.

## Controller

`lockControllerProvider` (`LockController`, `LockState`):

| Phase | Covered | When |
|---|---|---|
| `starting` | yes | launch, until the settings are read (at most 2 s, `lockSettingsReadBound`) |
| `unlocked` | no | lock off, a passed prompt, or the lock not engaged |
| `shielded` | yes | in the background with the lock on |
| `locked` | yes | waiting for the prompt, or for Unlock after a failed or cancelled one |
| `authenticating` | yes | the system prompt is up |

- **Launch:** with `enabled`, it locks when the `Authenticator` is available, the prompt due.
- **Background:** on `paused` it records the clock's `nowUtc()` and shields. On the first
  step back it locks when `timeoutMinutes` have passed (0 locks at once; a clock that went
  backwards locks too), and otherwise opens.
- **The prompt:** passed opens; failed or cancelled stays locked with the retry message and
  Unlock, with no counter and no back-off, and never prompts again by itself until the next
  return. A pause while the prompt is up (the credential screen) is not a background.
- Turning the lock on while open locks at the next launch or timeout; turning it off brings
  the cover down.
- **Lock now:** `lockNow()` (an app's "Lock now" row) locks at once with the prompt due, as
  after the timeout, only while the lock is on and the app is shown; otherwise it changes
  nothing.
- **Never a lock-out:** a store that throws or does not answer within 2 s, or an
  `Authenticator` that is unavailable or throws, leaves the lock off and logs
  `WARNING lock.notEngaged code=<unavailable|authenticatorError|settingsUnreadable>`, with
  the error's type and nothing else (under the mandatory policy it stays covered: see below).

## Mandatory mode

`lockPolicyProvider` is `LockPolicy.optional` (everything above) unless the app overrides it.
APSIRA, whose lock cannot be turned off (D-018, D-APK-026), binds the mandatory policy with
its own line for a phone with no screen lock (the package has no string for it):

```dart
lockPolicyProvider.overrideWithValue(LockPolicy.mandatory.copyWith(
  cannotPromptMessage: (context) => AppLocalizations.of(context).lockSetScreenLock,
)),
```

| | `LockPolicy.optional` | `LockPolicy.mandatory` |
|---|---|---|
| `isMandatory` | false | true |
| `timeoutOptions` | 0, 1, 5, 15, 30 | 0, 1, 5 |
| `defaults` | off, 5 minutes | on, 1 minute |

Under the mandatory policy the lock never opens unlocked:

- `lockSettingsProvider` reads and writes the app's store through
  `MandatoryLockSettingsStore`: a stored `enabled: false` reads and is written as on, and
  no store, a read that throws or one slower than `mandatoryReadBound` (1 s) reads as the
  policy's defaults (`lock.settingsReadFailed`), so launch locks. An app's own store passes
  `LockSettings.fromJson(row, fallback: LockPolicy.mandatory.defaults)` so a fresh install
  gets 1 minute.
- A device that cannot prompt, or an `Authenticator` that throws, keeps the cover:
  `LockState.cannotPrompt` (`locked` with `lastOutcome: unavailable`), no prompt due, logged
  `lock.notEngaged code=<unavailable|authenticatorError>`. The cover shows the policy's
  `cannotPromptMessage` (`lock/notice`) and Unlock as the retry, and no other button; a
  return from the background prompts once. No counter, no back-off.
- The Settings rows show **App lock** without its switch and **Lock after** always, with the
  policy's options (and a stored value outside them).

## Re-confirm

`LockController.reconfirm(prompt)` asks for a fresh confirmation before a sensitive act
(D-018: install, restore, pair, revoke), whatever the settings say, and answers a
`ReconfirmOutcome`; the act goes ahead only when `outcome.proceeds`:

| Outcome | When | `proceeds` |
|---|---|---|
| `confirmed` | passed | yes |
| `declined` | failed or cancelled (no counter, no back-off); the app covered; another re-confirm pending — no prompt in the last two | no |
| `skipped` | optional policy: unavailable or a throw, logged `lock.reconfirmSkipped code=…` | yes |
| `unavailable` | mandatory policy: unavailable or a throw, logged `lock.reconfirmUnavailable code=…` | no |

While its prompt is up, the pause it causes is not a background: at a timeout of 0 the app
does not lock under the user. A pause the app has not come back from when the prompt
resolves (Home pressed with the prompt up) is a background from that moment: the outcome
stands, the app shields, and the return locks past **Lock after** (at 0, at once).

## Hide in recents

`RecentsPrivacy` applies `hideInRecents` to `ScreenPrivacy` when the settings are first
read and on every change, whether the lock is on or not, and again on every return from the
background. `FlagSecureScreenPrivacy` calls `setHidden(bool)` on the channel
`apsira_lock/screen_privacy`; `ScreenPrivacyModule.kt` sets or clears `FLAG_SECURE` on the
activity's window, keeps the last state asked for and sets it on every activity it attaches
to (a rotation, a recreated activity). No activity is a `PlatformException`
(`noActivity`); anywhere but Android an `UnsupportedError`. Both are logged, never thrown at
the user.

## Widgets

- `LockShield({child, appTitle, promptReason, isExempt, exemptChanges, promptHeld, coverIcon})` in
  `MaterialApp.builder`: the cover from the first frame; the content stays built, out of
  semantics, not hit-tested, tickers paused, and offstage once locked; Back while covered
  leaves the app. `isExempt` (with `exemptChanges`, the listenable that says when its
  answer changes) lets an app show some screens without the lock, as RELAY's KAIROS space.
- `LockCover({appTitle, onUnlock, showRetry, icon, notice})`: the `ground` screen with one bordered
  `surface` card, the lock glyph, the app's title as the wordmark; never any content. `icon`
  (the shield's `coverIcon`) is the app's glyph, `Icon(AppIcons.lock)`, drawn at the cover's
  size in `accentText`; without it, Material's `lock_outline`. `notice` is the app's line
  under the cover's (`lock/notice`, the mandatory policy's `cannotPromptMessage`).
- `LockSettingsSection({note})`: **App lock**, **Lock after** (Immediately, 1, 5, 15, 30
  minutes, and a stored value outside the list; the mandatory policy's options and no lock
  switch under it) and **Hide in recent apps**, on
  `apsira_ui`'s settings rows, rows only (the app places them in its card); `note` is a line
  under them.

Keys: `lock/cover`, `lock/retry`, `lock/notice`, `lock/unlock`, `lock/settings/enabled`,
`lock/settings/timeout`, `lock/settings/hideInRecents`, `lock/settings/note`.

## What it holds, and what each app deletes

Sources: RELAY `09b28810`, VIATICUM `78d38e0`, LYCEUM `9f4ff27`; each file names its
source in its header. "Replaces" is under the app's root; the adoption lane confirms it.

| Symbol | Source | Replaces in RELAY | in LYCEUM |
|---|---|---|---|
| `Authenticator`, `AuthOutcome`, `AuthPrompt` (+ `AuthPrompt.of`) | R `lib/core/ports/authenticator.dart` | that file; `authPromptOf` | `lib/core/ports/authenticator.dart`, `lib/app/l10n/lock_prompt.dart` |
| `LocalAuthAuthenticator` | R `lib/data/platform/local_auth_authenticator.dart` | that file | `lib/data/platform/local_auth_authenticator.dart` |
| `ScreenPrivacy`, `FlagSecureScreenPrivacy`, `ApsiraLockPlugin.kt`, `ScreenPrivacyModule.kt` | R `lib/core/ports/screen_privacy.dart`, `lib/data/platform/screen_privacy.dart` | both files and `flutter_windowmanager_plus` | — (new: `app_lock_hide_in_recents`, off) |
| `RecentsPrivacy` (`enterRelay` is `leaveExempt`) | R `lib/features/lock/state/recents_privacy.dart` | that file | — |
| `LockSettings`, `lockTimeoutOptions`, `LockSettingsStore`, `lockSettingsProvider` | R `lib/features/lock/state/lock_settings.dart`; `lockTimeoutChoices`, `updateLockSettings` | that file (its `lock` row read and merge become its store) | its keys behind its store (`lib/app/services/auth_service.dart`) |
| `LockController`, `LockState`, `LockPhase`, `LockSkip`, the providers | R `lib/features/lock/state/lock_controller.dart` | that file | its lock state in `auth_service.dart` |
| `LockShield` | R `lib/features/lock/ui/lock_gate.dart` (`LockGate`) | `LockGate`; `LockCrossing`, `CrossingRouter`, `LockExemptRoute` and `route_privacy.dart` stay | — |
| `LockCover` | R `lib/features/lock/ui/lock_cover.dart` | that file | `lib/features/auth/ui/lock_screen.dart` |
| `LockSettingsSection` | R `lib/features/lock/ui/lock_settings_section.dart`; the note of `_LockRowsWithCalendarNote` | that file | its lock rows |
| `LockPolicy`, `lockPolicyProvider`, `MandatoryLockSettingsStore`, `mandatoryReadBound`, `ReconfirmOutcome`, `LockController.reconfirm`, `LockState.cannotPrompt`, `LockCover.notice` | the package's own (D-APK-026) | — | — |
| `FakeAuthenticator`, `FakeScreenPrivacy`, `FakeLockSettingsStore` (`testing.dart`) | R `test/fakes/` | `fake_authenticator.dart`, `fake_screen_privacy.dart` | `test/fakes/fake_authenticator.dart` |

VIATICUM has no lock (its D-036); it gains this one off by default and supersedes D-036 in
its own log.

## Checks

From this directory: `flutter analyze` and `flutter test` (the `lock` gate): the
controller, settings, recents and shield tests ported from RELAY, the mandatory policy and
re-confirm (`lock_policy_test`, `lock_mandatory_test`, `lock_reconfirm_test`), the adapter against a
scripted `local_auth`, FLAG_SECURE against a mocked channel, and EN/ES × 100–200 % layout
of the cover, the shield and the rows. Mocked channels cannot see a mismatch between the
Dart and Kotlin halves, so `example/`'s debug build compiles them: run by hand, under a
build lease, from `example/`: `flutter build apk --debug && rm -rf build`.
