// From relay lib/core/result.dart @ 5f606e9
/// Expected failures as values (architecture §9.1).
///
/// Services return `Result<T, Failure>` for outcomes that are part of normal
/// behaviour — a validation error, a name conflict, a denied permission, a
/// backup folder that is gone, a full disk — and never throw them. Bugs are
/// thrown and caught at the service boundary instead.
library;

/// An expected failure, identified by a stable [code].
///
/// The code keys the failure's localised message, in English and Spanish
/// (architecture §9.2, D-030), so it never changes once released. The
/// optional [nextStep] is the code of the action the message offers, for
/// example `backupFolderUnavailable` → `chooseBackupFolder`.
///
/// A failure carries codes only, never user text or note content, so it is
/// always safe to log (D-050).
class Failure {
  const Failure(this.code, {this.nextStep});

  /// The stable message key: a lowerCamel identifier.
  final String code;

  /// The code of the suggested next step, if there is one.
  final String? nextStep;

  static final _codeShape = RegExp(r'^[a-z][a-zA-Z0-9]*$');

  /// Whether [code] has the shape of a message key (lowerCamel, no spaces).
  static bool isValidCode(String code) => _codeShape.hasMatch(code);

  @override
  bool operator ==(Object other) =>
      other is Failure &&
      other.runtimeType == runtimeType &&
      other.code == code &&
      other.nextStep == nextStep;

  @override
  int get hashCode => Object.hash(runtimeType, code, nextStep);

  @override
  String toString() =>
      nextStep == null ? 'Failure($code)' : 'Failure($code → $nextStep)';
}

/// Either a value ([Ok]) or an expected [Failure] ([Err]).
///
/// Sealed, so a `switch` over `Ok` and `Err` is exhaustive.
sealed class Result<T, F extends Failure> {
  const Result();

  const factory Result.ok(T value) = Ok<T, F>;

  const factory Result.err(F failure) = Err<T, F>;

  bool get isOk => this is Ok<T, F>;

  bool get isErr => !isOk;

  /// The value, or `null` for an [Err].
  T? get valueOrNull => switch (this) {
    Ok(:final value) => value,
    Err() => null,
  };

  /// The failure, or `null` for an [Ok].
  F? get failureOrNull => switch (this) {
    Ok() => null,
    Err(:final failure) => failure,
  };

  R fold<R>(R Function(T value) onOk, R Function(F failure) onErr) =>
      switch (this) {
        Ok(:final value) => onOk(value),
        Err(:final failure) => onErr(failure),
      };

  T getOrElse(T Function(F failure) orElse) => switch (this) {
    Ok(:final value) => value,
    Err(:final failure) => orElse(failure),
  };

  Result<U, F> map<U>(U Function(T value) transform) => switch (this) {
    Ok(:final value) => Ok(transform(value)),
    Err(:final failure) => Err(failure),
  };

  /// Chains a step that can fail; an [Err] short-circuits.
  Result<U, F> andThen<U>(Result<U, F> Function(T value) next) =>
      switch (this) {
        Ok(:final value) => next(value),
        Err(:final failure) => Err(failure),
      };

  Result<T, G> mapFailure<G extends Failure>(G Function(F failure) transform) =>
      switch (this) {
        Ok(:final value) => Ok(value),
        Err(:final failure) => Err(transform(failure)),
      };
}

final class Ok<T, F extends Failure> extends Result<T, F> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T, F> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok, value);

  /// Prints the value's type only: the value may be note content (D-050).
  @override
  String toString() => 'Ok($T)';
}

final class Err<T, F extends Failure> extends Result<T, F> {
  const Err(this.failure);

  final F failure;

  @override
  bool operator ==(Object other) =>
      other is Err<T, F> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err, failure);

  @override
  String toString() => 'Err($failure)';
}
