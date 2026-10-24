// forbidden_calls: without the clock-package group, a getter named like
// the time package's readers is not a call to the system clock.
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../../core/log.dart';

bool due(Day day) => day.isToday;
