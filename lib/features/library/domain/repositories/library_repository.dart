import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/recording.dart';

abstract class LibraryRepository {
  Future<Either<Failure, List<Recording>>> getRecordings();
  Future<Either<Failure, List<Recording>>> searchRecordings(String query);
  Future<Either<Failure, void>> deleteRecording(String id);
  Future<Either<Failure, Recording>> getRecordingById(String id);
  Future<Either<Failure, void>> saveRecording(Recording recording);
  Future<Either<Failure, void>> renameRecording(String id, String newTitle);
}
