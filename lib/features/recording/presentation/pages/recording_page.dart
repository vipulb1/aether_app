import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../library/presentation/bloc/library_bloc.dart';
import '../../../library/presentation/bloc/library_event.dart';
import '../bloc/recording_bloc.dart';
import '../widgets/waveform.dart';

class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  late Future<bool> _permissionsGranted;

  @override
  void initState() {
    super.initState();
    _permissionsGranted = _checkPermissions();
  }

  Future<bool> _checkPermissions() async {
    return await PermissionService.ensure(AppPermission.microphone);
  }

  void _retryPermissions() {
    setState(() {
      _permissionsGranted = _checkPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _permissionsGranted,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }

        if (snapshot.data != true) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              title: Text(
                'Permissions Required',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_open_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Recording needs permission to access the microphone and storage.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please grant permissions to use recording and saving features.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _retryPermissions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('Grant Permissions'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: PermissionService.openSettingsIfNeeded,
                    child: Text(
                      'Open Settings',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return BlocProvider(
          create: (_) => sl<RecordingBloc>(),
          child: const _RecordingView(),
        );
      },
    );
  }
}

class _RecordingView extends StatelessWidget {
  const _RecordingView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecordingBloc, RecordingViewState>(
      listener: (context, state) {
        if (state.status == RecordingStatus.saved) {
          context.read<LibraryBloc>().add(const LoadRecordings());
          Navigator.pop(context, true); // signal library to reload
        }
      },
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
            'Back',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        body: BlocBuilder<RecordingBloc, RecordingViewState>(
          builder: (context, state) {
            if (state.status == RecordingStatus.idle ||
                state.status == RecordingStatus.stopped) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mic_none,
                        size: 68,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        state.status == RecordingStatus.stopped
                            ? 'Recording stopped'
                            : 'Ready to record',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the button below to start capturing audio.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _ActionButton(
                        icon: Icons.fiber_manual_record,
                        isDanger: true,
                        isLarge: true,
                        onTap: () => context.read<RecordingBloc>().add(
                          const StartRecording(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    WaveformWidget(
                      isRecording: state.status == RecordingStatus.recording,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.formattedTime,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontSize: 48,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -1,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (state.status == RecordingStatus.recording)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          state.status == RecordingStatus.recording
                              ? 'Recording'
                              : state.status == RecordingStatus.paused
                              ? 'Paused'
                              : '',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: state.status == RecordingStatus.recording
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => _showRenameDialog(context, state.title),
                      child: Column(
                        children: [
                          Text(
                            state.title,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to rename',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ActionButton(
                          icon: state.status == RecordingStatus.paused
                              ? Icons.play_arrow
                              : Icons.pause,
                          onTap: () {
                            final bloc = context.read<RecordingBloc>();
                            state.status == RecordingStatus.paused
                                ? bloc.add(const ResumeRecording())
                                : bloc.add(const PauseRecording());
                          },
                        ),
                        const SizedBox(width: 24),
                        _ActionButton(
                          icon: Icons.stop,
                          isDanger: true,
                          isLarge: true,
                          onTap: () {
                            // Pause recording before showing stop dialog
                            context.read<RecordingBloc>().add(
                              const PauseRecording(),
                            );
                            Future.delayed(
                              const Duration(milliseconds: 100),
                              () {
                                if (context.mounted) {
                                  _promptStopRecording(context, state.title);
                                }
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 24),
                        _ActionButton(
                          icon: state.bookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          onTap: () => context.read<RecordingBloc>().add(
                            const ToggleBookmarkRecording(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
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
              if (newTitle.isNotEmpty && context.mounted) {
                context.read<RecordingBloc>().add(
                  RenameRecordingTitle(newTitle),
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

  void _promptStopRecording(BuildContext context, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Save Recording',
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
            onPressed: () {
              Navigator.pop(ctx, false);
              // Resume recording on cancel
              if (context.mounted) {
                context.read<RecordingBloc>().add(const ResumeRecording());
              }
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              Navigator.pop(ctx, true);
              if (context.mounted) {
                context.read<RecordingBloc>().add(
                  StopRecording(
                    title: newTitle.isNotEmpty ? newTitle : currentTitle,
                  ),
                );
              }
            },
            child: Text(
              'Save',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDanger;
  final bool isLarge;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    this.isDanger = false,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = isLarge ? 72.0 : 56.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDanger
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          border: isDanger
              ? null
              : Border.all(color: Theme.of(context).colorScheme.outline),
          boxShadow: isDanger
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withOpacity(0.25),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: isDanger
              ? Colors.white
              : Theme.of(context).colorScheme.onSurfaceVariant,
          size: isLarge ? 36 : 28,
        ),
      ),
    );
  }
}
