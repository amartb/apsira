import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_link/apsira_link.dart';
import 'package:apsira_link/archive.dart';
import 'package:flutter_test/flutter_test.dart';

// The archive calls' value types (atrium-offload.md §3, §4; K2-02c): the
// wire names, the extras an item sends, the replies parsed, and content
// (display_name, mime_type) kept out of every toString.
const _sha = 'ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12';
const _name = 'Passport scan of Ana.pdf';
const _mime = 'application/x-secret-mime';

LinkArchiveItem _item({String id = 'doc-1', int size = 12}) => LinkArchiveItem(
  itemId: id,
  displayName: _name,
  mimeType: _mime,
  size: size,
  sha256: _sha,
  keptUtc: DateTime.utc(2026, 10, 31, 9, 30),
);

Map<Object?, Object?> _wireEntry({
  Object? id = 'doc-1',
  Object? name = _name,
  Object? mime = _mime,
  Object? size = 12,
  Object? sha = _sha,
  Object? kept = '2026-10-31T09:30:00.000Z',
  Object? state = 'stored',
}) => {
  'item_id': id,
  'display_name': name,
  'mime_type': mime,
  'size': size,
  'sha256': sha,
  'kept_utc': kept,
  'state': state,
};

void main() {
  test('the five methods by their AO §3 names', () {
    expect(LinkArchiveMethod.values.map((m) => m.wire), [
      'archive_put',
      'archive_state',
      'archive_list',
      'archive_fetch',
      'archive_release',
    ]);
  });

  group('LinkArchiveState', () {
    test('stored, secured and absent by wire name', () {
      expect(LinkArchiveState.values.map((s) => s.wire), [
        'stored',
        'secured',
        'absent',
      ]);
      expect(LinkArchiveState.fromWire('secured'), LinkArchiveState.secured);
      expect(LinkArchiveState.fromWire('lost'), isNull);
    });

    test('a reply with a known state is that state', () {
      expect(
        LinkArchiveState.fromReply({'state': 'stored'}),
        const Ok<LinkArchiveState, LinkFailure>(LinkArchiveState.stored),
      );
    });

    test('a missing, unknown or mistyped state is unknownError', () {
      for (final fields in <Map<Object?, Object?>>[
        {},
        {'state': 'lost'},
        {'state': 1},
      ]) {
        expect(
          LinkArchiveState.fromReply(fields),
          Err<LinkArchiveState, LinkFailure>(
            LinkUnavailable(LinkUnavailableReason.unknownError),
          ),
          reason: '$fields',
        );
      }
    });
  });

  group('LinkArchiveItem', () {
    test('sends exactly AO §3 archive_put extras, kept_utc in UTC', () {
      final item = LinkArchiveItem(
        itemId: 'doc-1',
        displayName: _name,
        mimeType: _mime,
        size: 12,
        sha256: _sha,
        keptUtc: DateTime.utc(2026, 10, 31, 9, 30).toLocal(),
      );
      expect(item.extras, {
        'item_id': 'doc-1',
        'display_name': _name,
        'mime_type': _mime,
        'size': 12,
        'sha256': _sha,
        'kept_utc': '2026-10-31T09:30:00.000Z',
      });
    });

    test('equal by every field', () {
      expect(_item(), _item());
      expect(_item().hashCode, _item().hashCode);
      expect(_item(id: 'doc-2'), isNot(_item()));
    });

    test('toString never holds display_name or mime_type', () {
      final text = _item().toString();
      expect(text, contains('doc-1'));
      expect(text, isNot(contains(_name)));
      expect(text, isNot(contains(_mime)));
    });
  });

  group('LinkArchiveEntry.listFromReply', () {
    test('parses items with their metadata and state', () {
      final list = LinkArchiveEntry.listFromReply({
        'items': [
          _wireEntry(),
          _wireEntry(id: 'doc-2', state: 'secured', sha: _sha.toUpperCase()),
        ],
      });
      expect(list.valueOrNull, [
        LinkArchiveEntry(item: _item(), state: LinkArchiveState.stored),
        LinkArchiveEntry(
          item: _item(id: 'doc-2'),
          state: LinkArchiveState.secured,
        ),
      ]);
    });

    test('drops an item with a malformed field', () {
      final list = LinkArchiveEntry.listFromReply({
        'items': [
          'not a map',
          _wireEntry(id: ''),
          _wireEntry(id: 3),
          _wireEntry(name: null),
          _wireEntry(mime: 5),
          _wireEntry(size: -1),
          _wireEntry(size: '12'),
          _wireEntry(sha: 'abc'),
          _wireEntry(kept: '2026-10-31T09:30:00+01:00'),
          _wireEntry(kept: 'yesterday'),
          _wireEntry(state: 'lost'),
          _wireEntry(id: 'kept'),
        ],
      });
      expect(list.valueOrNull?.map((e) => e.item.itemId), ['kept']);
    });

    test('items that are not a list is unknownError', () {
      expect(
        LinkArchiveEntry.listFromReply({'items': 'none'}).failureOrNull,
        LinkUnavailable(LinkUnavailableReason.unknownError),
      );
      expect(
        LinkArchiveEntry.listFromReply({}).failureOrNull,
        LinkUnavailable(LinkUnavailableReason.unknownError),
      );
    });

    test('toString never holds display_name or mime_type', () {
      final text = LinkArchiveEntry(
        item: _item(),
        state: LinkArchiveState.secured,
      ).toString();
      expect(text, contains('secured'));
      expect(text, isNot(contains(_name)));
      expect(text, isNot(contains(_mime)));
    });
  });

  test('LinkArchiveFetch prints only its size', () {
    final fetch = LinkArchiveFetch(
      bytes: const Stream.empty(),
      sha256: _sha,
      size: 12,
    );
    expect(fetch.toString(), 'LinkArchiveFetch(12 bytes)');
  });

  test('AO §4 errors are their LinkFailures', () {
    expect(linkFailureFromWire('away'), LinkCallFailed(LinkErrorCode.away));
    expect(
      linkFailureFromWire('store_full'),
      LinkCallFailed(LinkErrorCode.storeFull),
    );
    expect(
      linkFailureFromWire('not_found'),
      LinkCallFailed(LinkErrorCode.notFound),
    );
    expect(
      linkFailureFromWire('checksum_mismatch'),
      LinkCallFailed(LinkErrorCode.checksumMismatch),
    );
  });
}
