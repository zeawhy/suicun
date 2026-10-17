import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/data/autosave_service.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/domain/id_doc_codec.dart';
import 'package:suicun/features/records/presentation/records_notifier.dart';
import 'package:suicun/shared/utils/display_title.dart';

part 'edit_record_notifier.g.dart';

enum SaveState { saving, saved, error }

class EditRecordState {
  const EditRecordState({
    this.record,
    this.saveState = SaveState.saved,
  });

  final RecordDetail? record;
  final SaveState saveState;

  EditRecordState copyWith({
    RecordDetail? record,
    SaveState? saveState,
  }) {
    return EditRecordState(
      record: record ?? this.record,
      saveState: saveState ?? this.saveState,
    );
  }
}

@riverpod
class EditRecordNotifier extends _$EditRecordNotifier {
  Timer? _debounceTimer;
  Future<void>? _saveFuture;

  /// Latest pending input captured by [onInputChanged], used by [flush].
  String? _pendingTitle;
  String? _pendingBody;

  @override
  EditRecordState build(String? recordId) {
    if (recordId != null) {
      _loadRecord(recordId);
    }

    ref.onDispose(() {
      _debounceTimer?.cancel();
    });

    return const EditRecordState();
  }

  Future<void> _loadRecord(String id) async {
    try {
      final repo = ref.read(recordRepositoryProvider);
      final record = await repo.getRecord(id);
      if (record != null) {
        state = state.copyWith(record: record);
      }
    } catch (e) {
      // ignore
    }
  }

  void onInputChanged(String title, String body) {
    if (isRecordEffectivelyEmpty(title: title, body: body) &&
        state.record == null) {
      return;
    }

    _pendingTitle = title;
    _pendingBody = body;
    state = state.copyWith(saveState: SaveState.saving);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _pendingTitle = null;
      _pendingBody = null;
      _save(title: title, body: body);
    });
  }

  /// Runs [task] after any in-flight save completes, serializing saves so a
  /// slow create can never be duplicated by a second overlapping save.
  Future<void> _serialize(Future<void> Function() task) {
    final previous = _saveFuture;
    final completer = Completer<void>();
    _saveFuture = completer.future;
    return () async {
      try {
        if (previous != null) await previous;
        await task();
      } finally {
        completer.complete();
      }
    }();
  }

  Future<void> _save({
    String? title,
    String? body,
    String? categoryId,
    bool clearCategory = false,
    bool? isFavorite,
    List<String>? tagIds,
  }) {
    final effectiveTitle = (title != null &&
            title.trim().isEmpty &&
            body != null &&
            isIdDocBody(body))
        ? displayTitleFrom(title: '', body: body, untitled: '')
        : title;
    return _serialize(() async {
      state = state.copyWith(saveState: SaveState.saving);
      final repo = ref.read(recordRepositoryProvider);
      try {
        if (state.record == null) {
          // Create new
          final newRecord = await repo.createRecord(
            title: effectiveTitle ?? '',
            body: body ?? '',
            categoryId: categoryId,
            isFavorite: isFavorite ?? false,
            tagIds: tagIds ?? const [],
          );
          state = state.copyWith(record: newRecord, saveState: SaveState.saved);
        } else {
          // Update existing
          final updatedRecord = await repo.updateRecord(
            state.record!.id,
            title: effectiveTitle,
            body: body,
            categoryId: categoryId,
            clearCategoryId: clearCategory,
            isFavorite: isFavorite,
            tagIds: tagIds,
          );
          state =
              state.copyWith(record: updatedRecord, saveState: SaveState.saved);
        }
        ref.invalidate(recordsListProvider);
      } catch (e) {
        state = state.copyWith(saveState: SaveState.error);
      }
    });
  }

  Future<void> toggleFavorite() async {
    if (state.record == null) return;
    await _save(isFavorite: !state.record!.isFavorite);
  }

  Future<void> setCategory(String? categoryId) async {
    await _save(categoryId: categoryId, clearCategory: categoryId == null);
  }

  Future<void> setTags(List<String> tagIds) async {
    await _save(tagIds: tagIds);
  }

  /// Immediately persists any pending debounced input and waits for all
  /// in-flight saves. Called when leaving the edit page so no keystroke
  /// is lost when the 500 ms debounce window hasn't elapsed yet.
  Future<void> flush() async {
    _debounceTimer?.cancel();
    final title = _pendingTitle;
    final body = _pendingBody;
    _pendingTitle = null;
    _pendingBody = null;
    if (title != null && body != null) {
      await _save(title: title, body: body);
    } else if (_saveFuture != null) {
      await _saveFuture;
    }
  }

  /// Ensures a record exists, creating an empty one if necessary.
  /// Returns the record ID. Used by the ID document new-flow (§1.3)
  /// which needs a record ID before opening IdDocForm.
  Future<String> ensureRecordExists() async {
    if (state.record != null) return state.record!.id;
    await _serialize(() async {
      if (state.record != null) return;
      final repo = ref.read(recordRepositoryProvider);
      final newRecord = await repo.createRecord(
        title: '',
        body: '',
        isFavorite: false,
        tagIds: const [],
      );
      state = state.copyWith(record: newRecord, saveState: SaveState.saved);
    });
    return state.record!.id;
  }
}
