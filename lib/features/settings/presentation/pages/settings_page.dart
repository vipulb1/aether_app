import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/theme/theme_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = true;
  bool _showUserDetails = true;
  bool _enableNotifications = true;
  bool _isDarkMode = true;
  late Box _settingsBox;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _settingsBox = await Hive.openBox('settings_box');
    setState(() {
      _showUserDetails =
          _settingsBox.get('show_user_details', defaultValue: true) as bool;
      _enableNotifications =
          _settingsBox.get('enable_notifications', defaultValue: true) as bool;
      _isDarkMode = ThemeManager.isDarkMode;
      _loading = false;
    });
  }

  void _updateShowUserDetails(bool value) {
    _settingsBox.put('show_user_details', value);
    setState(() => _showUserDetails = value);
  }

  void _updateEnableNotifications(bool value) {
    _settingsBox.put('enable_notifications', value);
    setState(() => _enableNotifications = value);
  }

  void _updateThemeMode(bool isDark) {
    final newMode = isDark ? ThemeMode.dark : ThemeMode.light;
    ThemeManager.setThemeMode(newMode);
    setState(() => _isDarkMode = isDark);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Preferences',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _showUserDetails,
                  onChanged: _updateShowUserDetails,
                  activeColor: Theme.of(context).colorScheme.primary,
                  title: Text(
                    'Show user details',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    'Display your profile name and avatar across the app',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _enableNotifications,
                  onChanged: _updateEnableNotifications,
                  activeColor: Theme.of(context).colorScheme.primary,
                  title: Text(
                    'Enable notifications',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    'Receive alerts for recordings, updates, and reminders',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isDarkMode,
                  onChanged: _updateThemeMode,
                  activeColor: Theme.of(context).colorScheme.primary,
                  title: Text(
                    'Dark theme',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    'Enable dark or light mode for the app.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Account',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'User details',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    'Your profile information is used to personalize the app.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    Icons.person_outline,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onTap: () {},
                ),
              ],
            ),
    );
  }
}
