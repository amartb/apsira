/// Every apsira_tools check as a library, for an app's tool/ wrapper that
/// adds its own rules: the configuration ([ApsiraToolsConfig]), the coverage
/// gate, the dependency and manifest checks of the privacy guards, the l10n
/// check and the layering lint. Each is also its own library
/// (`package:apsira_tools/<check>.dart`); `src/` stays private.
library;

export 'config.dart';
export 'coverage_gate.dart';
export 'deps_check.dart';
export 'l10n_check.dart';
export 'layering_lint.dart';
export 'manifest_check.dart';
