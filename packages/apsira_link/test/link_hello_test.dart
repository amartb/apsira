import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_link/apsira_link.dart';
import 'package:flutter_test/flutter_test.dart';

Map<Object?, Object?> _fields({
  Object versions = const ['1.0'],
  Object appVersion = '0.1.0',
  Object locked = false,
}) => {'versions': versions, 'app_version': appVersion, 'locked': locked};

void main() {
  test('the contract constants', () {
    expect(linkContract, 'apsira.app_link');
    expect(linkVersions, ['1.0']);
  });

  group('chooseLinkVersion', () {
    test('picks the highest version both sides speak', () {
      expect(chooseLinkVersion(['1.0', '1.1']), '1.0');
      expect(chooseLinkVersion(['1.1', '1.0']), '1.0');
      expect(
        chooseLinkVersion(['1.0', '1.2', '2.0'], ours: ['1.2', '1.10', '1.0']),
        '1.2',
      );
    });

    test('compares numerically, not as text', () {
      expect(chooseLinkVersion(['1.9', '1.10'], ours: ['1.9', '1.10']), '1.10');
    });

    test('ignores malformed versions', () {
      expect(chooseLinkVersion(['x', '1', '1.0.0', ' 1.0', '01.0']), isNull);
      expect(chooseLinkVersion(['x', '1.0']), '1.0');
    });

    test('no common version is null', () {
      expect(chooseLinkVersion(['2.0']), isNull);
      expect(chooseLinkVersion([]), isNull);
    });
  });

  group('LinkHello.fromReply', () {
    test('reads the hello fields with the chosen version', () {
      final result = LinkHello.fromReply(
        _fields(versions: ['1.0', '1.1'], appVersion: '0.2.0', locked: true),
      );
      final hello = (result as Ok<LinkHello, LinkFailure>).value;
      expect(hello.version, '1.0');
      expect(hello.versions, ['1.0', '1.1']);
      expect(hello.appVersion, '0.2.0');
      expect(hello.locked, isTrue);
      expect(hello.devUnverified, isFalse);
    });

    test('carries devUnverified', () {
      final result = LinkHello.fromReply(_fields(), devUnverified: true);
      expect(
        (result as Ok<LinkHello, LinkFailure>).value.devUnverified,
        isTrue,
      );
    });

    test('no common version is unsupportedVersion naming both lists', () {
      for (final theirs in [
        ['2.0'],
        ['x'],
      ]) {
        expect(
          LinkHello.fromReply(_fields(versions: theirs)),
          Err<LinkHello, LinkFailure>(
            LinkUnavailable(
              LinkUnavailableReason.unsupportedVersion,
              theirs: theirs,
              ours: linkVersions,
            ),
          ),
          reason: '$theirs',
        );
      }
    });

    test('a missing or mistyped field is unknownError', () {
      final unknown = Err<LinkHello, LinkFailure>(
        LinkUnavailable(LinkUnavailableReason.unknownError),
      );
      final replies = <Map<Object?, Object?>>[
        {
          'versions': const ['1.0'],
          'locked': false,
        },
        _fields(appVersion: 7),
        {
          'versions': const ['1.0'],
          'app_version': '0.1.0',
        },
        _fields(locked: 'yes'),
        {'app_version': '0.1.0', 'locked': false},
        _fields(versions: '1.0'),
        _fields(versions: [1.0]),
        {},
      ];
      for (final reply in replies) {
        expect(LinkHello.fromReply(reply), unknown, reason: '$reply');
      }
    });

    test('equal hellos are equal', () {
      expect(LinkHello.fromReply(_fields()), LinkHello.fromReply(_fields()));
    });
  });
}
