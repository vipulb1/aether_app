import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/recording.dart';
import '../bloc/library_bloc.dart';
import '../bloc/library_event.dart';
import '../bloc/library_state.dart';
import '../widgets/recording_card.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: context.read<LibraryBloc>()..add(const LoadRecordings()),
      child: const _LibraryView(),
    );
  }
}

class _LibraryView extends StatefulWidget {
  const _LibraryView();

  @override
  State<_LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<_LibraryView> {
  late ScrollController _scrollController;
  int _itemsToShow = 20;
  final int _itemsPerPage = 20;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      setState(() {
        _itemsToShow += _itemsPerPage;
      });
    }
  }

  String _formatDateForSearch(DateTime dateTime) {
    return '${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  bool _matchesSearchQuery(Recording recording, String query) {
    if (query.isEmpty) return true;

    final lowerQuery = query.toLowerCase();
    final recordingDate = recording.createdAt;

    // Format recording date as MM/DD/YYYY
    final monthStr = recordingDate.month.toString().padLeft(2, '0');
    final dayStr = recordingDate.day.toString().padLeft(2, '0');
    final yearStr = recordingDate.year.toString();

    // Check if query is numeric (for date search)
    final isNumericOnly =
        query.replaceAll('/', '').isEmpty ||
        query
            .replaceAll('/', '')
            .split('')
            .every((c) => int.tryParse(c) != null);

    // Always check name first
    if (recording.title.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    // If not numeric, only name search applies
    if (!isNumericOnly) {
      return false;
    }

    // Date search logic
    if (query.contains('/')) {
      final parts = query.split('/');

      // Pad single digit parts
      final padPart = (String p) =>
          p.isEmpty ? '' : (p.length == 1 ? '0$p' : p);

      if (parts.length == 2) {
        final paddedMonth = padPart(parts[0]);
        final paddedDay = padPart(parts[1]);

        try {
          final month = int.parse(paddedMonth);

          if (paddedDay.isEmpty) {
            // Format: "6/" or "06/" - match by month only
            return month == recordingDate.month;
          } else {
            // Format: "6/2" or "06/25" - match month and partial day
            final recordingDayInt = recordingDate.day;

            // Check if recording month matches
            if (month != recordingDate.month) return false;

            // Check if day matches the pattern
            // "6/2" should match days 20-29 (where day starts with "2")
            // "6/25" should match day 25
            final dayStr = recordingDayInt.toString();
            final queryDayStr = parts[1]; // Use original query day, not padded

            return dayStr.startsWith(queryDayStr);
          }
        } catch (_) {
          return false;
        }
      } else if (parts.length == 3) {
        // Full date format: MM/DD/YYYY or partial year like MM/DD/202
        final paddedMonth = padPart(parts[0]);
        final paddedDay = padPart(parts[1]);
        final yearPart = parts[2]; // Don't pad year for partial matching

        try {
          final month = int.parse(paddedMonth);
          final day = int.parse(paddedDay);

          // Check month and day first
          if (month != recordingDate.month || day != recordingDate.day) {
            return false;
          }

          // For year, support both exact and partial matches
          // "6/25/2026" matches exactly
          // "6/25/202" matches 2020-2029
          // "6/25/20" matches 2000-2099
          final yearStr = recordingDate.year.toString();
          return yearStr.startsWith(yearPart);
        } catch (_) {
          return false;
        }
      }
    } else {
      // Single number - match in month, day, or year
      // "1" should match months 01, 10, 11, 12 and days 01, 10, 11, etc. and years with 1
      return monthStr.contains(query) ||
          dayStr.contains(query) ||
          yearStr.contains(query);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Aether',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
        ),
        // actions: [
        //   IconButton(
        //     icon: Icon(
        //       Icons.notifications_outlined,
        //       color: Theme.of(context).colorScheme.onSurfaceVariant,
        //     ),
        //     onPressed: () {},
        //   ),
        //   IconButton(
        //     icon: Icon(
        //       Icons.person_outline,
        //       color: Theme.of(context).colorScheme.onSurfaceVariant,
        //     ),
        //     onPressed: () {},
        //   ),
        // ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: TextField(
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Search by name or date(MM/DD/YYYY)',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              onChanged: (query) =>
                  context.read<LibraryBloc>().add(SearchQueryChanged(query)),
            ),
          ),
          Expanded(
            child: BlocBuilder<LibraryBloc, LibraryState>(
              builder: (context, state) {
                switch (state.status) {
                  case LibraryStatus.initial:
                  case LibraryStatus.loading:
                    return Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  case LibraryStatus.error:
                    return Center(
                      child: Text(
                        state.errorMessage ?? 'Error',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  case LibraryStatus.empty:
                    return Center(
                      child: Text(
                        'No recordings yet',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  case LibraryStatus.loaded:
                    final list = state.recordings;
                    return _buildRecordingList(
                      context,
                      list,
                      state.searchQuery,
                    );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingList(
    BuildContext context,
    List<Recording> recordings, [
    String searchQuery = '',
  ]) {
    // Sort in descending order by creation date (newest first)
    final sortedRecordings = List<Recording>.from(recordings)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Apply date filtering if search query contains a date
    final filteredByDate = searchQuery.isNotEmpty
        ? sortedRecordings
              .where((r) => _matchesSearchQuery(r, searchQuery))
              .toList()
        : sortedRecordings;

    // Limit the display based on lazy loading
    final displayedRecordings = filteredByDate.take(_itemsToShow).toList();
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
      child: ListView(
        padding: EdgeInsets.only(bottom: 24),
        controller: _scrollController,
        children: [
          // Live recording card
          GestureDetector(
            onTap: () async {
              final result = await Navigator.pushNamed(context, '/recording');
              if (result == true && context.mounted) {
                context.read<LibraryBloc>().add(const LoadRecordings());
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Row(
                children: [
                  const _NewRecordingIcon(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Recording',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to start',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (displayedRecordings.isNotEmpty) ...[
            const SizedBox(height: 4),
            Divider(
              color: Theme.of(context).colorScheme.outline,
              thickness: 1.5,
            ),
            const SizedBox(height: 4),
          ],
          if (displayedRecordings.isNotEmpty)
            ...displayedRecordings.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RecordingCard(
                  recording: r,
                  onTap: () =>
                      Navigator.pushNamed(context, '/detail', arguments: r),
                  onLongPress: () => _showCardMenu(context, r),
                ),
              ),
            ),
          if (displayedRecordings.isEmpty && searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No recordings found',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try searching with different keywords or date\n(MM for month, MM/DD for month & day, MM/DD/YYYY for full date)',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (displayedRecordings.length < filteredByDate.length)
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 20),
              child: Center(
                child: SizedBox(
                  height: 40,
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showCardMenu(BuildContext context, Recording recording) {
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
                recording.title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${recording.typeLabel} · ${recording.formattedDuration}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  recording.bookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: recording.bookmarked
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  recording.bookmarked ? 'Remove bookmark' : 'Bookmark',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  final updatedRecording = recording.copyWith(
                    bookmarked: !recording.bookmarked,
                  );
                  context.read<LibraryBloc>().add(
                    UpdateRecordingRequested(updatedRecording),
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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameDialog(context, recording);
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
                  _confirmDelete(context, recording);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Recording recording) {
    final controller = TextEditingController(text: recording.title);
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
                context.read<LibraryBloc>().add(
                  RenameRecordingRequested(recording.id, newTitle),
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

  void _confirmDelete(BuildContext context, Recording recording) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Delete Recording',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        content: Text(
          'Delete "${recording.title}"? This cannot be undone.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<LibraryBloc>().add(
                DeleteRecordingRequested(recording.id),
              );
              Navigator.pop(ctx);
            },
            child: Text(
              'Delete',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewRecordingIcon extends StatelessWidget {
  const _NewRecordingIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withOpacity(0.3),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '●',
        style: TextStyle(
          fontSize: 18,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}
