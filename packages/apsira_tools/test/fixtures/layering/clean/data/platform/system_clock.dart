import 'package:path_provider/path_provider.dart';
import 'package:relay/core/clock.dart';

/// Data may read the real time: it implements the Clock port.
class SystemClock implements Clock {
  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}
