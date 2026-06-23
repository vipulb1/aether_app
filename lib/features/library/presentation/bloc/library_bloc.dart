import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/usecases/get_recordings.dart';
import '../../domain/usecases/search_recordings.dart';
import '../../domain/usecases/delete_recording.dart';
import '../../domain/usecases/rename_recording.dart';
import 'library_event.dart';
import 'library_state.dart';

class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  final GetRecordings getRecordings;
  final SearchRecordings searchRecordings;
  final DeleteRecording deleteRecording;
  final RenameRecording renameRecording;

  LibraryBloc({
    required this.getRecordings,
    required this.searchRecordings,
    required this.deleteRecording,
    required this.renameRecording,
  }) : super(const LibraryState()) {
    on<LoadRecordings>(_onLoadRecordings);
    on<SearchQueryChanged>(_onSearchChanged);
    on<DeleteRecordingRequested>(_onDeleteRecording);
    on<RecordingSelected>(_onRecordingSelected);
    on<RenameRecordingRequested>(_onRenameRecording);
  }

  Future<void> _onLoadRecordings(
    LoadRecordings event,
    Emitter<LibraryState> emit,
  ) async {
    emit(state.copyWith(status: LibraryStatus.loading));
    final result = await getRecordings(const NoParams());
    result.fold(
      (failure) => emit(state.copyWith(
        status: LibraryStatus.error,
        errorMessage: failure.message,
      )),
      (recordings) => emit(state.copyWith(
        status: recordings.isEmpty ? LibraryStatus.empty : LibraryStatus.loaded,
        recordings: recordings,
        filteredRecordings: recordings,
      )),
    );
  }

  Future<void> _onSearchChanged(
    SearchQueryChanged event,
    Emitter<LibraryState> emit,
  ) async {
    final query = event.query;
    emit(state.copyWith(searchQuery: query));
    if (query.isEmpty) {
      emit(state.copyWith(filteredRecordings: state.recordings));
      return;
    }
    final result = await searchRecordings(query);
    result.fold(
      (_) => emit(state.copyWith(filteredRecordings: state.recordings)),
      (filtered) => emit(state.copyWith(filteredRecordings: filtered)),
    );
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
    await renameRecording(RenameRecordingParams(id: event.id, newTitle: event.newTitle));
    add(const LoadRecordings());
  }

  void _onRecordingSelected(RecordingSelected event, Emitter<LibraryState> emit) {}
}
