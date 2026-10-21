// From relay lib/core/ports/id_gen.dart @ 5f606e9
/// The only source of identifiers (architecture §3.1; CLAUDE.md §1.5).
abstract interface class IdGen {
  /// A new UUIDv7 in lowercase canonical form (D-014): time-ordered, so
  /// identifiers made later sort later.
  String uuid();
}
