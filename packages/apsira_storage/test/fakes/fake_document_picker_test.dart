// FakeDocumentPicker: relay test/fakes/fake_document_picker.dart @ 09b28810
// (pickOne over `next`, its caps recorded) and viaticum
// test/fakes/fake_document_picker.dart @ 78d38e0 (pick and readAll over
// offered files or bytes, the MIME types recorded), in one fake.
import 'dart:io';
import 'dart:typed_data';

import 'package:apsira_storage/apsira_storage.dart';
import 'package:apsira_storage/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pickOne (RELAY)', () {
    test('is a cancel with nothing next, and records the cap', () async {
      final picker = FakeDocumentPicker();
      expect((await picker.pickOne(maxBytes: 10)).valueOrNull, isNull);
      expect(picker.caps, [10]);
    });

    test('returns next within the cap, documentTooLarge over it', () async {
      final doc = PickedDocument(name: 'p.json', bytes: Uint8List(5));
      final picker = FakeDocumentPicker(next: doc);
      expect((await picker.pickOne(maxBytes: 5)).valueOrNull, doc);
      expect(
        (await picker.pickOne(maxBytes: 4)).failureOrNull?.code,
        DocumentPicker.documentTooLarge,
      );
      expect(picker.caps, [5, 4]);
    });
  });

  group('pick and readAll (VIATICUM)', () {
    test('a pick with nothing offered is a cancel; the types are '
        'recorded', () async {
      final picker = FakeDocumentPicker();
      expect(
        (await picker.pick(mimeTypes: ['application/json'])).valueOrNull,
        isNull,
      );
      expect(picker.requestedMimeTypes, [
        ['application/json'],
      ]);
    });

    test(
      'offered bytes are picked in order and read under the limit',
      () async {
        final picker = FakeDocumentPicker()
          ..offerBytes('a.json', [1, 2, 3])
          ..offerBytes('b.json', [4]);
        final a = (await picker.pick()).valueOrNull!;
        final b = (await picker.pick()).valueOrNull!;
        expect((a.name, a.sizeBytes, b.name), ('a.json', 3, 'b.json'));
        expect((await picker.readAll(a, maxBytes: 3)).valueOrNull, [1, 2, 3]);
        expect(
          (await picker.readAll(a, maxBytes: 2)).failureOrNull,
          DocumentPicker.tooLarge,
        );
      },
    );

    test('an offered file is read from disk; a gone one is '
        'documentUnreadable', () async {
      final dir = Directory.systemTemp.createTempSync('fake_picker');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/seed.json')..writeAsBytesSync([7, 8]);
      final picker = FakeDocumentPicker()..offerFile(file);
      final ref = (await picker.pick()).valueOrNull!;
      expect(ref.name, 'seed.json');
      expect((await picker.readAll(ref, maxBytes: 2)).valueOrNull, [7, 8]);
      expect(
        (await picker.readAll(ref, maxBytes: 1)).failureOrNull,
        DocumentPicker.tooLarge,
      );
      file.deleteSync();
      expect(
        (await picker.readAll(ref, maxBytes: 2)).failureOrNull,
        DocumentPicker.documentUnreadable,
      );
    });
  });
}
