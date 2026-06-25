import 'package:equatable/equatable.dart';

class Recording extends Equatable {
  final String id;
  final String title;
  final String type; // meeting, interview, voice_note
  final DateTime createdAt;
  final Duration duration;
  final String summary;
  final List<TranscriptLine> transcript;
  final List<ActionItem> actions;
  final bool isRecording;
  final bool bookmarked;
  final String? filePath;
  final String sourceLanguageCode;

  const Recording({
    required this.id,
    required this.title,
    required this.type,
    required this.createdAt,
    required this.duration,
    this.summary = '',
    this.transcript = const [],
    this.actions = const [],
    this.isRecording = false,
    this.bookmarked = false,
    this.filePath,
    this.sourceLanguageCode = 'en',
  });

  @override
  List<Object?> get props => [
    id,
    title,
    type,
    createdAt,
    duration,
    summary,
    transcript,
    actions,
    isRecording,
    bookmarked,
    filePath,
    sourceLanguageCode,
  ];

  Recording copyWith({
    String? title,
    Duration? duration,
    String? summary,
    List<TranscriptLine>? transcript,
    List<ActionItem>? actions,
    bool? isRecording,
    String? filePath,
    String? sourceLanguageCode,
  }) {
    return Recording(
      id: id,
      title: title ?? this.title,
      type: type,
      createdAt: createdAt,
      duration: duration ?? this.duration,
      summary: summary ?? this.summary,
      transcript: transcript ?? this.transcript,
      actions: actions ?? this.actions,
      isRecording: isRecording ?? this.isRecording,
      bookmarked: bookmarked ?? this.bookmarked,
      filePath: filePath ?? this.filePath,
      sourceLanguageCode: sourceLanguageCode ?? this.sourceLanguageCode,
    );
  }

  String get formattedDuration {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get typeIcon {
    switch (type) {
      case 'interview':
        return '◈';
      case 'voice_note':
        return '●';
      default:
        return '✦';
    }
  }

  String get typeLabel {
    switch (type) {
      case 'interview':
        return 'Interview';
      case 'voice_note':
        return 'Voice Note';
      default:
        return 'Meeting';
    }
  }
}

class TranscriptLine extends Equatable {
  final String speaker;
  final String text;
  const TranscriptLine({required this.speaker, required this.text});
  @override
  List<Object> get props => [speaker, text];
}

class ActionItem extends Equatable {
  final String text;
  final bool done;
  const ActionItem({required this.text, this.done = false});
  @override
  List<Object?> get props => [text, done];
  ActionItem toggle() => ActionItem(text: text, done: !done);
}
