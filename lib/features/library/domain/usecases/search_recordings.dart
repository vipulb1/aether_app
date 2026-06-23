import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/recording.dart';
import '../repositories/library_repository.dart';

class SearchRecordings implements UseCase<List<Recording>, String> {
  final LibraryRepository repository;
  const SearchRecordings(this.repository);

  @override
  Future<Either<Failure, List<Recording>>> call(String query) {
    return repository.searchRecordings(query);
  }
}
