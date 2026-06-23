import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/language.dart';
import '../../domain/repositories/translation_repository.dart';
import '../datasources/translation_remote_datasource.dart';

class TranslationRepositoryImpl implements TranslationRepository {
  final TranslationRemoteDataSource remoteDataSource;

  TranslationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, String>> translate(
    String text,
    Language sourceLanguage,
    Language targetLanguage,
  ) {
    return remoteDataSource.translate(text, sourceLanguage, targetLanguage);
  }
}
