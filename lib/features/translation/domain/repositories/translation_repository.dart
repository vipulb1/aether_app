import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/language.dart';

abstract class TranslationRepository {
  Future<Either<Failure, String>> translate(
    String text,
    Language sourceLanguage,
    Language targetLanguage,
  );
}
