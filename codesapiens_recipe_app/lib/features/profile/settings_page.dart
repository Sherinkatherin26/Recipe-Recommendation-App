import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'preferences_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<PreferencesProvider>(
        builder: (context, preferences, child) {
          return ListView(
            children: [
              // Appearance Section
              _buildSectionHeader(context, 'Appearance'),
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Enable dark theme'),
                value: preferences.isDarkMode,
                onChanged: (value) => preferences.toggleDarkMode(),
              ),
              const Divider(),

              // Dietary Preferences Section
              _buildSectionHeader(context, 'Dietary Preferences'),
              SwitchListTile(
                title: const Text('Vegetarian'),
                subtitle: const Text('Show only vegetarian recipes'),
                value: preferences.isVegetarian,
                onChanged: (value) => preferences.toggleVegetarian(),
              ),
              SwitchListTile(
                title: const Text('Vegan'),
                subtitle: const Text('Show only vegan recipes'),
                value: preferences.isVegan,
                onChanged: (value) => preferences.toggleVegan(),
              ),
              SwitchListTile(
                title: const Text('Gluten-Free'),
                subtitle: const Text('Show only gluten-free recipes'),
                value: preferences.isGlutenFree,
                onChanged: (value) => preferences.toggleGlutenFree(),
              ),
              const Divider(),

              // Notifications Section
              _buildSectionHeader(context, 'Notifications'),
              SwitchListTile(
                title: const Text('Push Notifications'),
                subtitle: const Text('Receive recipe recommendations'),
                value: preferences.notificationsEnabled,
                onChanged: (value) => preferences.toggleNotifications(),
              ),
              const Divider(),

              // Language Section
              _buildSectionHeader(context, 'Language'),
              ListTile(
                title: const Text('Language'),
                subtitle: Text(preferences.language),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLanguageDialog(context, preferences),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  void _showLanguageDialog(
      BuildContext context, PreferencesProvider preferences) {
    final languages = ['English', 'Spanish', 'French', 'German'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages
              .map(
                (lang) => ListTile(
                  title: Text(lang),
                  trailing: preferences.language == lang
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    preferences.setLanguage(lang);
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
