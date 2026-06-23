import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/recording.dart';
import '../repositories/library_repository.dart';

class SaveRecording implements UseCase<void, Recording> {
  final LibraryRepository repository;
  const SaveRecording(this.repository);

  @override
  Future<Either<Failure, void>> call(Recording recording) {
    return repository.saveRecording(recording);
  }
}
