import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_link/apsira_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LinkUnavailableReason', () {
    test('carries the wire names of the contract and the client', () {
      expect(LinkUnavailableReason.values.map((r) => r.wire), [
        'not_installed',
        'not_trusted',
        'not_authorised',
        'unsupported_version',
        'no_answer',
        'unknown_error',
      ]);
    });

    test('every reason round-trips through its wire name', () {
      for (final reason in LinkUnavailableReason.values) {
        expect(LinkUnavailableReason.fromWire(reason.wire), reason);
      }
    });

    test('an unknown wire name is unknownError', () {
      expect(
        LinkUnavailableReason.fromWire('gone_fishing'),
        LinkUnavailableReason.unknownError,
      );
    });
  });

  group('LinkErrorCode', () {
    test('carries the six call errors of contract §8', () {
      expect(LinkErrorCode.values.map((c) => c.wire), [
        'busy',
        'away',
        'storage_full',
        'not_found',
        'not_allowed',
        'checksum_mismatch',
      ]);
    });
  });

  group('linkFailureFromWire', () {
    test('not_authorised and unsupported_version are unavailable', () {
      expect(
        linkFailureFromWire('not_authorised'),
        LinkUnavailable(LinkUnavailableReason.notAuthorised),
      );
      expect(
        linkFailureFromWire('unsupported_version'),
        LinkUnavailable(LinkUnavailableReason.unsupportedVersion),
      );
    });

    test('every call error of §8 round-trips', () {
      for (final error in LinkErrorCode.values) {
        final failure = linkFailureFromWire(error.wire);
        expect(failure, LinkCallFailed(error));
        expect(failure.wire, error.wire);
      }
    });

    test('an unknown code is unavailable with unknownError', () {
      for (final code in ['', 'BUSY', 'not_installed', 'teapot']) {
        expect(
          linkFailureFromWire(code),
          LinkUnavailable(LinkUnavailableReason.unknownError),
          reason: code,
        );
      }
    });
  });

  group('codes', () {
    test('every failure code is a valid Failure code', () {
      final failures = <LinkFailure>[
        for (final r in LinkUnavailableReason.values) LinkUnavailable(r),
        for (final e in LinkErrorCode.values) LinkCallFailed(e),
      ];
      for (final failure in failures) {
        expect(failure, isA<Failure>());
        expect(Failure.isValidCode(failure.code), isTrue, reason: failure.code);
      }
      expect(failures.map((f) => f.code).toSet(), hasLength(failures.length));
    });

    test('the codes are the link-prefixed reason and error names', () {
      expect(
        LinkUnavailable(LinkUnavailableReason.notInstalled).code,
        'linkNotInstalled',
      );
      expect(
        LinkUnavailable(LinkUnavailableReason.unknownError).code,
        'linkUnknownError',
      );
      expect(
        LinkCallFailed(LinkErrorCode.checksumMismatch).code,
        'linkChecksumMismatch',
      );
    });
  });

  group('LinkUnavailable', () {
    test('unsupportedVersion names both version lists', () {
      final failure = LinkUnavailable(
        LinkUnavailableReason.unsupportedVersion,
        theirs: const ['2.0'],
        ours: const ['1.0'],
      );
      expect(failure.theirs, ['2.0']);
      expect(failure.ours, ['1.0']);
      expect(failure.toString(), contains('2.0'));
      expect(failure.toString(), contains('1.0'));
    });

    test('equality includes the version lists', () {
      expect(
        LinkUnavailable(
          LinkUnavailableReason.unsupportedVersion,
          theirs: const ['2.0'],
          ours: const ['1.0'],
        ),
        LinkUnavailable(
          LinkUnavailableReason.unsupportedVersion,
          theirs: const ['2.0'],
          ours: const ['1.0'],
        ),
      );
      expect(
        LinkUnavailable(
          LinkUnavailableReason.unsupportedVersion,
          theirs: const ['2.0'],
        ),
        isNot(LinkUnavailable(LinkUnavailableReason.unsupportedVersion)),
      );
      expect(
        LinkUnavailable(LinkUnavailableReason.notInstalled).hashCode,
        LinkUnavailable(LinkUnavailableReason.notInstalled).hashCode,
      );
    });

    test('an unavailable failure is never a call failure', () {
      expect(
        LinkUnavailable(LinkUnavailableReason.notAuthorised),
        isNot(LinkCallFailed(LinkErrorCode.busy)),
      );
    });
  });
}
