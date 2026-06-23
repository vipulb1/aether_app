import 'package:equatable/equatable.dart';
import '../../domain/entities/recording.dart';

enum LibraryStatus { initial, loading, loaded, error, empty }

class LibraryState extends Equatable {
  final LibraryStatus status;
  final List<Recording> recordings;
  final List<Recording> filteredRecordings;
  final String searchQuery;
  final String? errorMessage;

  const LibraryState({
    this.status = LibraryStatus.initial,
    this.recordings = const [],
    this.filteredRecordings = const [],
    this.searchQuery = '',
    this.errorMessage,
  });

  LibraryState copyWith({
    LibraryStatus? status,
    List<Recording>? recordings,
    List<Recording>? filteredRecordings,
    String? searchQuery,
    String? errorMessage,
  }) {
    return LibraryState(
      status: status ?? this.status,
      recordings: recordings ?? this.recordings,
      filteredRecordings: filteredRecordings ?? this.filteredRecordings,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, recordings, filteredRecordings, searchQuery, errorMessage];
}
