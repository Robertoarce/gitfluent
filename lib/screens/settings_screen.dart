import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/language_settings_service.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import '../utils/debug_helper.dart';
import '../widgets/debug_overlay.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
          _buildDebugSection(context),
          const Divider(height: 32),
          _buildAnalysisLimitsSection(context),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _testDebugOutput,
        icon: const Icon(Icons.bug_report),
        label: const Text('Test Debug'),
        tooltip: 'Test debug output for all enabled sections',
      ),
    );
  }

  void _testDebugOutput() {
    final sections = DebugHelper.getAllSections();
    int enabledCount = 0;

    // Test debug output for all sections
    for (final entry in sections.entries) {
      final testMessage =
          '🔧 Testing ${entry.key.replaceAll('_', ' ').toUpperCase()} debug output from Settings';
      DebugHelper.printDebug(entry.key, testMessage);

      // Also add to overlay if section is enabled
      if (entry.value) {
        addDebugMessageToOverlay(entry.key, testMessage);
        enabledCount++;
      }
    }

    // Show feedback to user
    final message = enabledCount > 0
        ? '🔧 Debug test sent to $enabledCount enabled sections! Check console/logs and debug overlay.'
        : '⚠️ No debug sections are enabled. Enable some sections first.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        backgroundColor: enabledCount > 0 ? Colors.green : Colors.orange,
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
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final chatService = context.read<ChatService>();
                          debugPrint('🔧 DEBUG: Force updating ChatService...');
                          await chatService.forceUpdateLanguageSettings();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    '🔧 ChatService force updated - check debug logs'),
                                backgroundColor: Colors.purple,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text('Force Update ChatService'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
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

                    final user = userService.currentUser!;
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
                            '📊 Debug: Raw Supabase User Language Settings',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Target Language: "${user.targetLanguage}"'),
                          Text('Native Language: "${user.nativeLanguage}"'),
                          Text(
                              'Support Language 1: "${user.supportLanguage1 ?? 'null'}"'),
                          Text(
                              'Support Language 2: "${user.supportLanguage2 ?? 'null'}"'),
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
                      // Enhanced debug logging for Scenario 3 testing
                      debugPrint(
                          '🎯 SCENARIO 3 TEST: User changing target language');
                      debugPrint(
                          '   FROM: ${languageSettings.targetLanguage?.code} (${languageSettings.targetLanguage?.name})');
                      debugPrint('   TO: ${language.code} (${language.name})');
                      debugPrint('   Timestamp: ${DateTime.now()}');

                      // Add debug message to overlay if available
                      addDebugMessageToOverlay('language_settings',
                          '🎯 SCENARIO 3: Target language changing FROM ${languageSettings.targetLanguage?.name} TO ${language.name}');

                      // Trigger the actual language change
                      languageSettings.setTargetLanguage(language);

                      debugPrint(
                          '✅ SCENARIO 3 TEST: setTargetLanguage() called, waiting for updates...');
                      addDebugMessageToOverlay('language_settings',
                          '✅ SCENARIO 3: Language change triggered, watch for updates!');
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

  Widget _buildDebugSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Debug Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Control debug output in real-time. Changes are saved automatically.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, bool>>(
          future: _getDebugSections(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text('Error loading debug settings: ${snapshot.error}');
            }

            final sections = snapshot.data ?? {};

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status summary
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Status: ${DebugHelper.getStatusSummary()}',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await DebugHelper.enableAll();
                          if (context.mounted) {
                            setState(() {});
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Enable All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await DebugHelper.disableAll();
                          if (context.mounted) {
                            setState(() {});
                          }
                        },
                        icon: const Icon(Icons.block),
                        label: const Text('Disable All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await DebugHelper.resetToDefaults();
                      if (context.mounted) {
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset to Defaults'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Individual section toggles
                const Text(
                  'Debug Sections',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...sections.entries
                    .map(
                      (entry) => Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: SwitchListTile(
                          title: Text(
                            entry.key.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            _getDebugSectionDescription(entry.key),
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: entry.value,
                          onChanged: (bool value) async {
                            await DebugHelper.setSection(entry.key, value);
                            if (context.mounted) {
                              setState(() {});
                            }
                          },
                        ),
                      ),
                    )
                    .toList(),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<Map<String, bool>> _getDebugSections() async {
    if (!DebugHelper.isEnabled('config')) {
      await DebugHelper.initialize();
    }
    return DebugHelper.getAllSections();
  }

  String _getDebugSectionDescription(String section) {
    switch (section) {
      case 'supabase':
        return 'Database operations, user management, data sync';
      case 'chat_service':
        return 'AI chat, prompt handling, LLM responses';
      case 'user_service':
        return 'User authentication, profile management';
      case 'vocabulary_service':
        return 'Vocabulary storage, flashcards, learning data';
      case 'auth_service':
        return 'Login/logout, authentication flows';
      case 'flashcard_service':
        return 'Flashcard generation, study sessions';
      case 'language_settings':
        return 'Language preferences, locale changes';
      case 'llm_output_formatter':
        return 'AI response formatting, JSON parsing';
      case 'nlp_service':
        return 'Natural language processing, text analysis';
      case 'accessibility':
        return 'Screen reader announcements, accessibility features';
      case 'config':
        return 'Configuration loading, app initialization';
      case 'general':
        return 'General app operations, misc debugging';
      default:
        return 'Debug output for ${section.replaceAll('_', ' ')}';
    }
  }
}
