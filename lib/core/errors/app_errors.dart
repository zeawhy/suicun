// lib/core/errors/app_errors.dart

sealed class AppError implements Exception {
  const AppError(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => cause != null
      ? '$runtimeType: $message (caused by: $cause)'
      : '$runtimeType: $message';
}

final class DatabaseError extends AppError {
  const DatabaseError(super.message, [super.cause]);
}

final class ValidationError extends AppError {
  const ValidationError(super.message);
}

final class ImportError extends AppError {
  const ImportError(super.message, [super.cause]);
}

final class ExportError extends AppError {
  const ExportError(super.message, [super.cause]);
}
