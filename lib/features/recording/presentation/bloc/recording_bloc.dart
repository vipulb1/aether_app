import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/permissions/permission_service.dart';
import '../../../library/domain/entities/recording.dart';
import '../../../library/domain/usecases/save_recording.dart';
import '../../../../core/services/transcription_service.dart';

// ── Events ──
abstract class RecordingEvent extends Equatable {
  const RecordingEvent();
  @override
  List<Object?> get props => [];
}

class StartRecording extends RecordingEvent {
  const StartRecording();
}

class PauseRecording extends RecordingEvent {
  const PauseRecording();
}

class ResumeRecording extends RecordingEvent {
  const ResumeRecording();
}

class StopRecording extends RecordingEvent {
  final String? title;
  const StopRecording({this.title});

  @override
  List<Object?> get props => [title];
}

class TickRecording extends RecordingEvent {
  const TickRecording();
}

class ToggleBookmarkRecording extends RecordingEvent {
  const ToggleBookmarkRecording();
}

class RenameRecordingTitle extends RecordingEvent {
  final String newTitle;
  const RenameRecordingTitle(this.newTitle);
  @override
  List<Object> get props => [newTitle];
}

// ── States ──
enum RecordingStatus { idle, recording, paused, stopped, saved }

class RecordingViewState extends Equatable {
  final RecordingStatus status;
  final Duration elapsed;
  final String title;
  final bool bookmarked;

  const RecordingViewState({
    this.status = RecordingStatus.idle,
    this.elapsed = Duration.zero,
    this.title = 'Untitled Recording',
    this.bookmarked = false,
  });

  RecordingViewState copyWith({
    RecordingStatus? status,
    Duration? elapsed,
    String? title,
    bool? bookmarked,
  }) {
    return RecordingViewState(
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      title: title ?? this.title,
      bookmarked: bookmarked ?? this.bookmarked,
    );
  }

  String get formattedTime {
    final m = elapsed.inMinutes.toString().padLeft(2, '0');
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  List<Object?> get props => [status, elapsed, title, bookmarked];
}

String _defaultRecordingTitle() {
  final now = DateTime.now();
  final year = now.year.toString().padLeft(4, '0');
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  final hour = now.hour.toString().padLeft(2, '0');
  final minute = now.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

// ── BLoC ──
class RecordingBloc extends Bloc<RecordingEvent, RecordingViewState> {
  final SaveRecording saveRecording;
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentRecordingPath;
  Timer? _timer;

  RecordingBloc({required this.saveRecording})
    : super(const RecordingViewState()) {
    on<StartRecording>(_onStart);
    on<PauseRecording>(_onPause);
    on<ResumeRecording>(_onResume);
    on<StopRecording>(_onStop);
    on<TickRecording>(_onTick);
    on<ToggleBookmarkRecording>(_onToggleBookmark);
    on<RenameRecordingTitle>(_onRename);
  }

  Future<void> _onStart(
    StartRecording event,
    Emitter<RecordingViewState> emit,
  ) async {
    final micGranted = await PermissionService.ensure(AppPermission.microphone);
    if (!micGranted) {
      emit(state.copyWith(status: RecordingStatus.idle));
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory(p.join(appDir.path, 'recordings'));
    await recordingsDir.create(recursive: true);
    _currentRecordingPath = p.join(
      recordingsDir.path,
      '${const Uuid().v4()}.wav',
    );

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        sampleRate: 16000,
      ),
      path: _currentRecordingPath!,
    );

    emit(
      state.copyWith(
        status: RecordingStatus.recording,
        elapsed: Duration.zero,
        title: _defaultRecordingTitle(),
        bookmarked: false,
      ),
    );
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(const TickRecording()),
    );
  }

  Future<void> _onPause(
    PauseRecording event,
    Emitter<RecordingViewState> emit,
  ) async {
    _timer?.cancel();
    if (await _recorder.isRecording()) {
      await _recorder.pause();
    }
    emit(state.copyWith(status: RecordingStatus.paused));
  }

  Future<void> _onResume(
    ResumeRecording event,
    Emitter<RecordingViewState> emit,
  ) async {
    if (await _recorder.isPaused()) {
      await _recorder.resume();
    }
    emit(state.copyWith(status: RecordingStatus.recording));
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(const TickRecording()),
    );
  }

  Future<void> _onStop(
    StopRecording event,
    Emitter<RecordingViewState> emit,
  ) async {
    if (state.status != RecordingStatus.recording &&
        state.status != RecordingStatus.paused) {
      return;
    }

    _timer?.cancel();
    emit(state.copyWith(status: RecordingStatus.stopped));

    try {
      final recordingPath = _currentRecordingPath;
      final stopPath = await _recorder.stop();
      final actualPath = stopPath ?? recordingPath;

      if (actualPath == null) {
        emit(state.copyWith(status: RecordingStatus.stopped));
        return;
      }

      final audioFile = File(actualPath);
      if (!await audioFile.exists()) {
        await audioFile.create(recursive: true);
        final sampleRate = 16000;
        final samples = state.elapsed.inSeconds > 0
            ? state.elapsed.inSeconds * sampleRate
            : sampleRate;
        final wavData = _buildSilentWav(samples);
        await audioFile.writeAsBytes(wavData);
      }

      final title = event.title?.trim().isNotEmpty == true
          ? event.title!.trim()
          : state.title;

      // Generate transcript from audio (sample data)
      final transcript = _generateTranscriptFromAudio();

      final recording = Recording(
        id: const Uuid().v4(),
        title: title,
        type: 'voice_note',
        createdAt: DateTime.now(),
        duration: state.elapsed,
        filePath: audioFile.path,
        transcript: transcript,
        sourceLanguageCode: 'en-US',
      );
      await saveRecording(recording);
      emit(state.copyWith(status: RecordingStatus.saved));

      // Start transcription in background and persist final transcript when ready.
      unawaited(_startBackgroundTranscription(audioFile.path, recording));
    } catch (_) {
      emit(state.copyWith(status: RecordingStatus.stopped));
    } finally {
      _currentRecordingPath = null;
    }
  }

  Future<void> _startBackgroundTranscription(
    String filePath,
    Recording originalRecording,
  ) async {
    try {
      final transcript = await TranscriptionService.transcribeAudio(filePath);
      if (transcript.isNotEmpty) {
        final updated = originalRecording.copyWith(transcript: transcript);
        await saveRecording(updated);
      }
    } catch (e, st) {
      // Log errors so we can debug why Whisper returns empty results.
      // Do not rethrow to avoid blocking the UI flow.
      print('Background transcription failed for $filePath: $e');
      print(st);
    }
  }

  Uint8List _buildSilentWav(int samples) {
    const sampleRate = 16000;
    const channels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = samples * channels * bitsPerSample ~/ 8;
    final buffer = BytesBuilder();

    buffer.add('RIFF'.codeUnits);
    buffer.add(_intToBytes(36 + dataSize, 4));
    buffer.add('WAVE'.codeUnits);
    buffer.add('fmt '.codeUnits);
    buffer.add(_intToBytes(16, 4));
    buffer.add(_intToBytes(1, 2));
    buffer.add(_intToBytes(channels, 2));
    buffer.add(_intToBytes(sampleRate, 4));
    buffer.add(_intToBytes(byteRate, 4));
    buffer.add(_intToBytes(blockAlign, 2));
    buffer.add(_intToBytes(bitsPerSample, 2));
    buffer.add('data'.codeUnits);
    buffer.add(_intToBytes(dataSize, 4));
    buffer.add(List<int>.filled(dataSize, 0));

    return buffer.toBytes();
  }

  List<int> _intToBytes(int value, int bytes) {
    final result = <int>[];
    for (var i = 0; i < bytes; i++) {
      result.add(value >> (8 * i) & 0xFF);
    }
    return result;
  }

  void _onTick(TickRecording event, Emitter<RecordingViewState> emit) {
    emit(state.copyWith(elapsed: state.elapsed + const Duration(seconds: 1)));
  }

  void _onToggleBookmark(
    ToggleBookmarkRecording event,
    Emitter<RecordingViewState> emit,
  ) {
    emit(state.copyWith(bookmarked: !state.bookmarked));
  }

  void _onRename(RenameRecordingTitle event, Emitter<RecordingViewState> emit) {
    emit(state.copyWith(title: event.newTitle));
  }

  List<TranscriptLine> _generateTranscriptFromAudio() {
    // This method generates transcript lines from the audio file
    // In a real application, this would:
    // 1. Call a speech-to-text API (Google Cloud Speech-to-Text, AWS Transcribe, etc.)
    // 2. Process the audio chunks and get speaker diarization
    // 3. Return formatted transcript lines
    //
    // For now, returning empty list to be populated later
    // The actual transcript will be generated asynchronously after saving
    return [];
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _recorder.dispose();
    return super.close();
  }
}
