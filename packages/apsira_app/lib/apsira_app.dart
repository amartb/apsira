/// The app shell every Apsira app shares: the global [ErrorHandlers], the
/// rotating [FileLogSink], the start gate's [startRedirect],
/// [RestartableRoot], [StartupFailureApp], [SystemClock] with the
/// [ZoneChannel] (and its Android half, `ZoneModule.kt`), the [PendingPort]
/// stub base, per-install [InstallFlag] files and the [AboutPage].
///
/// Test helpers are in `package:apsira_app/testing.dart`.
library;

export 'src/about_page.dart';
export 'src/error_handlers.dart';
export 'src/file_log_sink.dart';
export 'src/install_flag.dart';
export 'src/pending_ports.dart';
export 'src/restartable_root.dart';
export 'src/start_redirect.dart';
export 'src/startup_failure_app.dart';
export 'src/system_clock.dart';
export 'src/zone_channel.dart';
