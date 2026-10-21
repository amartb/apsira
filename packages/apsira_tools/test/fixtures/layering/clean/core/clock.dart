import 'dart:async';

import 'package:meta/meta.dart';

/// Now (UTC). Implementations call DateTime.now(); this port never does.
abstract interface class Clock {
  DateTime nowUtc();
}

@immutable
class Tick {
  const Tick();
}
