import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/library_repository.dart';

class RenameRecordingParams {
  final String id;
  final String newTitle;
  const RenameRecordingParams({required this.id, required this.newTitle});
}

class RenameRecording implements UseCase<void, RenameRecordingParams> {
  final LibraryRepository repository;
  const RenameRecording(this.repository);

  @override
  Future<Either<Failure, void>> call(RenameRecordingParams params) {
    return repository.renameRecording(params.id, params.newTitle);
  }
}
