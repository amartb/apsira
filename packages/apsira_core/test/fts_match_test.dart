// From relay test/data/db/query_sql/fts_match_test.dart @ 09b28810
// The text search's MATCH string (07 P1-11, data model §9.1, A-24): user
// text becomes quoted prefix tokens, so FTS5's own syntax (quotes, `*`,
// `-`, `:`, parentheses, `NEAR`, `AND`, `OR`, `NOT`, `^`, `+`) is read as
// words, never as operators, and never raises. Run against the app's own
// `note_fts` table (its tokenizer folds accents).
import 'package:apsira_core/apsira_core.dart';
import 'package:test/test.dart';

import 'support/fts_db.dart';
import 'support/prop/prop.dart';

late RelayDatabase db;

Future<void> _index(Map<int, String> rows) async {
  await db.customStatement('DELETE FROM note_fts');
  for (final MapEntry(key: rowid, value: body) in rows.entries) {
    await db.customStatement(
      'INSERT INTO note_fts (rowid, note_id, title, body, tags, props) '
      "VALUES (?, ?, '', ?, '', '')",
      [rowid, 'n$rowid', body],
    );
  }
}

/// The rowids [text]'s MATCH string finds; none when it has no word.
Future<Set<int>> _search(String text) async {
  final match = ftsMatch(text);
  if (match == null) return {};
  final rows = await db
      .customSelect(
        'SELECT rowid AS r FROM note_fts WHERE note_fts MATCH ?',
        variables: [Variable.withString(match)],
      )
      .get();
  return {for (final r in rows) r.read<int>('r')};
}

/// The terms FTS5's tokenizer made of row [rowid], by `fts5vocab`: the
/// independent view of what the row holds.
Future<List<String>> _terms(int rowid) async {
  final rows = await db
      .customSelect(
        'SELECT term FROM temp.note_terms WHERE doc = ?',
        variables: [Variable.withInt(rowid)],
      )
      .get();
  return [for (final r in rows) r.read<String>('term')];
}

/// FTS5 query syntax and the characters around it.
const _specials = [
  // FTS5 syntax.
  '"', '""', "'", '*', '-', ':', '(', ')', '^', '+', '{', '}', ',', '.', //
  'NEAR', 'NEAR(', 'near', 'AND', 'OR', 'NOT', 'and', 'title:', 'body:', //
  '-x', '"a', 'a"', '*a', '\\', '%', '_', ';', //
  // White space and controls; a NUL ends a C string.
  ' ', '  ', '\t', '\n', '\u00A0', '\u2028', '\u0000', '\u0001', '\u001F', //
  '\u007F', '\uFEFF', '\uFFFF', '\u200D', '\uD800', '\uDC00', //
  // Accents, precomposed and combining, ligatures and dotted capitals.
  'reuni\u00F3n', 'A\u00F1o', 'a\u00F1o', '\u00E9', 'e\u0301', '\u00F1', //
  '\u00DC', '\uFB01', '\u0130', //
  'word', 'x', 'y', '9', '42', '\u{1F642}', //
];

final Gen<String> _userText = Gens.listOf(
  Gens.frequency([
    (3, Gens.elementOf(_specials)),
    (2, TextGens.atom),
    (2, TextGens.word),
  ]),
).map((parts) => parts.join());

void main() {
  setUp(() async {
    db = RelayDatabase(NativeDatabase.memory(setup: applyPragmas));
    await db.customStatement(
      'CREATE VIRTUAL TABLE temp.note_terms '
      'USING fts5vocab(main, note_fts, instance)',
    );
  });
  tearDown(() => db.close());

  group('the MATCH string', () {
    test('each word becomes a quoted prefix token', () {
      expect(ftsMatch('reun'), '"reun"*');
      expect(ftsMatch('  plan   de  viaje '), '"plan"* "de"* "viaje"*');
      expect(ftsMatch('tab\there\nnewline'), '"tab"* "here"* "newline"*');
      expect(ftsMatch('nul\u0000inside'), '"nul"* "inside"*');
    });

    test(
      'a quote inside a word is doubled, so the string never ends early',
      () {
        expect(ftsMatch('say "hi"'), '"say"* """hi"""*');
        expect(ftsMatch('"'), '""""*');
      },
    );

    test('text with no word gives none', () {
      expect(ftsMatch(''), isNull);
      expect(ftsMatch('   \t\n '), isNull);
      expect(ftsMatch('\u0000'), isNull);
    });
  });

  group('literal matching', () {
    setUp(
      () => _index({
        1: 'Reunión con Ana sobre el año fiscal',
        2: 'near the station and the bridge',
        3: 'e-mail from the team: plan (draft)',
        4: 'C++ and Dart',
        5: 'nothing in common',
        6: 'NOT this OR that',
      }),
    );

    test('a prefix finds the word, accents folded both ways', () async {
      expect(await _search('reun'), {1});
      expect(await _search('reunion'), {1});
      expect(await _search('ANO'), {1});
      expect(await _search('año fisc'), {1});
    });

    test('every word must be found', () async {
      expect(await _search('ana fiscal'), {1});
      expect(await _search('ana bridge'), <int>{});
    });

    test('FTS5 operators are words', () async {
      expect(await _search('NEAR'), {2});
      expect(await _search('near station'), {2});
      expect(await _search('NEAR('), {2});
      expect(await _search('AND'), {2, 4});
      expect(await _search('OR'), {6});
      expect(await _search('NOT'), {5, 6}, reason: 'a prefix of nothing');
      expect(await _search('this OR that'), {6});
      expect(await _search('station OR nothing'), <int>{});
      expect(await _search('NOT station'), <int>{});
    });

    test('punctuation and column names are not syntax', () async {
      expect(await _search('e-mail'), {3});
      expect(await _search('-mail'), {3});
      expect(await _search('team:'), {3});
      expect(await _search('body:plan'), <int>{});
      expect(await _search('(draft)'), {3});
      expect(await _search('"plan'), {3});
      expect(await _search('dra*'), {3});
      expect(await _search('^plan'), {3});
      expect(await _search('C++ dart'), {4});
      expect(await _search('+dart'), {4});
    });

    test(
      'a word of punctuation alone finds nothing and raises nothing',
      () async {
        for (final text in ['-', '*', '"', '()', ':', '^', '+']) {
          expect(await _search(text), <int>{}, reason: text);
        }
      },
    );
  });

  test('property: any text never raises inside FTS5, and finds itself '
      'whenever the tokenizer gives it a term', () async {
    await forAll(_userText, (text) async {
      await _index({1: text, 2: 'zzzq unrelated'});
      final found = await _search(text);
      final terms = await _terms(1);
      if (terms.isNotEmpty) {
        expect(found, contains(1), reason: 'its own words');
      } else {
        expect(found, isNot(contains(1)), reason: 'no word to find');
      }
      return true;
    });
  });
}
