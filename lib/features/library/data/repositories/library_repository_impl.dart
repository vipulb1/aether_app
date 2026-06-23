import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/recording.dart';
import '../../domain/repositories/library_repository.dart';
import '../datasources/library_local_datasource.dart';
import '../datasources/library_remote_datasource.dart';

class LibraryRepositoryImpl implements LibraryRepository {
  final LibraryLocalDataSource localDataSource;
  final LibraryRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  LibraryRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<Recording>>> getRecordings() async {
    if (await networkInfo.isConnected) {
      try {
        final remote = await remoteDataSource.getRecordings();
        await localDataSource.cacheRecordings(remote);
        return Right(remote);
      } on ServerException catch (_) {
        // Remote service is unavailable; try cached local data instead.
      } catch (error) {
        return Left(UnexpectedFailure(error.toString()));
      }
    }

    try {
      final cached = await localDataSource.getCachedRecordings();
      return Right(cached);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (error) {
      return Left(UnexpectedFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Recording>>> searchRecordings(
    String query,
  ) async {
    if (await networkInfo.isConnected) {
      try {
        return Right(await remoteDataSource.searchRecordings(query));
      } on ServerException catch (_) {
        // Remote search failed, fall back to local cached results.
      } catch (error) {
        return Left(UnexpectedFailure(error.toString()));
      }
    }
    // Offline or remote failure: filter cached
    try {
      final all = await localDataSource.getCachedRecordings();
      final q = query.toLowerCase();
      return Right(
        all
            .where(
              (r) =>
                  r.title.toLowerCase().contains(q) ||
                  r.summary.toLowerCase().contains(q),
            )
            .toList(),
      );
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (error) {
      return Left(UnexpectedFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRecording(String id) async {
    try {
      await localDataSource.deleteCachedRecording(id);
      if (await networkInfo.isConnected) {
        try {
          await remoteDataSource.deleteRecording(id);
        } on ServerException {
          // Silent fail — local delete succeeded
        }
      }
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (error) {
      return Left(UnexpectedFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Recording>> getRecordingById(String id) async {
    try {
      final all = await localDataSource.getCachedRecordings();
      final found = all.firstWhere((r) => r.id == id);
      return Right(found);
    } catch (e) {
      return Left(CacheFailure('Recording not found'));
    }
  }

  @override
  Future<Either<Failure, void>> saveRecording(Recording recording) async {
    try {
      await localDataSource.saveRecording(recording);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> renameRecording(
    String id,
    String newTitle,
  ) async {
    try {
      await localDataSource.renameCachedRecording(id, newTitle);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }
}
