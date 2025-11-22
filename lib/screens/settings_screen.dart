import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../services/user_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final userService = context.watch<UserService>();
    final currentUser = userService.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          _buildSectionHeader('Profile'),
          ShadCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF6B47ED),
                  child: Text(
                    currentUser.email.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser.email,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Member since ${currentUser.createdAt.year}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Language Settings
          _buildSectionHeader('Language Preferences'),
          ShadCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildLanguageTile(
                  title: 'Target Language',
                  subtitle: 'The language you are learning',
                  value: currentUser.targetLanguage,
                  onChanged: (value) {
                    userService.updateLanguagePreferences(
                      targetLanguage: value,
                      nativeLanguage: currentUser.nativeLanguage,
                    );
                  },
                ),
                const Divider(height: 1),
                _buildLanguageTile(
                  title: 'Native Language',
                  subtitle: 'Your primary language',
                  value: currentUser.nativeLanguage,
                  onChanged: (value) {
                    userService.updateLanguagePreferences(
                      targetLanguage: currentUser.targetLanguage,
                      nativeLanguage: value,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Account Actions
          _buildSectionHeader('Account'),
          ShadCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    await userService.signOut();
                    // Navigation is handled by AuthWrapper in main.dart
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildLanguageTile({
    required String title,
    required String subtitle,
    required String value,
    required Function(String) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 'en', child: Text('English')),
          DropdownMenuItem(value: 'es', child: Text('Spanish')),
          DropdownMenuItem(value: 'fr', child: Text('French')),
          DropdownMenuItem(value: 'de', child: Text('German')),
          DropdownMenuItem(value: 'it', child: Text('Italian')),
        ],
        onChanged: (newValue) {
          if (newValue != null && newValue != value) {
            onChanged(newValue);
          }
        },
      ),
    );
  }
}
