// From relay test/support/prop/prop_core_test.dart @ 09b28810, unchanged but
// for RELAY_PROP_* renamed APSIRA_PROP_* (prop.dart here supplies TextGens).
import 'package:flutter_test/flutter_test.dart';

import 'prop.dart';

/// A deliberately buggy reversal (07 P0-21 acceptance): it sorts in
/// descending order instead of reversing, so it is right on every list that
/// is already in ascending order and wrong on any list with a descent.
List<int> reverseBySorting(List<int> xs) =>
    [...xs]..sort((a, b) => b.compareTo(a));

/// A reversal that works on UTF-16 code units, so it splits surrogate pairs.
String reverseCodeUnits(String s) => String.fromCharCodes(s.codeUnits.reversed);

final Gen<List<int>> smallLists = Gens.listOf(Gens.intRange(0, 100));

bool reversesCorrectly(List<int> xs) =>
    listEquals(reverseBySorting(xs), xs.reversed.toList());

Future<PropertyFailure> failureOf(Future<void> Function() run) async {
  try {
    await run();
  } on PropertyFailure catch (failure) {
    return failure;
  }
  fail('the property was expected to fail');
}

bool listEquals(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main() {
  group('PropRandom', () {
    test('the same seed gives the same stream, another seed another', () {
      List<int> stream(int seed) {
        final random = PropRandom(seed);
        return [for (var i = 0; i < 16; i++) random.nextUint32()];
      }

      expect(stream(42), stream(42));
      expect(stream(42), isNot(stream(43)));
      expect(stream(42).every((v) => v >= 0 && v <= 0xFFFFFFFF), isTrue);
    });

    test('nextInt stays inside its bound', () {
      final random = PropRandom(7);
      for (var i = 0; i < 1000; i++) {
        expect(random.nextInt(6), inInclusiveRange(0, 5));
      }
    });
  });

  group('PropConfig', () {
    test('defaults to scale 1 and no seed', () {
      final config = PropConfig.fromEnvironment(const {});
      expect(config.scale, 1);
      expect(config.seed, isNull);
    });

    test('reads APSIRA_PROP_SCALE and APSIRA_PROP_SEED', () {
      final config = PropConfig.fromEnvironment(const {
        'APSIRA_PROP_SCALE': '10',
        'APSIRA_PROP_SEED': '123456',
      });
      expect(config.scale, 10);
      expect(config.seed, 123456);
    });

    test('refuses a scale or seed it cannot use, rather than ignoring it', () {
      for (final scale in ['0', '-1', 'x', '1.5']) {
        expect(
          () => PropConfig.fromEnvironment({'APSIRA_PROP_SCALE': scale}),
          throwsArgumentError,
          reason: scale,
        );
      }
      for (final seed in ['-1', 'abc', '4294967296']) {
        expect(
          () => PropConfig.fromEnvironment({'APSIRA_PROP_SEED': seed}),
          throwsArgumentError,
          reason: seed,
        );
      }
    });
  });

  group('forAll run counts', () {
    Future<int> countRuns(Map<String, String> env, {int? runs}) async {
      var calls = 0;
      final config = PropConfig.fromEnvironment(env);
      if (runs == null) {
        await forAll(Gens.intRange(0, 9), (_) => calls++, config: config);
      } else {
        await forAll(
          Gens.intRange(0, 9),
          (_) => calls++,
          runs: runs,
          config: config,
        );
      }
      return calls;
    }

    test('the default per-push count is bounded', () async {
      expect(defaultRuns, inInclusiveRange(1, 200));
      expect(await countRuns(const {}), defaultRuns);
    });

    test('APSIRA_PROP_SCALE=10 (nightly) runs ten times as many', () async {
      expect(
        await countRuns(const {'APSIRA_PROP_SCALE': '10'}),
        10 * defaultRuns,
      );
    });

    test('an explicit run count is multiplied by the scale too', () async {
      expect(await countRuns(const {}, runs: 25), 25);
      expect(await countRuns(const {'APSIRA_PROP_SCALE': '10'}, runs: 25), 250);
    });
  });

  group('shrinking', () {
    test('the buggy reversal is caught and shrunk to [1, 0]', () async {
      final failure = await failureOf(
        () => forAll(
          smallLists,
          reversesCorrectly,
          config: PropConfig.fromEnvironment(const {}),
        ),
      );
      expect(failure.minimal, [1, 0]);
      expect((failure.original! as List<int>).length, greaterThanOrEqualTo(2));
      expect(failure.reason, 'returned false');
    });

    test('a failing expect is caught, shrunk and reported', () async {
      final failure = await failureOf(
        () => forAll(
          smallLists,
          (xs) => expect(reverseBySorting(xs), xs.reversed.toList()),
          config: PropConfig.fromEnvironment(const {}),
        ),
      );
      expect(failure.minimal, [1, 0]);
      expect(failure.reason, contains('Expected'));
    });

    test(
      'a string reversal that splits surrogate pairs shrinks to one emoji',
      () async {
        final failure = await failureOf(
          () => forAll(
            TextGens.text(),
            (s) => listEquals(
              reverseCodeUnits(s).runes.toList(),
              s.runes.toList().reversed.toList(),
            ),
            config: PropConfig.fromEnvironment(const {}),
          ),
        );
        expect(failure.minimal, '\u{1F600}');
      },
    );

    test('every shrink of a string is well-formed UTF-16', () {
      final random = PropRandom(99);
      for (var n = 0; n < 20; n++) {
        final tree = TextGens.text().generate(random, 20);
        var level = [tree];
        for (var depth = 0; depth < 3; depth++) {
          final next = <Shrinkable<String>>[];
          for (final node in level) {
            expect(hasLoneSurrogate(node.value), isFalse, reason: node.value);
            next.addAll(node.shrinks.take(8));
          }
          level = next;
        }
      }
    });

    test('where keeps only accepted values, shrinks included', () async {
      final evens = Gens.intRange(0, 1000).where((n) => n.isEven);
      final failure = await failureOf(
        () => forAll(
          evens,
          (n) => n < 10,
          config: PropConfig.fromEnvironment(const {}),
        ),
      );
      expect(failure.minimal, 10);
    });
  });

  group('seed replay', () {
    test('a failure prints the seed and the minimal case', () async {
      final failure = await failureOf(
        () => forAll(
          smallLists,
          reversesCorrectly,
          config: PropConfig.fromEnvironment(const {}),
        ),
      );
      final message = failure.message!;
      expect(message, contains('APSIRA_PROP_SEED=${failure.seed}'));
      expect(message, contains('Minimal case'));
      expect(message, contains('[1, 0]'));
      expect(message, contains('Original case'));
    });

    test(
      'APSIRA_PROP_SEED=<printed seed> replays the identical failure',
      () async {
        final first = await failureOf(
          () => forAll(
            smallLists,
            reversesCorrectly,
            config: PropConfig.fromEnvironment(const {}),
          ),
        );
        final printed = RegExp(r'APSIRA_PROP_SEED=(\d+)')
            .firstMatch(first.message!)!
            .group(1)!;

        final replay = await failureOf(
          () => forAll(
            smallLists,
            reversesCorrectly,
            config: PropConfig.fromEnvironment({'APSIRA_PROP_SEED': printed}),
          ),
        );
        expect(replay.run, 1);
        expect(replay.seed, first.seed);
        expect(replay.original, first.original);
        expect(replay.minimal, first.minimal);
        expect(replay.shrinks, first.shrinks);
      },
    );

    test('values are described with invisible code points escaped', () {
      expect(describeValue('a‍b'), r"'a\u{200D}b'");
      expect(describeValue('it\'s'), r"'it\'s'");
      expect(describeValue(['\u{1F600}', 1]), "['\u{1F600}', 1]");
    });
  });
}
