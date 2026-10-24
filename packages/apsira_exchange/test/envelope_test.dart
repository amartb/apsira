// From lyceum test/domain/export/envelope_test.dart @ 9f4ff27, on the
// shared envelope through LYCEUM's parts (support/apps.dart): written with
// sorted keys and the tables last, so a dump can stream them; read back only
// when the format is the app's, its major version is 1 and its schema is not
// newer than the app's. Then the shared envelope's own rules: extra keys,
// the other apps' formats and the legacy shapes.
import 'dart:convert';

import 'package:apsira_exchange/apsira_exchange.dart';
import 'package:test/test.dart';

import 'support/apps.dart';

Map<String, Object?> _valid() => jsonDecode(
  lyceumEnvelope(
    appVersion: '0.4.0+7',
    producedAt: DateTime.utc(2026, 10, 22, 21, 9, 30, 456),
    schemaVersion: 2,
  ).encode(),
) as Map<String, Object?>;

EnvelopeInfo _read(Object? json, {int current = 2}) => (checkEnvelope(
  json,
  formats: {lyceumFormat},
  currentSchemaVersion: current,
) as EnvelopeOk).envelope;

void main() {
  final envelope = lyceumEnvelope(
    appVersion: '0.4.0+7',
    producedAt: DateTime.utc(2026, 10, 22, 21, 9, 30, 456),
    schemaVersion: 2,
  );

  test('the envelope is sorted, the tables last, produced_at UTC to the '
      'second', () {
    expect(
      envelope.encode(
        tables: {
          'works': [
            {'title': 'Uno', 'id': 'w1'},
          ],
          'captures': <Object?>[],
        },
      ),
      '{"app_version":"0.4.0+7","format":"lyceum-export",'
      '"format_version":"1.0","produced_at":"2026-10-22T21:09:30Z",'
      '"producer":{"app":"lyceum","app_version":"0.4.0+7"},'
      '"schema_version":2,'
      '"tables":{"captures":[],"works":[{"id":"w1","title":"Uno"}]}}\n',
    );
    expect(envelope.toJson().keys.toList()..sort(), [
      'app_version',
      'format',
      'format_version',
      'produced_at',
      'producer',
      'schema_version',
    ]);
  });

  test('head + tables + tail is the whole document, for a streaming dump', () {
    final out = StringBuffer();
    envelope.writeHead(out);
    out
      ..write('{}')
      ..write(ExportEnvelope.tail);
    expect(out.toString(), envelope.encode());
  });

  test('a local producedAt is written as its UTC instant', () {
    final local = DateTime.utc(2026, 1, 2, 3, 4, 5).toLocal();
    final e = lyceumEnvelope(
      appVersion: 'x',
      producedAt: local,
      schemaVersion: 1,
    );
    expect(e.toJson()['produced_at'], '2026-01-02T03:04:05Z');
  });

  test('a valid envelope is read back', () {
    final info = _read(_valid());
    expect(info.extra['app_version'], '0.4.0+7');
    expect(info.format, lyceumFormat);
    expect(info.formatVersion, '1.0');
    expect(info.producedAt, DateTime.utc(2026, 10, 22, 21, 9, 30));
    expect(info.producer, const Producer('lyceum', '0.4.0+7'));
    expect(info.schemaVersion, 2);
    expect(lyceumRefusal(_valid()), isNull);
  });

  test('an older schema, a later 1.x and unknown keys are accepted', () {
    final json = _valid()
      ..['format_version'] = '1.4'
      ..['added_in_1_4'] = true
      ..['produced_at'] = '2026-10-22T21:09:30.123456Z';
    final info = _read(json, current: 3);
    expect(info.formatVersion, '1.4');
    expect(info.schemaVersion, 2);
    expect(info.producedAt, DateTime.utc(2026, 10, 22, 21, 9, 30, 123, 456));
    expect(info.extra['added_in_1_4'], isTrue);
    // The tables may be left to a streaming reader.
    expect(lyceumRefusal(_valid()..remove('tables')), isNull);
  });

  test('a newer schema_version is refused, naming both versions', () {
    final read = checkEnvelope(
      _valid()..['schema_version'] = 3,
      formats: {lyceumFormat},
      currentSchemaVersion: 2,
    );
    expect(read, isA<SchemaTooNew>());
    expect((read as SchemaTooNew).found, 3);
    expect(read.supported, 2);
    expect(read.toString(), contains('3'));
    expect(lyceumRefusal(_valid()..['schema_version'] = 3), importSchemaTooNew);
  });

  test('format 2.0 is refused, naming the version found', () {
    for (final version in ['2.0', 'one', '0.9', '1', '1.01']) {
      final read = checkEnvelope(
        _valid()..['format_version'] = version,
        formats: {lyceumFormat},
        currentSchemaVersion: 2,
      );
      expect(read, isA<FormatUnsupported>(), reason: version);
      expect((read as FormatUnsupported).found, version);
    }
    expect(
      lyceumRefusal(_valid()..['format_version'] = '2.0'),
      importFormatUnsupported,
    );
  });

  test('anything that is not LYCEUM\'s envelope is not a bundle', () {
    for (final json in <Object?>[
      null,
      'lyceum',
      [1],
      _valid()..['format'] = 'relay-export',
      _valid()..remove('format'),
      _valid()..['format_version'] = 1.0,
      _valid()..remove('schema_version'),
      _valid()..['schema_version'] = '2',
      _valid()..['schema_version'] = 0,
      _valid()..['app_version'] = '',
      _valid()..['app_version'] = 7,
      _valid()..['produced_at'] = '2026-10-22T21:09:30',
      _valid()..['produced_at'] = '2026-02-30T21:09:30Z',
      _valid()..['produced_at'] = 1792319400,
      _valid()..['producer'] = 'lyceum',
      _valid()..['producer'] = {'app': 'lyceum'},
      _valid()..['producer'] = {'app': '', 'app_version': '1'},
      _valid()..['tables'] = [],
      _valid()..['tables'] = {'works': <String, Object?>{}},
      _valid()
        ..['tables'] = {
          'works': [1],
        },
    ]) {
      expect(lyceumRefusal(json), importNotABundle, reason: '$json');
    }
  });

  group('the shared envelope', () {
    test('extra keys: the envelope\'s own and any after "tables" are '
        'refused', () {
      for (final key in [...envelopeKeys, 'version', 'zone']) {
        expect(
          () => ExportEnvelope(
            format: 'f',
            producedAt: DateTime.utc(2026),
            producer: const Producer('a', '1'),
            schemaVersion: 1,
            extra: {key: 1},
          ),
          throwsArgumentError,
          reason: key,
        );
      }
    });

    test('VIATICUM\'s results after adoption: artifact_id kept, '
        'schema_version read', () {
      final doc = ExportEnvelope(
        format: 'viaticum.results',
        producedAt: DateTime.utc(2026, 11, 12, 18, 20),
        producer: const Producer('viaticum', '1.0.3'),
        schemaVersion: 1,
        extra: {'artifact_id': '9d4c7e12-6a3b-4c58-8e21-000000000005'},
      ).encode();
      final read = checkEnvelope(
        jsonDecode(doc),
        formats: {'viaticum.results'},
        currentSchemaVersion: 1,
        legacy: const [LegacyShape.viaticumExchangeV1],
      );
      expect(read, isA<EnvelopeOk>());
      final ok = read as EnvelopeOk;
      expect(ok.readAs, isNull);
      expect(ok.envelope.schemaVersion, 1);
      expect(ok.envelope.extra.keys, ['artifact_id']);
    });

    test('a legacy shape is read only when the app passes it', () {
      final viaticum = _valid()
        ..remove('schema_version')
        ..['format'] = 'viaticum.seed';
      expect(
        checkEnvelope(
          viaticum,
          formats: {'viaticum.seed'},
          currentSchemaVersion: 1,
        ),
        isA<NotABundle>(),
      );
      final relay = {
        'appVersion': '1.0.0',
        'format': 'relay-export',
        'schemaVersion': 9,
        'tables': <String, Object?>{},
        'version': 1,
      };
      expect(
        checkEnvelope(
          relay,
          formats: {'relay-export'},
          currentSchemaVersion: 12,
        ),
        isA<NotABundle>(),
      );
      final read = checkEnvelope(
        relay,
        formats: {'relay-export'},
        currentSchemaVersion: 12,
        legacy: const [LegacyShape.relayExportV1],
      );
      expect((read as EnvelopeOk).readAs, LegacyShape.relayExportV1);
      expect(read.envelope.producedAt, isNull);
      expect(read.envelope.formatVersion, '1');
      for (final broken in [
        {...relay, 'appVersion': 1},
        {...relay, 'schemaVersion': '9'},
        {...relay, 'schemaVersion': 0},
        {...relay, 'version': '1'},
        {...relay, 'tables': <Object?>[]},
      ]) {
        expect(
          checkEnvelope(
            broken,
            formats: {'relay-export'},
            currentSchemaVersion: 12,
            legacy: const [LegacyShape.relayExportV1],
          ),
          isA<NotABundle>(),
          reason: '$broken',
        );
      }
    });

    test('checkEnvelopeUtf8: a byte-order mark, bad UTF-8 and cut JSON are '
        'not a bundle', () {
      final bytes = utf8.encode(envelope.encode());
      EnvelopeCheck read(List<int> b) => checkEnvelopeUtf8(
        b,
        formats: {lyceumFormat},
        currentSchemaVersion: 2,
      );
      expect(read(bytes), isA<EnvelopeOk>());
      expect(
        (read([0xEF, 0xBB, 0xBF, ...bytes]) as NotABundle).reason,
        'byteOrderMark',
      );
      expect(
        (read([...bytes.take(10), 0xFF, 0xFE]) as NotABundle).reason,
        'notJson',
      );
      expect(read(const []), isA<NotABundle>());
    });

    test('formatMajor and isReadableFormatVersion', () {
      expect(formatMajor('1.0'), 1);
      expect(formatMajor('12.3'), 12);
      expect(formatMajor('01.0'), isNull);
      expect(formatMajor('1'), isNull);
      expect(isReadableFormatVersion('1.17'), isTrue);
      expect(isReadableFormatVersion('2.0'), isFalse);
    });
  });
}
