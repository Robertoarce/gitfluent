import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/language_settings_service.dart';
import '../services/user_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAIProviderSection(context),
          const Divider(height: 32),
          _buildLanguageSection(context),
          const Divider(height: 32),
          _buildAnalysisLimitsSection(context),
        ],
      ),
    );
  }

  Widget _buildAIProviderSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Provider',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Consumer<SettingsService>(
          builder: (context, settings, child) {
            return Column(
              children: AIProvider.values.map((provider) {
                return RadioListTile<AIProvider>(
                  title: Text(settings.getProviderName(provider)),
                  subtitle: Text(
                      'API Key: ${settings.getProviderApiKeyName(provider)}'),
                  value: provider,
                  groupValue: settings.currentProvider,
                  onChanged: (AIProvider? value) {
                    if (value != null) {
                      settings.setProvider(value);
                    }
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLanguageSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Language Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Consumer<LanguageSettings>(
          builder: (context, languageSettings, child) {
            return Column(
              children: [
                // Debug info section
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🔍 Debug: Current Language Settings',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Target: ${languageSettings.targetLanguage?.code} (${languageSettings.targetLanguage?.name ?? 'None'})'),
                      Text(
                          'Native: ${languageSettings.nativeLanguage?.code} (${languageSettings.nativeLanguage?.name ?? 'None'})'),
                      Text(
                          'Support 1: ${languageSettings.supportLanguage1?.code} (${languageSettings.supportLanguage1?.name ?? 'None'})'),
                      Text(
                          'Support 2: ${languageSettings.supportLanguage2?.code} (${languageSettings.supportLanguage2?.name ?? 'None'})'),
                      const SizedBox(height: 4),
                      const Text(
                        'If these show default values (it/en/es/fr) and you have different settings in Supabase, there might be a loading issue.',
                        style: TextStyle(
                            fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final userService = context.read<UserService>();
                          if (userService.isLoggedIn &&
                              userService.currentUser != null) {
                            debugPrint(
                                '🔄 Manual refresh: Loading language preferences from Supabase...');
                            try {
                              await languageSettings.loadFromUserPreferences(
                                  userService.currentUser!);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        '✅ Language preferences refreshed from Supabase'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint('❌ Manual refresh failed: $e');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('❌ Failed to refresh: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    '⚠️ Please log in to refresh from Supabase'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh from Supabase'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontSize: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                ),

                // Supabase preferences debug section
                Consumer<UserService>(
                  builder: (context, userService, child) {
                    if (!userService.isLoggedIn ||
                        userService.currentUser == null) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '⚠️ Not logged in - Cannot show Supabase preferences',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange),
                        ),
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📊 Debug: Raw Supabase User Preferences',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                              'Target Language: "${userService.currentUser!.targetLanguage}"'),
                          Text(
                              'Native Language: "${userService.currentUser!.nativeLanguage}"'),
                          Text(
                              'Support Language 1: "${userService.currentUser!.supportLanguage1 ?? 'null'}"'),
                          Text(
                              'Support Language 2: "${userService.currentUser!.supportLanguage2 ?? 'null'}"'),
                          const SizedBox(height: 4),
                          const Text(
                            'These are the raw values from your Supabase user profile. They should match the Language Settings above.',
                            style: TextStyle(
                                fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                _buildLanguageDropdown(
                  context: context,
                  label: 'Language to Learn',
                  value: languageSettings.targetLanguage,
                  onChanged: (Language? language) {
                    if (language != null) {
                      languageSettings.setTargetLanguage(language);
                    }
                  },
                ),
                const SizedBox(height: 16),
                _buildLanguageDropdown(
                  context: context,
                  label: 'Your Language',
                  value: languageSettings.nativeLanguage,
                  onChanged: (Language? language) {
                    if (language != null) {
                      languageSettings.setNativeLanguage(language);
                    }
                  },
                ),
                const SizedBox(height: 16),
                _buildLanguageDropdown(
                  context: context,
                  label: 'Support Language 1',
                  value: languageSettings.supportLanguage1,
                  onChanged: (Language? language) {
                    languageSettings.setSupportLanguage1(language);
                  },
                  allowNull: true,
                ),
                const SizedBox(height: 16),
                _buildLanguageDropdown(
                  context: context,
                  label: 'Support Language 2',
                  value: languageSettings.supportLanguage2,
                  onChanged: (Language? language) {
                    languageSettings.setSupportLanguage2(language);
                  },
                  allowNull: true,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildLanguageDropdown({
    required BuildContext context,
    required String label,
    required Language? value,
    required void Function(Language?) onChanged,
    bool allowNull = false,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Language>(
          value: value,
          isExpanded: true,
          hint: Text('Select $label'),
          items: [
            if (allowNull)
              const DropdownMenuItem<Language>(
                value: null,
                child: Text('None'),
              ),
            ...LanguageSettings.availableLanguages.map((language) {
              return DropdownMenuItem<Language>(
                value: language,
                child: Text(language.name),
              );
            }),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildAnalysisLimitsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analysis Limits',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Consumer<SettingsService>(
          builder: (context, settings, child) {
            return Column(
              children: [
                _buildLimitSlider(
                  context: context,
                  label: 'Maximum Verbs',
                  value: settings.maxVerbs.toDouble(),
                  min: 1,
                  max: SettingsService.maxVerbsLimit.toDouble(),
                  defaultValue: SettingsService.defaultMaxVerbs,
                  onChanged: (value) => settings.setMaxVerbs(value.round()),
                ),
                const SizedBox(height: 16),
                _buildLimitSlider(
                  context: context,
                  label: 'Maximum Nouns',
                  value: settings.maxNouns.toDouble(),
                  min: 1,
                  max: SettingsService.maxNounsLimit.toDouble(),
                  defaultValue: SettingsService.defaultMaxNouns,
                  onChanged: (value) => settings.setMaxNouns(value.round()),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildLimitSlider({
    required BuildContext context,
    required String label,
    required double value,
    required double min,
    required double max,
    required int defaultValue,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${value.round()} (Default: $defaultValue)',
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).round(),
          label: value.round().toString(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
