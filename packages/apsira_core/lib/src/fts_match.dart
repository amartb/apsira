// From relay lib/data/db/query_sql/fts_match.dart @ 09b28810
/// The MATCH string of a text search (data model §9.1, A-24).
///
/// Each word the user typed (a run of characters between white space)
/// becomes an FTS5 string, quoted with its `"` doubled, and a prefix match:
/// `reun` → `"reun"*`, `plan de` → `"plan"* "de"*`. Inside a string FTS5
/// reads nothing as syntax, so quotes, `*`, `-`, `:`, parentheses, `^`,
/// `+`, `NEAR`, `AND`, `OR` and `NOT` are words to find, never operators,
/// and no text makes FTS5 raise. Every word must be found (FTS5's implicit
/// AND), and the tokenizer folds accents on both sides (DM-7).
///
/// FTS5 splits a word at its punctuation, so `e-mail` is the phrase
/// `e mail*`: its parts in order, the last as a prefix. A word with no
/// letter or digit (`-`, `()`) finds nothing. A NUL separates words, as
/// white space does.
///
/// The string is a value: the compiler binds it as a variable, never as
/// SQL text (07 P1-11).
library;

/// White space, and NUL: FTS5 reads a query as a C string, so a NUL would
/// end it inside a quoted word and raise ("unterminated string").
final _space = RegExp(r'[\s\u0000]+');

/// The MATCH string for [text], or null when it holds no word (only white
/// space and NULs).
String? ftsMatch(String text) {
  final out = StringBuffer();
  for (final word in text.split(_space)) {
    if (word.isEmpty) continue;
    if (out.isNotEmpty) out.write(' ');
    out
      ..write('"')
      ..write(word.replaceAll('"', '""'))
      ..write('"*');
  }
  return out.isEmpty ? null : out.toString();
}
