import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
// D-108: freezed's annotations are pure Dart; generated code joins them.
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:relay/core/clock.dart';

import '../tags/tag.dart';

// Time comes from Clock, never DateTime.now(); IDs from IdGen, never
// Random() or Uuid().
const hint = 'DateTime.now() and Random() in a string are not calls';

DateTime created(Clock clock) => clock.nowUtc();

final noRandom = max(1, 2);
