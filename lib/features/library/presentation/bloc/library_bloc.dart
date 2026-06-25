import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'package:hive/hive.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/usecases/get_recordings.dart';
import '../../domain/usecases/search_recordings.dart';
import '../../domain/usecases/delete_recording.dart';
import '../../domain/usecases/rename_recording.dart';
import '../../domain/usecases/save_recording.dart';
import 'library_event.dart';
import 'library_state.dart';

class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  final GetRecordings getRecordings;
  final SearchRecordings searchRecordings;
  final DeleteRecording deleteRecording;
  final RenameRecording renameRecording;
  final SaveRecording saveRecording;

  LibraryBloc({
    required this.getRecordings,
    required this.searchRecordings,
    required this.deleteRecording,
    required this.renameRecording,
    required this.saveRecording,
  }) : super(const LibraryState()) {
    on<LoadRecordings>(_onLoadRecordings);
    on<SearchQueryChanged>(_onSearchChanged);
    on<DeleteRecordingRequested>(_onDeleteRecording);
    on<RecordingSelected>(_onRecordingSelected);
    on<RenameRecordingRequested>(_onRenameRecording);
    on<UpdateRecordingRequested>(_onUpdateRecording);

    // Watch Hive recordings box and reload when changes occur so UI updates
    // when recordings are modified outside of this Bloc (e.g., background transcription).
    try {
      final box = Hive.box('recordings');
      _boxSubscription = box.watch().listen((_) => add(const LoadRecordings()));
    } catch (_) {
      _boxSubscription = null;
    }
  }

  StreamSubscription? _boxSubscription;

  Future<void> _onLoadRecordings(
    LoadRecordings event,
    Emitter<LibraryState> emit,
  ) async {
    emit(state.copyWith(status: LibraryStatus.loading));
    final result = await getRecordings(const NoParams());
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: LibraryStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (recordings) => emit(
        state.copyWith(
          status: recordings.isEmpty
              ? LibraryStatus.empty
              : LibraryStatus.loaded,
          recordings: recordings,
          filteredRecordings: recordings,
        ),
      ),
    );
  }

  Future<void> _onSearchChanged(
    SearchQueryChanged event,
    Emitter<LibraryState> emit,
  ) async {
    final query = event.query;
    emit(state.copyWith(searchQuery: query));
    // Don't filter in BLoC - let the UI handle both name and date filtering
    // This allows the page to apply custom date search logic
  }

  Future<void> _onDeleteRecording(
    DeleteRecordingRequested event,
    Emitter<LibraryState> emit,
  ) async {
    await deleteRecording(event.id);
    add(const LoadRecordings());
  }

  Future<void> _onRenameRecording(
    RenameRecordingRequested event,
    Emitter<LibraryState> emit,
  ) async {
    await renameRecording(
      RenameRecordingParams(id: event.id, newTitle: event.newTitle),
    );
    add(const LoadRecordings());
  }

  Future<void> _onUpdateRecording(
    UpdateRecordingRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final result = await saveRecording(event.recording);
    result.fold((_) {}, (_) => add(const LoadRecordings()));
  }

  void _onRecordingSelected(
    RecordingSelected event,
    Emitter<LibraryState> emit,
  ) {}

  @override
  Future<void> close() async {
    await _boxSubscription?.cancel();
    return super.close();
  }
}
