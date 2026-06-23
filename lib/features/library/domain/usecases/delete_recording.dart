import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/library_repository.dart';

class DeleteRecording implements UseCase<void, String> {
  final LibraryRepository repository;
  const DeleteRecording(this.repository);

  @override
  Future<Either<Failure, void>> call(String id) {
    return repository.deleteRecording(id);
  }
}
