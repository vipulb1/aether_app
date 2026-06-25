import 'package:equatable/equatable.dart';
import '../../domain/entities/recording.dart';

abstract class LibraryEvent extends Equatable {
  const LibraryEvent();
  @override
  List<Object?> get props => [];
}

class LoadRecordings extends LibraryEvent {
  const LoadRecordings();
}

class SearchQueryChanged extends LibraryEvent {
  final String query;
  const SearchQueryChanged(this.query);
  @override
  List<Object> get props => [query];
}

class DeleteRecordingRequested extends LibraryEvent {
  final String id;
  const DeleteRecordingRequested(this.id);
  @override
  List<Object> get props => [id];
}

class RecordingSelected extends LibraryEvent {
  final Recording recording;
  const RecordingSelected(this.recording);
  @override
  List<Object> get props => [recording];
}

class RenameRecordingRequested extends LibraryEvent {
  final String id;
  final String newTitle;
  const RenameRecordingRequested(this.id, this.newTitle);
  @override
  List<Object> get props => [id, newTitle];
}

class UpdateRecordingRequested extends LibraryEvent {
  final Recording recording;
  const UpdateRecordingRequested(this.recording);
  @override
  List<Object?> get props => [recording];
}
