// From relay lib/data/platform/pending_ports.dart @ 09b28810, with
// viaticum's Result stubs (lib/data/platform/pending_ports.dart @ 78d38e0).
import 'package:apsira_core/apsira_core.dart';

/// The base of a stub for a port whose real implementation lands later.
/// The app keeps its own stubs (`PendingDocScanner extends PendingPort
/// implements DocScanner`); this class is what they share.
///
/// A member that returns a `Result` answers `Err(portPending)`
/// ([pendingResult]), so a caller shows the failure like any other. A
/// member that cannot carry a failure throws an [UnimplementedError]
/// ([pending]) whose message starts with `portPending` and names the port
/// and where its implementation lands.
abstract base class PendingPort {
  const PendingPort(this.port, this.landsWith);

  /// The failure every `Result` member of a stub returns.
  static const portPending = Failure('portPending');

  /// The port's name, as in the app's architecture.
  final String port;

  /// The task (or phase) that lands the real implementation.
  final String landsWith;

  Never pending() => throw UnimplementedError(
    'portPending: $port: the platform implementation lands with $landsWith',
  );

  Future<Result<T, Failure>> pendingResult<T>() async =>
      Err<T, Failure>(portPending);
}
