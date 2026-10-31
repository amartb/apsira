import 'dart:async';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_link/apsira_link.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel(ChannelApsiraLink.channelName);

void _answer(Future<Object?>? Function(MethodCall call)? handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

Map<Object?, Object?> _hello({bool devUnverified = false}) => {
  'fields': {
    'versions': ['1.0'],
    'app_version': '0.1.0',
    'locked': false,
  },
  'devUnverified': devUnverified,
};

Err<LinkHello, LinkFailure> _unavailable(LinkUnavailableReason reason) =>
    Err(LinkUnavailable(reason));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const link = ChannelApsiraLink();

  tearDown(() => _answer(null));

  test('the channel name and the control deadline', () {
    expect(ChannelApsiraLink.channelName, 'apsira_link/link');
    expect(linkControlDeadline, const Duration(seconds: 5));
  });

  test('hello sends exactly method, version and extras on "call"', () async {
    final calls = <MethodCall>[];
    _answer((call) async {
      calls.add(call);
      return _hello();
    });
    await link.hello();
    expect(calls, hasLength(1));
    expect(calls.single.method, 'call');
    final arguments = calls.single.arguments as Map<Object?, Object?>;
    expect(arguments.keys.toSet(), {'method', 'version', 'extras'});
    expect(arguments['method'], 'hello');
    expect(arguments['version'], linkVersions.last);
    expect(arguments['extras'], isEmpty);
  });

  test('a fields reply is the hello', () async {
    _answer((call) async => _hello());
    expect(
      await link.hello(),
      const Ok<LinkHello, LinkFailure>(
        LinkHello(
          version: '1.0',
          versions: ['1.0'],
          appVersion: '0.1.0',
          locked: false,
        ),
      ),
    );
  });

  test('devUnverified reaches the hello', () async {
    _answer((call) async => _hello(devUnverified: true));
    final result = await link.hello();
    expect((result as Ok<LinkHello, LinkFailure>).value.devUnverified, isTrue);
  });

  test('a hello with no common version is unsupportedVersion', () async {
    _answer(
      (call) async => {
        'fields': {
          'versions': ['2.0'],
          'app_version': '9.0.0',
          'locked': false,
        },
        'devUnverified': false,
      },
    );
    expect(
      await link.hello(),
      Err<LinkHello, LinkFailure>(
        LinkUnavailable(
          LinkUnavailableReason.unsupportedVersion,
          theirs: const ['2.0'],
          ours: linkVersions,
        ),
      ),
    );
  });

  test('an unavailable reply is its reason', () async {
    for (final reason in LinkUnavailableReason.values) {
      _answer((call) async => {'unavailable': reason.wire});
      expect(await link.hello(), _unavailable(reason), reason: reason.wire);
    }
    _answer((call) async => {'unavailable': 'on_holiday'});
    expect(
      await link.hello(),
      _unavailable(LinkUnavailableReason.unknownError),
    );
  });

  test('an error reply is its §8 failure', () async {
    for (final error in LinkErrorCode.values) {
      _answer((call) async => {'error': error.wire});
      expect(
        await link.hello(),
        Err<LinkHello, LinkFailure>(LinkCallFailed(error)),
        reason: error.wire,
      );
    }
    _answer((call) async => {'error': 'not_authorised'});
    expect(
      await link.hello(),
      _unavailable(LinkUnavailableReason.notAuthorised),
    );
    _answer((call) async => {'error': 'teapot'});
    expect(
      await link.hello(),
      _unavailable(LinkUnavailableReason.unknownError),
    );
  });

  test('a null or unknown-shaped reply is unknownError', () async {
    final replies = <Object?>[
      null,
      'hello',
      42,
      <Object?, Object?>{},
      {'unavailable': 3},
      {'error': true},
      {'fields': 'versions', 'devUnverified': false},
      {
        'fields': {
          'versions': ['1.0'],
          'app_version': '0.1.0',
          'locked': false,
        },
      },
      {
        'fields': {
          'versions': ['1.0'],
          'app_version': '0.1.0',
          'locked': false,
        },
        'devUnverified': 'no',
      },
    ];
    for (final reply in replies) {
      _answer((call) async => reply);
      expect(
        await link.hello(),
        _unavailable(LinkUnavailableReason.unknownError),
        reason: '$reply',
      );
    }
  });

  test('a PlatformException is noAnswer', () async {
    _answer((call) async => throw PlatformException(code: 'boom'));
    expect(await link.hello(), _unavailable(LinkUnavailableReason.noAnswer));
  });

  test('a MissingPluginException is noAnswer', () async {
    _answer(null);
    expect(await link.hello(), _unavailable(LinkUnavailableReason.noAnswer));
    _answer((call) async => throw MissingPluginException());
    expect(await link.hello(), _unavailable(LinkUnavailableReason.noAnswer));
  });

  testWidgets('6 s of silence is noAnswer, never a throw', (tester) async {
    _answer((call) => Completer<Object?>().future);
    Result<LinkHello, LinkFailure>? result;
    unawaited(link.hello().then((r) => result = r));
    await tester.pump(const Duration(seconds: 4));
    expect(result, isNull);
    await tester.pump(const Duration(seconds: 2));
    expect(result, _unavailable(LinkUnavailableReason.noAnswer));
  });
}
