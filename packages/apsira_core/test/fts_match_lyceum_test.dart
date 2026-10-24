// From lyceum test/domain/search/fts_query_test.dart @ 9f4ff27: LYCEUM's
// cases of its port of RELAY's rule, against apsira_core's ftsMatch (RELAY's
// rule unchanged, ruling R-2). The cases that hold are LYCEUM's as written;
// the ones where LYCEUM dropped a word with no letter or digit are restated
// to RELAY's output, each marked D-APK-011.
import 'package:apsira_core/apsira_core.dart';
import 'package:test/test.dart';

import 'support/fts_db.dart';

void main() {
  group('ftsMatch', () {
    test('each word is a quoted prefix; every word must match', () {
      expect(ftsMatch('reun'), '"reun"*');
      expect(ftsMatch('  plan   de '), '"plan"* "de"*');
    });

    test('a quote is doubled inside its string', () {
      expect(ftsMatch('say"hi'), '"say""hi"*');
      expect(ftsMatch('"quoted"'), '"""quoted"""*');
    });

    test('operators are words to find, never syntax', () {
      expect(ftsMatch('NEAR(a b)'), '"NEAR(a"* "b)"*');
      expect(ftsMatch('a OR b NOT c'), '"a"* "OR"* "b"* "NOT"* "c"*');
      expect(ftsMatch('col:val'), '"col:val"*');
      expect(ftsMatch('^start +x'), '"^start"* "+x"*');
    });

    test('a star or a minus inside a word stays in its string', () {
      expect(ftsMatch('wh*t'), '"wh*t"*');
      expect(ftsMatch('e-mail'), '"e-mail"*');
      expect(ftsMatch('-excluded'), '"-excluded"*');
    });

    test(
      'a word with no letter or digit stays a phrase that finds nothing',
      () {
        // D-APK-011: RELAY's rule; neutral for LYCEUM's caller (null and a
        // never-matching phrase both give []). LYCEUM: '"rose"*'.
        expect(ftsMatch('- rose'), '"-"* "rose"*');
        // D-APK-011: RELAY's rule; neutral for LYCEUM's caller (null and a
        // never-matching phrase both give []). LYCEUM: '"rose"*'.
        expect(ftsMatch('rose * ()'), '"rose"* "*"* "()"*');
      },
    );

    test('NUL separates words like white space', () {
      expect(ftsMatch('ab\u0000cd'), '"ab"* "cd"*');
    });

    test('accents and digits are letters and digits', () {
      expect(ftsMatch('año 1936'), '"año"* "1936"*');
    });

    test('no word is null; a word with no letter or digit is a phrase', () {
      expect(ftsMatch(''), isNull);
      expect(ftsMatch('   \t\n'), isNull);
      expect(ftsMatch('\u0000'), isNull);
      // D-APK-011: RELAY's rule; neutral for LYCEUM's caller (null and a
      // never-matching phrase both give []). LYCEUM: null.
      expect(ftsMatch('- * "" ()'), '"-"* "*"* """"""* "()"*');
      expect(ftsMatch('NEAR'), '"NEAR"*');
    });
  });

  group('the restated cases, in FTS5 (R-2)', () {
    late RelayDatabase db;

    setUp(() async {
      db = RelayDatabase(NativeDatabase.memory(setup: applyPragmas));
      await db.customStatement(
        'INSERT INTO note_fts (rowid, note_id, title, body, tags, props) '
        "VALUES (1, 'n1', '', 'plan rose', '', '')",
      );
    });
    tearDown(() => db.close());

    Future<int> count(String text) async =>
        (await db
                .customSelect(
                  'SELECT rowid AS r FROM note_fts WHERE note_fts MATCH ?',
                  variables: [Variable.withString(ftsMatch(text)!)],
                )
                .get())
            .length;

    test('a token-less word alone matches nothing', () async {
      for (final text in ['-', '*', '()', '- * "" ()']) {
        expect(await count(text), 0, reason: text);
      }
    });

    test('a mixed query still finds its words', () async {
      expect(await count('plan -'), 1);
      expect(await count('- rose'), 1);
      expect(await count('rose * ()'), 1);
    });
  });
}
