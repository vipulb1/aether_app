import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/recording.dart';
import '../repositories/library_repository.dart';

class GetRecordings implements UseCase<List<Recording>, NoParams> {
  final LibraryRepository repository;
  const GetRecordings(this.repository);

  @override
  Future<Either<Failure, List<Recording>>> call(NoParams params) {
    return repository.getRecordings();
  }
}
