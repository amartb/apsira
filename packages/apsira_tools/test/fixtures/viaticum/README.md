# test/fixtures/viaticum

VIATICUM @ `20f05f6` as `apsira_tools` v0.2 configuration (D-APK-002). Unlike
the other fixture directories, these files are this package's, not RELAY's.
`apsira_tools.yaml` sets every key whose VIATICUM value differs from RELAY's;
its paths are relative to the package root, where `test/viaticum_test.dart`
runs. Each knob has one passing and one failing case:

| Key | Passes | Fails |
|---|---|---|
| `layering.domain_packages` | `layering/clean/core/log.dart` (crypto) | `layering/violations/domain/trips/trip.dart:2` (clock) |
| `layering.feature_packages` | `layering/clean/features/trips/trips_screen.dart` (flutter) | `layering/violations/features/trips/trips_screen.dart:2` (json_annotation) |
| `layering.disabled_rules` | `layering/clean/features/trips/trips_screen.dart:4` (a colour literal) | RELAY's defaults on the same line |
| `layering.forbidden_calls` | `layering/clean/domain/trips/trip.dart:8` (`.isToday`) | `layering/violations/domain/trips/trip.dart:5` (`DateTime.now()`) |
| `layering.extra_layers` | `layering/clean/app/tutorial/tour.dart` imports a feature | `layering/violations/app/tutorial/tour.dart:4` imports `data/` |
| `layering.forbidden_packages` | `layering/clean/app/tutorial/tour.dart` (flutter) | `layering/violations/app/tutorial/tour.dart:2` (flutter_riverpod) |
| `layering.may_import` | `layering/clean/app/l10n/strings.dart` (core, theme) | `layering/violations/app/l10n/strings.dart:2` (domain) |
| `l10n.text_calls` | `l10n/clean/trip_card.dart` | `l10n/violations/trip_card.dart:4-6` |
| `l10n.scan_exemptions` | `l10n/clean/features/spike_lab/lab.dart` | the same file with no exemption |
| `coverage.exempt_export_only` | `coverage/no_barrel/` with `coverage/trip_only.info` | `coverage/barrel/`: the barrel is missing from the report |
| `privacy.dependencies_doc` | `privacy/dependencies.md` | `privacy/dependencies_missing_row.md` (no `crypto` row) |
| `privacy.manifest`, `privacy.approved_permissions`, `privacy.approved_heading` | `privacy/manifest_approved.xml` with `privacy/declared_permissions.txt` | `privacy/manifest_outside.xml` (CAMERA) with `privacy/declared_outside.txt` (no reason) |

`privacy/deps.json` and `privacy/dependency_allowlist.yaml` are the closure
and allowlist the dependency-table cases run with.
