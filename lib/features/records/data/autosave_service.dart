// lib/features/records/data/autosave_service.dart
// Pure logic for auto-save debounce semantics. No Flutter dependencies.

/// Determines whether a record's content is effectively empty
/// (both title and body are blank after trimming).
bool isRecordEffectivelyEmpty({
  required String title,
  required String body,
}) =>
    title.trim().isEmpty && body.trim().isEmpty;
