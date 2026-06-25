import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:translator/translator.dart';
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
  final GoogleTranslator _translator;

  TranslationRemoteDataSourceImpl({required this.client})
    : _translator = GoogleTranslator();

  @override
  Future<Either<Failure, String>> translate(
    String text,
    Language sourceLanguage,
    Language targetLanguage,
  ) async {
    if (sourceLanguage.code == targetLanguage.code) {
      return Right(text);
    }

    try {
      final translation = await _translator.translate(
        text,
        from: sourceLanguage.code,
        to: targetLanguage.code,
      );
      return Right(
        '${sourceLanguage.name} to ${targetLanguage.name} : ${translation.text}',
      );
    } catch (_) {
      return const Left(TranslationFailure());
    }
  }
}
