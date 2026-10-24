// From relay test/support/prop/prop_core.dart @ 09b28810 (viaticum
// test/support/prop/prop_core.dart @ 78d38e0 is the same code): RELAY_PROP_*
// and VIATICUM_PROP_* are APSIRA_PROP_*, the only change.

/// The engine of the apps' in-house property testing (RELAY D-092): a seeded
/// PRNG, generators that carry their own shrink trees (integrated shrinking, so a
/// shrunk value is always one the generator could have produced), and
/// [forAll], which runs a property, shrinks a failure to a minimal case and
/// reports the seed that replays it. See README.md.
library;

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart' show TestFailure;

/// Runs per property on every run. A long run multiplies it (APSIRA_PROP_SCALE).
const int defaultRuns = 100;

/// The largest size a case is generated at; each case draws its own size in
/// `0..maxSize` from its seed, so replaying a seed replays the size too.
const int defaultMaxSize = 30;

/// The seed the first case starts from when APSIRA_PROP_SEED is not set: runs
/// are deterministic, so a red push reproduces on any machine.
const int defaultSeed = 0x5EED2026;

/// Environment variable multiplying every run count (a long run sets 10).
const String scaleVariable = 'APSIRA_PROP_SCALE';

/// Environment variable naming the seed the first case starts from.
const String seedVariable = 'APSIRA_PROP_SEED';

const int _mask32 = 0xFFFFFFFF;

int _imul32(int a, int b) {
  // (a * b) mod 2^32 without leaving 53-bit integer precision.
  final high = ((a >>> 16) * b) & 0xFFFF;
  return ((high << 16) + (a & 0xFFFF) * b) & _mask32;
}

/// The seed of the case after the case seeded [seed] (a murmur3 finaliser
/// over a golden-ratio step).
int nextSeed(int seed) {
  var h = (seed + 0x9E3779B9) & _mask32;
  h ^= h >>> 16;
  h = _imul32(h, 0x85EBCA6B);
  h ^= h >>> 13;
  h = _imul32(h, 0xC2B2AE35);
  return (h ^ (h >>> 16)) & _mask32;
}

/// A small seeded PRNG (mulberry32). The only randomness property tests use.
final class PropRandom {
  PropRandom(int seed) : _state = seed & _mask32;

  int _state;

  /// The next value in `0..2^32-1`.
  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & _mask32;
    var t = _state;
    t = _imul32(t ^ (t >>> 15), t | 1);
    t ^= (t + _imul32(t ^ (t >>> 7), t | 61)) & _mask32;
    return (t ^ (t >>> 14)) & _mask32;
  }

  /// A value in `0..bound-1`; [bound] is at most 2^32.
  int nextInt(int bound) {
    RangeError.checkValueInInterval(bound, 1, 1 << 32, 'bound');
    return nextUint32() % bound;
  }
}

/// A value and, lazily, the simpler values to try when it fails a property,
/// simplest first.
final class Shrinkable<T> {
  Shrinkable(this.value, [Iterable<Shrinkable<T>> Function()? shrinks])
    : _shrinks = shrinks;

  final T value;
  final Iterable<Shrinkable<T>> Function()? _shrinks;

  Iterable<Shrinkable<T>> get shrinks => _shrinks?.call() ?? const [];

  Shrinkable<R> map<R>(R Function(T value) f) =>
      Shrinkable(f(value), () => shrinks.map((s) => s.map(f)));

  Shrinkable<T>? _where(bool Function(T value) accept) => accept(value)
      ? Shrinkable(value, () => shrinks.map((s) => s._where(accept)).nonNulls)
      : null;
}

/// A generator of [T] values with their shrink trees. Build one from [Gens]
/// and the domain generators; never from an unseeded random generator.
final class Gen<T> {
  const Gen(this._generate);

  final Shrinkable<T> Function(PropRandom random, int size) _generate;

  /// The value tree drawn from [random] at [size].
  Shrinkable<T> generate(PropRandom random, int size) =>
      _generate(random, size);

  Gen<R> map<R>(R Function(T value) f) =>
      Gen((random, size) => _generate(random, size).map(f));

  /// A generator that depends on a generated value. The inner generator gets
  /// its own seed, so shrinking the outer value regenerates the inner one
  /// from the same seed and every shrink stays a value [f] could produce.
  Gen<R> flatMap<R>(Gen<R> Function(T value) f) => Gen((random, size) {
    final outer = _generate(random, size);
    return _bind(outer, f, random.nextUint32(), size);
  });

  static Shrinkable<R> _bind<T, R>(
    Shrinkable<T> outer,
    Gen<R> Function(T value) f,
    int seed,
    int size,
  ) {
    final inner = f(outer.value).generate(PropRandom(seed), size);
    return Shrinkable(inner.value, () sync* {
      for (final o in outer.shrinks) {
        yield _bind(o, f, seed, size);
      }
      yield* inner.shrinks;
    });
  }

  /// Only values [accept] keeps, shrinks included; gives up after [maxTries]
  /// rejected draws in a row.
  Gen<T> where(bool Function(T value) accept, {int maxTries = 100}) =>
      Gen((random, size) {
        for (var i = 0; i < maxTries; i++) {
          final tree = _generate(random, size)._where(accept);
          if (tree != null) return tree;
        }
        throw StateError('where: no accepted value in $maxTries tries');
      });

  /// The values of [count] consecutive cases starting at [seed], exactly as
  /// [forAll] would draw them.
  List<T> sample({required int seed, int count = 10, int? maxSize}) {
    final values = <T>[];
    var caseSeed = seed & _mask32;
    for (var i = 0; i < count; i++) {
      values.add(_case(this, caseSeed, maxSize ?? defaultMaxSize).value);
      caseSeed = nextSeed(caseSeed);
    }
    return values;
  }
}

Shrinkable<T> _case<T>(Gen<T> gen, int seed, int maxSize) {
  final random = PropRandom(seed);
  return gen.generate(random, random.nextInt(maxSize + 1));
}

/// The basic generators; the domain ones (text, edits, dates) stay in each
/// app's test/support/prop/.
abstract final class Gens {
  static Gen<T> constant<T>(T value) => Gen((_, _) => Shrinkable(value));

  /// An integer in `min..max` that shrinks towards 0, or towards the bound
  /// nearest 0 when 0 is outside the range.
  static Gen<int> intRange(int min, int max) {
    if (max < min || max - min >= 1 << 32) {
      throw ArgumentError('intRange($min, $max): empty or wider than 2^32');
    }
    final origin = min > 0 ? min : (max < 0 ? max : 0);
    return Gen(
      (random, _) => _towards(min + random.nextInt(max - min + 1), origin),
    );
  }

  static Shrinkable<int> _towards(int value, int origin) =>
      Shrinkable(value, () sync* {
        for (var d = value - origin; d != 0; d = d ~/ 2) {
          yield _towards(value - d, origin);
        }
      });

  static final Gen<bool> boolean = elementOf(const [false, true]);

  /// One of [values], shrinking towards the first.
  static Gen<T> elementOf<T>(List<T> values) {
    if (values.isEmpty) throw ArgumentError('elementOf: no values');
    final list = List<T>.unmodifiable(values);
    return intRange(0, list.length - 1).map((i) => list[i]);
  }

  /// A value from one of [gens], shrinking towards the first generator.
  static Gen<T> oneOf<T>(List<Gen<T>> gens) =>
      frequency([for (final g in gens) (1, g)]);

  /// A value from a generator picked by weight, shrinking towards the first.
  static Gen<T> frequency<T>(List<(int, Gen<T>)> weighted) {
    final total = weighted.fold<int>(0, (sum, w) => sum + w.$1);
    if (weighted.isEmpty || weighted.any((w) => w.$1 < 1)) {
      throw ArgumentError('frequency: weights must be positive');
    }
    return intRange(0, total - 1).flatMap((k) {
      var left = k;
      for (final (weight, gen) in weighted) {
        if (left < weight) return gen;
        left -= weight;
      }
      throw StateError('unreachable');
    });
  }

  /// null or a value of [gen], shrinking towards null.
  static Gen<T?> optional<T>(Gen<T> gen, {int presentWeight = 3}) =>
      frequency<T?>([(1, constant<T?>(null)), (presentWeight, gen)]);

  /// A list of [min]..[max] values (at most [min] + size when [max] is null).
  /// It shrinks by dropping runs of elements, then by shrinking each one.
  static Gen<List<T>> listOf<T>(Gen<T> gen, {int min = 0, int? max}) => Gen((
    random,
    size,
  ) {
    final upper = max ?? min + size;
    final length = min + random.nextInt(math.max(upper - min, 0) + 1);
    final items = [for (var i = 0; i < length; i++) gen.generate(random, size)];
    return _listTree(items, min);
  });

  static Shrinkable<List<T>> _listTree<T>(List<Shrinkable<T>> items, int min) =>
      Shrinkable(List.unmodifiable(items.map((e) => e.value)), () sync* {
        final n = items.length;
        for (var k = n; k > 0; k ~/= 2) {
          if (n - k < min) continue;
          for (var start = 0; start + k <= n; start += k) {
            yield _listTree([
              ...items.sublist(0, start),
              ...items.sublist(start + k),
            ], min);
          }
        }
        for (var i = 0; i < n; i++) {
          for (final s in items[i].shrinks) {
            yield _listTree([...items]..[i] = s, min);
          }
        }
      });

  static Gen<(A, B)> zip<A, B>(Gen<A> a, Gen<B> b) =>
      a.flatMap((x) => b.map((y) => (x, y)));

  static Gen<(A, B, C)> zip3<A, B, C>(Gen<A> a, Gen<B> b, Gen<C> c) =>
      zip(a, zip(b, c)).map((v) => (v.$1, v.$2.$1, v.$2.$2));
}

/// How many runs and from which seed: [PropConfig.fromEnvironment] reads
/// APSIRA_PROP_SCALE and APSIRA_PROP_SEED.
final class PropConfig {
  const PropConfig({this.scale = 1, this.seed});

  /// Reads [env] (the process environment when null). A value that cannot be
  /// used is an error, never silently ignored.
  factory PropConfig.fromEnvironment([Map<String, String>? env]) {
    final vars = env ?? Platform.environment;
    final rawScale = vars[scaleVariable];
    final rawSeed = vars[seedVariable];
    var scale = 1;
    if (rawScale != null && rawScale.isNotEmpty) {
      final parsed = int.tryParse(rawScale);
      if (parsed == null || parsed < 1) {
        throw ArgumentError('$scaleVariable must be a positive integer');
      }
      scale = parsed;
    }
    int? seed;
    if (rawSeed != null && rawSeed.isNotEmpty) {
      seed = int.tryParse(rawSeed);
      if (seed == null || seed < 0 || seed > _mask32) {
        throw ArgumentError('$seedVariable must be an integer in 0..$_mask32');
      }
    }
    return PropConfig(scale: scale, seed: seed);
  }

  final int scale;
  final int? seed;
}

/// A property that failed: the seed of the failing case, the case as drawn
/// and as shrunk, and why. Its message is what the test runner prints.
final class PropertyFailure extends TestFailure {
  PropertyFailure({
    required this.seed,
    required this.run,
    required this.runs,
    required this.original,
    required this.minimal,
    required this.shrinks,
    required this.reason,
    required String Function(Object? value) show,
  }) : super(
         'Property failed on run $run of $runs.\n'
         'Seed: $seed (replay with $seedVariable=$seed)\n'
         'Minimal case (after $shrinks shrinks): ${show(minimal)}\n'
         'Original case: ${show(original)}\n'
         'Failure: $reason',
       );

  final int seed;
  final int run;
  final int runs;
  final Object? original;
  final Object? minimal;
  final int shrinks;
  final String reason;
}

/// Checks [property] on `runs × scale` cases of [gen]. The property fails by
/// returning false or throwing (an `expect` included); the failure is shrunk
/// and thrown as a [PropertyFailure]. Call it from a test body:
/// `test('…', () => forAll(gen, (x) => …));`.
Future<void> forAll<T>(
  Gen<T> gen,
  FutureOr<Object?> Function(T value) property, {
  int runs = defaultRuns,
  int maxSize = defaultMaxSize,
  int maxShrinks = 1000,
  PropConfig? config,
  String Function(T value)? show,
}) async {
  final settings = config ?? PropConfig.fromEnvironment();
  final total = runs * settings.scale;
  var seed = settings.seed ?? defaultSeed;
  for (var run = 1; run <= total; run++) {
    final tree = _case(gen, seed, maxSize);
    final reason = await _check(property, tree.value);
    if (reason != null) {
      final (minimal, why, steps) = await _shrink(
        tree,
        reason,
        property,
        maxShrinks,
      );
      throw PropertyFailure(
        seed: seed,
        run: run,
        runs: total,
        original: tree.value,
        minimal: minimal,
        shrinks: steps,
        reason: why,
        show: (v) => show == null ? describeValue(v) : show(v as T),
      );
    }
    seed = nextSeed(seed);
  }
}

Future<String?> _check<T>(
  FutureOr<Object?> Function(T value) property,
  T value,
) async {
  try {
    final result = await property(value);
    return result == false ? 'returned false' : null;
  } on TestFailure catch (error) {
    return 'threw ${error.message}';
  } on Object catch (error) {
    return 'threw $error';
  }
}

/// Greedy shrinking: take the first simpler value that still fails, repeat.
Future<(T, String, int)> _shrink<T>(
  Shrinkable<T> failing,
  String reason,
  FutureOr<Object?> Function(T value) property,
  int maxShrinks,
) async {
  var current = failing;
  var why = reason;
  var steps = 0;
  var attempts = 0;
  search:
  while (steps < maxShrinks) {
    for (final candidate in current.shrinks) {
      if (++attempts > maxShrinks * 20) break search;
      final r = await _check(property, candidate.value);
      if (r != null) {
        current = candidate;
        why = r;
        steps++;
        continue search;
      }
    }
    break;
  }
  return (current.value, why, steps);
}

/// A readable form of a case: strings quoted, with control, zero-width,
/// combining and variation-selector code points (and lone surrogates)
/// escaped as `\u{…}`; lists element by element.
String describeValue(Object? value) {
  if (value is String) return _quote(value);
  if (value is Iterable<Object?>) {
    return '[${value.map(describeValue).join(', ')}]';
  }
  return '$value';
}

String _quote(String s) {
  final out = StringBuffer("'");
  for (final r in s.runes) {
    if (r == 0x27) {
      out.write(r"\'");
    } else if (r == 0x5C) {
      out.write(r'\\');
    } else if (r == 0x0A) {
      out.write(r'\n');
    } else if (_invisible(r)) {
      out.write('\\u{${r.toRadixString(16).toUpperCase()}}');
    } else {
      out.writeCharCode(r);
    }
  }
  return (out..write("'")).toString();
}

bool _invisible(int r) =>
    r < 0x20 ||
    (r >= 0x7F && r <= 0x9F) ||
    (r >= 0x0300 && r <= 0x036F) ||
    (r >= 0x200B && r <= 0x200F) ||
    r == 0x2060 ||
    (r >= 0xD800 && r <= 0xDFFF) ||
    (r >= 0xFE00 && r <= 0xFE0F);
