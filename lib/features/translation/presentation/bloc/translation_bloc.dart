import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/language.dart';
import '../../domain/usecases/translate_text.dart';
import '../../../library/domain/entities/recording.dart';

abstract class TranslationEvent extends Equatable {
  const TranslationEvent();
  @override
  List<Object?> get props => [];
}

class SelectLanguage extends TranslationEvent {
  final Language language;
  const SelectLanguage(this.language);
  @override
  List<Object> get props => [language];
}

class TranslateTranscript extends TranslationEvent {
  final List<TranscriptLine> lines;
  final Language sourceLanguage;
  final Language targetLanguage;
  const TranslateTranscript(
    this.lines,
    this.sourceLanguage,
    this.targetLanguage,
  );
  @override
  List<Object> get props => [lines, sourceLanguage, targetLanguage];
}

enum TranslationStatus { initial, translating, done, error }

class TranslatedLine {
  final String speaker;
  final String text;
  final String? originalSpeaker;
  final String? originalText;
  const TranslatedLine({
    required this.speaker,
    required this.text,
    this.originalSpeaker,
    this.originalText,
  });
}

class TranslationState extends Equatable {
  final TranslationStatus status;
  final Language? selectedLanguage;
  final List<TranslatedLine>? translatedLines;
  final String? errorMessage;

  const TranslationState({
    this.status = TranslationStatus.initial,
    this.selectedLanguage,
    this.translatedLines,
    this.errorMessage,
  });

  TranslationState copyWith({
    TranslationStatus? status,
    Language? selectedLanguage,
    List<TranslatedLine>? translatedLines,
    String? errorMessage,
  }) {
    return TranslationState(
      status: status ?? this.status,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      translatedLines: translatedLines ?? this.translatedLines,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    selectedLanguage,
    translatedLines,
    errorMessage,
  ];
}

class TranslationBloc extends Bloc<TranslationEvent, TranslationState> {
  final TranslateText translateText;

  TranslationBloc({required this.translateText})
    : super(const TranslationState()) {
    on<SelectLanguage>(_onSelectLanguage);
    on<TranslateTranscript>(_onTranslateTranscript);
  }

  void _onSelectLanguage(SelectLanguage event, Emitter<TranslationState> emit) {
    emit(state.copyWith(selectedLanguage: event.language));
  }

  Future<void> _onTranslateTranscript(
    TranslateTranscript event,
    Emitter<TranslationState> emit,
  ) async {
    emit(state.copyWith(status: TranslationStatus.translating));

    try {
      final translations = await Future.wait(
        event.lines.map((line) async {
          final result = await translateText(
            TranslateParams(
              text: line.text,
              sourceLanguage: event.sourceLanguage,
              targetLanguage: event.targetLanguage,
            ),
          );
          return result.fold(
            (_) => '[${event.targetLanguage.code.toUpperCase()}] ${line.text}',
            (translated) => translated,
          );
        }),
      );

      final translatedLines = <TranslatedLine>[];
      for (var i = 0; i < event.lines.length; i++) {
        final line = event.lines[i];
        translatedLines.add(
          TranslatedLine(
            speaker: _translateSpeaker(line.speaker, event.targetLanguage.code),
            text: translations[i],
            originalSpeaker: line.speaker,
            originalText: line.text,
          ),
        );
      }

      emit(
        state.copyWith(
          status: TranslationStatus.done,
          translatedLines: translatedLines,
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: TranslationStatus.error));
    }
  }

  String _translateSpeaker(String name, String langCode) {
    const map = <String, Map<String, String>>{
      'ja': {
        'Alex Kim': 'アレックス・キム',
        'Elena Vasquez': 'エレナ・バスケス',
        'Dr. Patel': 'パテル博士',
      },
      'ko': {'Alex Kim': '알렉스 김', 'Dr. Patel': '파텔 박사'},
      'zh': {'Dr. Patel': 'Patel 博士'},
      'ar': {'Alex Kim': 'أليكس كيم', 'Dr. Patel': 'الدكتور باتيل'},
    };
    return map[langCode]?[name] ?? name;
  }
}
