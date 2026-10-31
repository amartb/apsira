# Changelog

## 0.5.0 — 2026-10-31

First release (D-APK-026): the app side of APSIRA's app link (contract `app-link.md` 1.0)
as one Flutter plugin (`pluginClass: ApsiraLinkPlugin`). Dependency `apsira_core`.

- **`ApsiraLink`** with `hello()` and **`ChannelApsiraLink`** over `apsira_link/link`
  (`call` with `method`, `version`, `extras`); no method throws, APSIRA missing is
  unavailable.
- **`LinkFailure`**: `LinkUnavailable` with every `LinkUnavailableReason` and
  `LinkCallFailed` with the six §8 `LinkErrorCode`s; `linkFailureFromWire`.
- **`LinkHello`** and **`chooseLinkVersion`**; `linkContract`, `linkVersions` (`1.0`),
  `linkControlDeadline` (5 s).
- **`linkDevSwitch`**: the `DEV_LINK` meta-data an app declares in its dev source set only.
- **`FakeApsiraLink`** (`testing.dart`). `F_APSIRA` is unset: a release app trusts no APSIRA
  yet.

Migration: none; an app adopts it in its own adoption lane (D-APK-009).
