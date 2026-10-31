import 'dart:async';
import 'dart:typed_data';

import 'package:apsira_link/apsira_link.dart';
import 'package:apsira_link/archive.dart';
import 'package:apsira_link/testing/fake_archive_link.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';

// FakeApsiraArchiveLink (K2-02c): an in-memory archive that keeps
// atrium-offload.md's rules — stored, then secured only by a snapshot
// (`secure`), `away` for the calls that move bytes, `store_full`, the
// checksum on put, `not_found` on fetch.
Uint8List _bytes(int length) =>
    Uint8List.fromList(List.generate(length, (i) => i & 0xff));

LinkArchiveItem _item(List<int> bytes, {String id = 'doc-1', String? sha}) =>
    LinkArchiveItem(
      itemId: id,
      displayName: 'Lease.pdf',
      mimeType: 'application/pdf',
      size: bytes.length,
      sha256: sha ?? crypto.sha256.convert(bytes).toString(),
      keptUtc: DateTime.utc(2026, 10, 31),
    );

void main() {
  test('put stores, secure secures, fetch gives the bytes back', () async {
    final archive = FakeApsiraArchiveLink();
    final bytes = _bytes(300);
    final item = _item(bytes);

    expect(
      (await archive.archiveState('doc-1')).valueOrNull,
      LinkArchiveState.absent,
    );
    expect(
      (await archive.archivePut(item, Stream.value(bytes))).valueOrNull,
      LinkArchiveState.stored,
    );
    archive.secure('doc-1');
    expect(
      (await archive.archiveState('doc-1')).valueOrNull,
      LinkArchiveState.secured,
    );

    final fetch = (await archive.archiveFetch('doc-1')).valueOrNull!;
    expect(fetch.size, 300);
    expect(fetch.sha256, item.sha256);
    expect(await fetch.bytes.expand((b) => b).toList(), bytes);

    expect((await archive.archiveList()).valueOrNull, [
      LinkArchiveEntry(item: item, state: LinkArchiveState.secured),
    ]);
    expect(archive.calls, [
      'archive_state',
      'archive_put',
      'archive_state',
      'archive_fetch',
      'archive_list',
    ]);
  });

  test('a put whose bytes do not match the item stores nothing', () async {
    final archive = FakeApsiraArchiveLink();
    final bytes = _bytes(10);
    final result = await archive.archivePut(
      _item(bytes, sha: 'ab' * 32),
      Stream.value(bytes),
    );
    expect(
      result.failureOrNull,
      LinkCallFailed(LinkErrorCode.checksumMismatch),
    );
    expect(
      (await archive.archiveState('doc-1')).valueOrNull,
      LinkArchiveState.absent,
    );
  });

  test('away refuses put and fetch, before the stream is read', () async {
    final archive = FakeApsiraArchiveLink();
    final bytes = _bytes(4);
    await archive.archivePut(_item(bytes), Stream.value(bytes));
    archive.away = true;

    var listened = false;
    final source = StreamController<List<int>>(onListen: () => listened = true);
    expect(
      (await archive.archivePut(
        _item(bytes, id: 'doc-2'),
        source.stream,
      )).failureOrNull,
      LinkCallFailed(LinkErrorCode.away),
    );
    expect(listened, isFalse);
    unawaited(source.close());
    expect(
      (await archive.archiveFetch('doc-1')).failureOrNull,
      LinkCallFailed(LinkErrorCode.away),
    );
  });

  test('storeFull refuses put with store_full', () async {
    final archive = FakeApsiraArchiveLink()..storeFull = true;
    final bytes = _bytes(4);
    expect(
      (await archive.archivePut(
        _item(bytes),
        Stream.value(bytes),
      )).failureOrNull,
      LinkCallFailed(LinkErrorCode.storeFull),
    );
  });

  test('fetch of an item the archive does not hold is not_found', () async {
    expect(
      (await FakeApsiraArchiveLink().archiveFetch('nope')).failureOrNull,
      LinkCallFailed(LinkErrorCode.notFound),
    );
  });

  test('release removes the item; its state is then absent', () async {
    final archive = FakeApsiraArchiveLink();
    final bytes = _bytes(4);
    await archive.archivePut(_item(bytes), Stream.value(bytes));
    expect((await archive.archiveRelease('doc-1')).isOk, isTrue);
    expect(
      (await archive.archiveState('doc-1')).valueOrNull,
      LinkArchiveState.absent,
    );
  });

  test('list since keeps the items kept at or after it', () async {
    final archive = FakeApsiraArchiveLink();
    final bytes = _bytes(4);
    await archive.archivePut(_item(bytes), Stream.value(bytes));
    expect(
      (await archive.archiveList(since: DateTime.utc(2026, 11))).valueOrNull,
      isEmpty,
    );
    expect(
      (await archive.archiveList(since: DateTime.utc(2026, 10, 31)))
          .valueOrNull,
      hasLength(1),
    );
  });

  test('unavailable fails every call', () async {
    final archive = FakeApsiraArchiveLink()
      ..unavailable = LinkUnavailableReason.notInstalled;
    final failure = LinkUnavailable(LinkUnavailableReason.notInstalled);
    final bytes = _bytes(4);
    expect(
      (await archive.archivePut(
        _item(bytes),
        Stream.value(bytes),
      )).failureOrNull,
      failure,
    );
    expect((await archive.archiveState('doc-1')).failureOrNull, failure);
    expect((await archive.archiveList()).failureOrNull, failure);
    expect((await archive.archiveFetch('doc-1')).failureOrNull, failure);
    expect((await archive.archiveRelease('doc-1')).failureOrNull, failure);
  });

  test('secure of an item it does not hold is a StateError', () {
    expect(() => FakeApsiraArchiveLink().secure('nope'), throwsStateError);
  });
}
