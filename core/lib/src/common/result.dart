/// Outcome of an operation that can fail in an expected way.
///
/// Expected failures (file missing, file changed, no access) are values.
/// Exceptions are reserved for bugs.
sealed class Result<T, E> {
  const Result();

  /// This result with [convert] applied to its value; an error stays as it
  /// is.
  Result<U, E> map<U>(U Function(T value) convert) => switch (this) {
    Ok(:final value) => Ok(convert(value)),
    Err(:final error) => Err(error),
  };
}

final class Ok<T, E> extends Result<T, E> {
  const Ok(this.value);

  final T value;
}

final class Err<T, E> extends Result<T, E> {
  const Err(this.error);

  final E error;
}
