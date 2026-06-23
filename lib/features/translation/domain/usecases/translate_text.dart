import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/language.dart';
import '../repositories/translation_repository.dart';

class TranslateParams {
  final String text;
  final Language sourceLanguage;
  final Language targetLanguage;
  const TranslateParams({
    required this.text,
    required this.sourceLanguage,
    required this.targetLanguage,
  });
}

class TranslateText implements UseCase<String, TranslateParams> {
  final TranslationRepository repository;
  const TranslateText(this.repository);

  @override
  Future<Either<Failure, String>> call(TranslateParams params) {
    return repository.translate(
      params.text,
      params.sourceLanguage,
      params.targetLanguage,
    );
  }
}
