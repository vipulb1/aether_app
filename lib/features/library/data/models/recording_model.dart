import '../../domain/entities/recording.dart';

class RecordingModel extends Recording {
  const RecordingModel({
    required super.id,
    required super.title,
    required super.type,
    required super.createdAt,
    required super.duration,
    super.summary,
    super.transcript,
    super.actions,
    super.isRecording,
    super.bookmarked,
    super.filePath,
    super.sourceLanguageCode,
  });

  factory RecordingModel.fromJson(Map<String, dynamic> json) {
    return RecordingModel(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      duration: Duration(seconds: json['duration_seconds'] as int),
      summary: json['summary'] as String? ?? '',
      transcript:
          (json['transcript'] as List<dynamic>?)
              ?.map(
                (t) => TranscriptLine(
                  speaker: t['speaker'] as String,
                  text: t['text'] as String,
                ),
              )
              .toList() ??
          [],
      actions:
          (json['actions'] as List<dynamic>?)
              ?.map(
                (a) => ActionItem(
                  text: a['text'] as String,
                  done: a['done'] as bool? ?? false,
                ),
              )
              .toList() ??
          [],
      isRecording: json['is_recording'] as bool? ?? false,
      bookmarked: json['bookmarked'] as bool? ?? false,
      filePath: json['file_path'] as String?,
      sourceLanguageCode: json['source_language_code'] as String? ?? 'en',
    );
  }

  factory RecordingModel.fromEntity(Recording recording) {
    return RecordingModel(
      id: recording.id,
      title: recording.title,
      type: recording.type,
      createdAt: recording.createdAt,
      duration: recording.duration,
      summary: recording.summary,
      transcript: recording.transcript,
      actions: recording.actions,
      isRecording: recording.isRecording,
      bookmarked: recording.bookmarked,
      filePath: recording.filePath,
      sourceLanguageCode: recording.sourceLanguageCode,
    );
  }

  RecordingModel copyWith({
    String? title,
    Duration? duration,
    String? summary,
    List<TranscriptLine>? transcript,
    List<ActionItem>? actions,
    bool? isRecording,
    bool? bookmarked,
    String? filePath,
    String? sourceLanguageCode,
  }) {
    return RecordingModel(
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'created_at': createdAt.toIso8601String(),
      'duration_seconds': duration.inSeconds,
      'summary': summary,
      'transcript': transcript
          .map((t) => {'speaker': t.speaker, 'text': t.text})
          .toList(),
      'actions': actions.map((a) => {'text': a.text, 'done': a.done}).toList(),
      'is_recording': isRecording,
      'bookmarked': bookmarked,
      'file_path': filePath,
      'source_language_code': sourceLanguageCode,
    };
  }

  Recording toEntity() => this;
}
