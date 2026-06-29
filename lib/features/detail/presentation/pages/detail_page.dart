import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';
import '../../../library/data/models/recording_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/transcription_service.dart';
import '../../../library/domain/entities/recording.dart';
import '../../../library/presentation/bloc/library_bloc.dart';
import '../../../library/presentation/bloc/library_event.dart';
import '../../../translation/presentation/bloc/translation_bloc.dart';
import '../../../translation/domain/entities/language.dart';
import '../../../translation/presentation/widgets/language_modal.dart';

class DetailPage extends StatefulWidget {
  final Recording recording;
  const DetailPage({super.key, required this.recording});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late Recording _recording;
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _boxSubscription;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  RangeValues _selectedRange = const RangeValues(0, 0);
  String? _selectedRangeNotes;
  bool _isExtractingRangeNotes = false;
  String? _rangeExtractionError;
  bool _isRangePlaybackActive = false;
  Duration _rangePlaybackEnd = Duration.zero;

  @override
  void initState() {
    super.initState();
    _recording = widget.recording;
    _initializeSelectedRange();
    _watchRecordingUpdates();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _playerState = state;
      });
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _duration = duration;
      });
    });
    _audioPlayer.onPositionChanged.listen((position) {
      if (_isRangePlaybackActive && position >= _rangePlaybackEnd) {
        _audioPlayer.pause();
        setState(() {
          _isRangePlaybackActive = false;
          _playerState = PlayerState.stopped;
          _position = _rangePlaybackEnd;
        });
      } else {
        setState(() {
          _position = position;
        });
      }
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _playerState = PlayerState.stopped;
        _position = _isRangePlaybackActive ? _rangePlaybackEnd : _duration;
        _isRangePlaybackActive = false;
      });
    });
  }

  void _watchRecordingUpdates() {
    try {
      final box = Hive.box('recordings');
      _boxSubscription = box.watch(key: _recording.id).listen((_) {
        final value = box.get(_recording.id);
        if (value == null) return;
        final updated = RecordingModel.fromJson(
          Map<String, dynamic>.from(value as Map),
        );
        if (!mounted) return;
        setState(() {
          _recording = updated;
        });
      });
    } catch (_) {
      _boxSubscription = null;
    }
  }

  @override
  void dispose() {
    _boxSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _shareRecording() async {
    if (_recording.filePath == null || _recording.filePath!.isEmpty) return;

    final transcriptText = _recording.transcript.isEmpty
        ? 'No transcript available.'
        : _recording.transcript
              .map((line) => '${line.speaker}: ${line.text}')
              .join('\n');

    final message = StringBuffer()
      ..writeln('Recording: ${_recording.title}')
      ..writeln('Duration: ${_recording.formattedDuration}')
      ..writeln('\nTranscript:')
      ..writeln(transcriptText);

    await Share.shareXFiles(
      [XFile(_recording.filePath!)],
      text: message.toString(),
      subject: _recording.title,
    );
  }

  Future<void> _togglePlayback() async {
    if (_recording.filePath == null || _recording.filePath!.isEmpty) return;

    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else if (_playerState == PlayerState.paused) {
      await _audioPlayer.resume();
    } else {
      await _audioPlayer.play(DeviceFileSource(_recording.filePath!));
    }
  }

  void _initializeSelectedRange() {
    final maxSeconds = (_recording.duration.inSeconds > 0)
        ? _recording.duration.inSeconds.toDouble()
        : 1.0;
    final endSeconds = _recording.duration.inSeconds >= 10 ? 10.0 : maxSeconds;
    _selectedRange = RangeValues(0, endSeconds);
    _selectedRangeNotes = null;
    _rangeExtractionError = null;
  }

  Future<void> _playSelectedRange() async {
    if (_recording.filePath == null || _recording.filePath!.isEmpty) return;
    final startSeconds = _selectedRange.start.round();
    final endSeconds = _selectedRange.end.round();
    if (endSeconds <= startSeconds) return;

    final start = Duration(seconds: startSeconds);
    final end = Duration(seconds: endSeconds);

    if (_isRangePlaybackActive && _playerState == PlayerState.playing) {
      await _audioPlayer.pause();
      setState(() {
        _isRangePlaybackActive = false;
      });
      return;
    }

    _rangePlaybackEnd = end;
    _isRangePlaybackActive = true;
    await _audioPlayer.play(
      DeviceFileSource(_recording.filePath!),
      position: start,
    );
    setState(() {});
  }

  Future<void> _playSavedClip(RecordingNote note) async {
    if (note.clipPath == null || note.clipPath!.isEmpty) return;

    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
      setState(() {
        _isRangePlaybackActive = false;
      });
      return;
    }

    _rangePlaybackEnd = note.end;
    _isRangePlaybackActive = true;
    await _audioPlayer.play(
      DeviceFileSource(note.clipPath!),
      position: note.start,
    );
    setState(() {});
  }

  Future<void> _extractNotesForSelectedRange() async {
    if (_recording.filePath == null || _recording.filePath!.isEmpty) return;
    final startSeconds = _selectedRange.start.round();
    final endSeconds = _selectedRange.end.round();
    if (endSeconds <= startSeconds) return;

    setState(() {
      _isExtractingRangeNotes = true;
      _rangeExtractionError = null;
      _selectedRangeNotes = null;
    });

    try {
      final notes = await TranscriptionService.transcribeAudioRange(
        _recording.filePath!,
        Duration(seconds: startSeconds),
        Duration(seconds: endSeconds),
      );
      if (!mounted) return;
      final noteText = notes.isNotEmpty
          ? notes.map((line) => '${line.speaker}: ${line.text}').join('\n')
          : 'No notes could be extracted from the selected interval.';

      if (notes.isNotEmpty) {
        final clipPath = await TranscriptionService.saveAudioClip(
          _recording.filePath!,
          Duration(seconds: startSeconds),
          Duration(seconds: endSeconds),
          _recording.id,
        );

        final newNote = RecordingNote(
          id: '${_recording.id}-${DateTime.now().millisecondsSinceEpoch}',
          start: Duration(seconds: startSeconds),
          end: Duration(seconds: endSeconds),
          text: noteText,
          clipPath: clipPath,
        );
        final updatedRecording = _recording.copyWith(
          notes: [..._recording.notes, newNote],
        );
        context.read<LibraryBloc>().add(
          UpdateRecordingRequested(updatedRecording),
        );
        setState(() {
          _recording = updatedRecording;
          _selectedRangeNotes = noteText;
        });
      } else {
        setState(() {
          _selectedRangeNotes = noteText;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _rangeExtractionError = error.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isExtractingRangeNotes = false;
      });
    }
  }

  void _updateSelectedRange(RangeValues values) {
    setState(() {
      _selectedRange = values;
    });
  }

  void _rename() {
    final controller = TextEditingController(text: _recording.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Rename Recording',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Enter a name…',
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                context.read<LibraryBloc>().add(
                  RenameRecordingRequested(_recording.id, newTitle),
                );
                setState(
                  () => _recording = _recording.copyWith(title: newTitle),
                );
              }
              Navigator.pop(ctx);
            },
            child: Text(
              'Rename',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Library',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.share,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: _shareRecording,
            ),
            IconButton(
              icon: Icon(
                Icons.more_horiz,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: () => _showMoreMenu(),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _recording.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_recording.typeLabel} · ${_recording.formattedDuration}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const TabBar(
              isScrollable: false,
              labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              unselectedLabelStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(text: 'Summary'),
                Tab(text: 'Transcript'),
                Tab(text: 'Actions'),
                Tab(text: 'Translate'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _SummaryTab(
                    recording: _recording,
                    onTogglePlayback: _togglePlayback,
                    isPlaying: _playerState == PlayerState.playing,
                    position: _position,
                    duration: _duration,
                  ),
                  _TranscriptTab(recording: _recording),
                  _ActionsTab(
                    recording: _recording,
                    selectedRange: _selectedRange,
                    isExtractingNotes: _isExtractingRangeNotes,
                    extractedNotes: _selectedRangeNotes,
                    extractionError: _rangeExtractionError,
                    savedNotes: _recording.notes,
                    onPlaySavedNote: _playSavedClip,
                    isPlayingRange:
                        _isRangePlaybackActive &&
                        _playerState == PlayerState.playing,
                    onPlaySelectedRange: _playSelectedRange,
                    onExtractNotes: _extractNotesForSelectedRange,
                    onRangeChanged: _updateSelectedRange,
                  ),
                  _TranslateTab(recording: _recording),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _recording.title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_recording.typeLabel} · ${_recording.formattedDuration}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  _recording.bookmarked
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color: _recording.bookmarked
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  _recording.bookmarked ? 'Remove bookmark' : 'Bookmark',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _recording = _recording.copyWith(
                      bookmarked: !_recording.bookmarked,
                    );
                  });
                  context.read<LibraryBloc>().add(
                    UpdateRecordingRequested(_recording),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.edit_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  'Rename',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _rename();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<LibraryBloc>().add(
                    DeleteRecordingRequested(_recording.id),
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  final Recording recording;
  final VoidCallback onTogglePlayback;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  const _SummaryTab({
    required this.recording,
    required this.onTogglePlayback,
    required this.isPlaying,
    required this.position,
    required this.duration,
  });

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio =
        recording.filePath != null && recording.filePath!.isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI SUMMARY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            recording.summary.isEmpty
                ? 'No summary available yet.'
                : recording.summary,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(height: 1.65),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: hasAudio ? onTogglePlayback : null,
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            label: Text(
              hasAudio
                  ? (isPlaying ? 'Pause playback' : 'Listen to recording')
                  : 'No recording audio available',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasAudio
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceVariant,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (hasAudio)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatDuration(position)} / ${_formatDuration(duration > Duration.zero ? duration : recording.duration)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isPlaying
                      ? 'Playing…'
                      : 'Tap listen to play the saved recording.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TranscriptTab extends StatefulWidget {
  final Recording recording;
  const _TranscriptTab({required this.recording});

  @override
  State<_TranscriptTab> createState() => _TranscriptTabState();
}

class _TranscriptTabState extends State<_TranscriptTab> {
  final List<TranscriptLine> _transcriptLines = [];
  StreamSubscription<List<TranscriptLine>>? _streamSubscription;
  StreamSubscription? _boxSubscription;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _transcriptLines.addAll(widget.recording.transcript);
    // Watch for external updates to this recording in the Hive box
    try {
      final box = Hive.box('recordings');
      _boxSubscription = box.watch().listen((event) {
        if (event.key == widget.recording.id) {
          final value = box.get(widget.recording.id);
          if (value == null) return;
          final updated = RecordingModel.fromJson(
            Map<String, dynamic>.from(value as Map),
          );
          if (!mounted) return;
          setState(() {
            _transcriptLines
              ..clear()
              ..addAll(updated.transcript);
          });
        }
      });
    } catch (_) {
      _boxSubscription = null;
    }
    if (_transcriptLines.isEmpty) {
      _startTranscription();
    }
  }

  @override
  void didUpdateWidget(covariant _TranscriptTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recording.id != widget.recording.id ||
        oldWidget.recording.transcript != widget.recording.transcript) {
      _transcriptLines
        ..clear()
        ..addAll(widget.recording.transcript);
      if (_transcriptLines.isEmpty && !_isProcessing) {
        _startTranscription();
      }
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _boxSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startTranscription() async {
    if (widget.recording.filePath == null ||
        widget.recording.filePath!.isEmpty) {
      setState(() {
        _errorMessage = 'No audio file available for transcription.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final stream = TranscriptionService.transcribeAudioStream(
      widget.recording.filePath!,
    );

    _streamSubscription?.cancel();
    _streamSubscription = stream.listen(
      (chunk) {
        setState(() {
          _transcriptLines.addAll(chunk);
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Transcript failed: ${error.toString()}';
        });
      },
      onDone: () async {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
        });

        if (_transcriptLines.isNotEmpty) {
          final updatedRecording = widget.recording.copyWith(
            transcript: List<TranscriptLine>.from(_transcriptLines),
          );
          context.read<LibraryBloc>().add(
            UpdateRecordingRequested(updatedRecording),
          );
        }
      },
      cancelOnError: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _startTranscription,
                child: const Text('Retry transcription'),
              ),
            ],
          ),
        ),
      );
    }

    if (_transcriptLines.isEmpty) {
      return const _ProcessingTranscriptAnimation();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _transcriptLines.length,
      itemBuilder: (_, i) {
        final line = _transcriptLines[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.speaker,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                line.text,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontSize: 15, height: 1.7),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProcessingTranscriptAnimation extends StatefulWidget {
  const _ProcessingTranscriptAnimation();

  @override
  State<_ProcessingTranscriptAnimation> createState() =>
      _ProcessingTranscriptAnimationState();
}

class _ProcessingTranscriptAnimationState
    extends State<_ProcessingTranscriptAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<int> _dotsAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _dotsAnimation = IntTween(begin: 0, end: 3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _dotsAnimation,
            builder: (context, child) {
              final dots = '.' * (_dotsAnimation.value + 1);
              return Text(
                'Processing transcript$dots',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'This may take a few moments',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsTab extends StatelessWidget {
  final Recording recording;
  final RangeValues selectedRange;
  final bool isExtractingNotes;
  final String? extractedNotes;
  final String? extractionError;
  final List<RecordingNote> savedNotes;
  final Future<void> Function(RecordingNote note) onPlaySavedNote;
  final bool isPlayingRange;
  final VoidCallback onPlaySelectedRange;
  final VoidCallback onExtractNotes;
  final ValueChanged<RangeValues> onRangeChanged;

  const _ActionsTab({
    required this.recording,
    required this.selectedRange,
    required this.isExtractingNotes,
    required this.extractedNotes,
    required this.extractionError,
    required this.savedNotes,
    required this.onPlaySavedNote,
    required this.isPlayingRange,
    required this.onPlaySelectedRange,
    required this.onExtractNotes,
    required this.onRangeChanged,
  });

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio =
        recording.filePath != null && recording.filePath!.isNotEmpty;
    final maxSeconds = recording.duration.inSeconds > 0
        ? recording.duration.inSeconds.toDouble()
        : 1.0;
    final snapTo = maxSeconds < 1 ? 1 : maxSeconds.round();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Play a selection',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Text(
          '${_formatDuration(Duration(seconds: selectedRange.start.round()))} — ${_formatDuration(Duration(seconds: selectedRange.end.round()))}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        RangeSlider(
          values: selectedRange,
          min: 0,
          max: maxSeconds,
          divisions: snapTo,
          labels: RangeLabels(
            _formatDuration(Duration(seconds: selectedRange.start.round())),
            _formatDuration(Duration(seconds: selectedRange.end.round())),
          ),
          onChanged: hasAudio ? onRangeChanged : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: hasAudio ? onPlaySelectedRange : null,
                icon: Icon(
                  isPlayingRange ? Icons.pause : Icons.play_arrow,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                label: Text(
                  hasAudio
                      ? (isPlayingRange ? 'Pause selection' : 'Play selection')
                      : 'No audio available',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  disabledBackgroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: hasAudio && !isExtractingNotes
                    ? onExtractNotes
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    isExtractingNotes ? 'Extracting…' : 'Extract notes',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (extractionError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              extractionError!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          )
        else if (extractedNotes != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Text(
              extractedNotes!,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
          ),
        if (savedNotes.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Saved notes',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...savedNotes.map(
            (note) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_formatDuration(note.start)} — ${_formatDuration(note.end)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    note.text,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                  if (note.clipPath != null) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () {
                        onPlaySavedNote(note);
                      },
                      icon: Icon(
                        Icons.play_circle_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      label: Text(
                        'Play clip',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Actions',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (recording.actions.isEmpty &&
            recording.notes.isEmpty &&
            extractedNotes == null)
          Text(
            'No actions available for this recording.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else if (recording.actions.isNotEmpty)
          ...recording.actions.map(
            (action) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: action.done
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                        width: 2,
                      ),
                      color: action.done
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: action.done
                        ? Text(
                            '✓',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                  fontWeight: FontWeight.w700,
                                ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      action.text,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: action.done
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).textTheme.bodyLarge?.color,
                        decoration: action.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TranslateTab extends StatefulWidget {
  final Recording recording;
  const _TranslateTab({required this.recording});

  @override
  State<_TranslateTab> createState() => _TranslateTabState();
}

class _TranslateTabState extends State<_TranslateTab> {
  final List<TranscriptLine> _transcriptLines = [];
  StreamSubscription<List<TranscriptLine>>? _transcriptionSubscription;
  bool _isTranscriptGenerating = false;
  String? _transcriptError;

  @override
  void initState() {
    super.initState();
    context.read<TranslationBloc>().add(const ResetTranslation());
    _transcriptLines.addAll(widget.recording.transcript);
    if (_transcriptLines.isEmpty) {
      _generateTranscript();
    } else {
      _translateIfReady();
    }
  }

  @override
  void didUpdateWidget(covariant _TranslateTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recording.id != widget.recording.id ||
        oldWidget.recording.transcript != widget.recording.transcript) {
      _transcriptionSubscription?.cancel();
      _transcriptLines
        ..clear()
        ..addAll(widget.recording.transcript);
      _transcriptError = null;
      _isTranscriptGenerating = false;
      context.read<TranslationBloc>().add(const ResetTranslation());
      if (_transcriptLines.isEmpty) {
        _generateTranscript();
      } else {
        _translateIfReady();
      }
    }
  }

  @override
  void dispose() {
    _transcriptionSubscription?.cancel();
    super.dispose();
  }

  Language get _sourceLanguage => languageByCode('en');

  Future<void> _generateTranscript() async {
    if (widget.recording.filePath == null ||
        widget.recording.filePath!.isEmpty) {
      setState(() {
        _transcriptError = 'No audio file available for transcription.';
      });
      return;
    }

    setState(() {
      _isTranscriptGenerating = true;
      _transcriptError = null;
    });

    final stream = TranscriptionService.transcribeAudioStream(
      widget.recording.filePath!,
    );
    _transcriptionSubscription = stream.listen(
      (chunk) {
        if (!mounted) return;
        setState(() {
          _transcriptLines.addAll(chunk);
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isTranscriptGenerating = false;
          _transcriptError =
              'Transcript generation failed: ${error.toString()}';
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isTranscriptGenerating = false;
        });
        _persistTranscript();
        _translateIfReady();
      },
      cancelOnError: true,
    );
  }

  void _translateIfReady() {
    final targetLanguage = context
        .read<TranslationBloc>()
        .state
        .selectedLanguage;
    if (targetLanguage != null && _transcriptLines.isNotEmpty) {
      context.read<TranslationBloc>().add(
        TranslateTranscript(_transcriptLines, _sourceLanguage, targetLanguage),
      );
    }
  }

  void _onTargetSelected(Language language) {
    if (!mounted) return;
    context.read<TranslationBloc>().add(SelectLanguage(language));
    if (_transcriptLines.isNotEmpty) {
      context.read<TranslationBloc>().add(
        TranslateTranscript(_transcriptLines, _sourceLanguage, language),
      );
    }
  }

  Future<void> _persistTranscript() async {
    if (_transcriptLines.isEmpty) return;
    final updatedRecording = widget.recording.copyWith(
      transcript: List<TranscriptLine>.from(_transcriptLines),
    );
    if (mounted) {
      context.read<LibraryBloc>().add(
        UpdateRecordingRequested(updatedRecording),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: context.read<TranslationBloc>(),
      child: BlocBuilder<TranslationBloc, TranslationState>(
        builder: (context, state) {
          final sourceLanguage = _sourceLanguage;
          final selectedLanguage = state.selectedLanguage;
          final isTranslating = state.status == TranslationStatus.translating;
          final hasTranscript = _transcriptLines.isNotEmpty;
          final hasTranslation =
              state.translatedLines != null && selectedLanguage != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Source language',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${sourceLanguage.flag} ${sourceLanguage.name}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'English (US)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () async {
                    await showModalBottomSheet<Language>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => LanguageModal(
                        selectedCode: state.selectedLanguage?.code,
                        onSelect: _onTargetSelected,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.language,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          selectedLanguage != null
                              ? '${selectedLanguage.flag} ${selectedLanguage.name}'
                              : 'Select target language',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_transcriptError != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _transcriptError!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _generateTranscript,
                            child: const Text('Retry transcript generation'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_isTranscriptGenerating)
                  Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Generating transcript...',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (selectedLanguage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Translation will begin after transcript is ready.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  )
                else if (isTranslating)
                  const _ProcessingTranscriptAnimation()
                else if (hasTranscript && !hasTranslation)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Original transcript',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._transcriptLines.map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.speaker,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      letterSpacing: 0.5,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                line.text,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontSize: 15, height: 1.7),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                else if (hasTranslation && state.translatedLines!.isNotEmpty)
                  ...state.translatedLines!.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.speaker,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            line.text,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontSize: 15, height: 1.7),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ORIGINAL (${sourceLanguage.name.toUpperCase()})',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            line.originalSpeaker != null
                                ? '${line.originalSpeaker}: ${line.originalText}'
                                : line.originalText ?? '',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 13,
                                  height: 1.6,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (!hasTranscript)
                  Center(
                    child: Column(
                      children: [
                        const Text('📝', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 12),
                        Text(
                          'Transcript generation is in progress.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedLanguage != null
                              ? 'Translation will begin in ${selectedLanguage.name} once ready.'
                              : 'Select a language to translate once the transcript is ready.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                else
                  Center(
                    child: Column(
                      children: [
                        const Text('🌐', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 12),
                        Text(
                          selectedLanguage != null
                              ? 'Tap the language selector again to translate the transcript.'
                              : 'Choose a language to translate the transcript.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Supports 112 languages',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
