import 'package:aether_app/features/library/presentation/bloc/library_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
// import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'core/di/injection_container.dart' as di;
import 'core/theme/app_theme.dart';
import 'core/theme/theme_manager.dart';
import 'features/library/presentation/bloc/library_bloc.dart';
import 'features/library/presentation/pages/library_page.dart';
import 'features/recording/presentation/pages/recording_page.dart';
import 'features/detail/presentation/pages/detail_page.dart';
import 'features/knowledge/presentation/pages/knowledge_page.dart';
import 'features/chat/presentation/pages/chat_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/translation/presentation/bloc/translation_bloc.dart';
import 'features/library/domain/entities/recording.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AetherApp());
}

class AetherApp extends StatefulWidget {
  const AetherApp({super.key});

  @override
  State<AetherApp> createState() => _AetherAppState();
}

class _AetherAppState extends State<AetherApp> {
  late final Future<void> _initializationFuture;
  // late final Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    // _packageInfoFuture = PackageInfo.fromPlatform();
    _initializationFuture = _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Hive.initFlutter();
    await ThemeManager.init();
    await di.initDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: SplashScreen(version: 'Aether v1.0.0'), // Replace with actual version if needed
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: ErrorScreen(error: snapshot.error.toString()),
          );
        }

        return MultiBlocProvider(
          providers: [
            BlocProvider<LibraryBloc>(create: (_) => di.sl<LibraryBloc>()),
            BlocProvider<TranslationBloc>(
              create: (_) => di.sl<TranslationBloc>(),
            ),
          ],
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeManager.mode,
            builder: (context, themeMode, child) {
              return MaterialApp(
                title: 'Aether',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeMode,
                initialRoute: '/',
                onGenerateRoute: (settings) {
                  switch (settings.name) {
                    case '/':
                      return MaterialPageRoute(
                        builder: (_) => const MainShell(),
                      );
                    case '/recording':
                      return MaterialPageRoute(
                        builder: (_) => const RecordingPage(),
                      );
                    case '/detail':
                      final recording = settings.arguments as Recording;
                      return MaterialPageRoute(
                        builder: (_) => DetailPage(recording: recording),
                      );
                    default:
                      return MaterialPageRoute(
                        builder: (_) => const MainShell(),
                      );
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  final String version;
  const SplashScreen({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1B2A),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/splash_logo.svg',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 24),
              const Text(
                'Aether',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                version,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 36),
                child: Text(
                  'Preparing your sound library…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String error;
  const ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1B2A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 72,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Failed to start the app',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Main shell with bottom navigation and center FAB
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    LibraryPage(),
    KnowledgePage(),
    ChatPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.grid_view_rounded,
                  label: 'Library',
                  isActive: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavItem(
                  icon: Icons.hub_outlined,
                  label: 'Knowledge',
                  isActive: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                const SizedBox(width: 52),
                _NavItem(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  isActive: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  isActive: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final libraryBloc = context.read<LibraryBloc>();
          final result = await Navigator.pushNamed(context, '/recording');
          if (!mounted) return;
          if (result == true) {
            setState(() {
              _currentIndex = 0;
            });
            libraryBloc.add(const LoadRecordings());
          }
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        shape: const CircleBorder(),
        child: Icon(
          Icons.circle,
          color: Theme.of(context).colorScheme.onPrimary,
          size: 28,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
