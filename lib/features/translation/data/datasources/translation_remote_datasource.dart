import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import '../../../../core/error/failures.dart';
import '../../domain/entities/language.dart';

abstract class TranslationRemoteDataSource {
  Future<Either<Failure, String>> translate(
    String text,
    Language sourceLanguage,
    Language targetLanguage,
  );
}

class TranslationRemoteDataSourceImpl implements TranslationRemoteDataSource {
  final http.Client client;

  TranslationRemoteDataSourceImpl({required this.client});

  @override
  Future<Either<Failure, String>> translate(
    String text,
    Language sourceLanguage,
    Language targetLanguage,
  ) async {
    // In production: call translation API with both source and target languages.
    return Right('[${targetLanguage.code.toUpperCase()}] $text');
  }
}
