import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/language_settings_service.dart';
import '../services/user_preferences_service.dart';
import '../services/global_settings_service.dart';
import '../services/logging_service.dart';
import '../services/user_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LoggingService _logger = LoggingService();

  // Temporary state for language settings
  Language? _tempTargetLanguage;
  Language? _tempNativeLanguage;
  Language? _tempSupportLanguage1;
  Language? _tempSupportLanguage2;

  // Track if there are unsaved changes
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentSettings();
    });
  }

  void _loadCurrentSettings() {
    final languageSettings =
        Provider.of<LanguageSettings>(context, listen: false);
    setState(() {
      _tempTargetLanguage = languageSettings.targetLanguage;
      _tempNativeLanguage = languageSettings.nativeLanguage;
      _tempSupportLanguage1 = languageSettings.supportLanguage1;
      _tempSupportLanguage2 = languageSettings.supportLanguage2;
    });
  }

  void _markAsChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_hasUnsavedChanges) return;

    try {
      _logger.log(LogCategory.settingsService, 'Saving language settings...');
      _logger.log(LogCategory.settingsService,
          'Target language being saved: ${_tempTargetLanguage?.code}');

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get all required services
      final languageSettings =
          Provider.of<LanguageSettings>(context, listen: false);
      final userPreferencesService =
          Provider.of<UserPreferencesService>(context, listen: false);

      // Update LanguageSettings service
      if (_tempTargetLanguage != null) {
        await languageSettings.setTargetLanguage(_tempTargetLanguage!);
      }
      if (_tempNativeLanguage != null) {
        await languageSettings.setNativeLanguage(_tempNativeLanguage!);
      }
      await languageSettings.setSupportLanguage1(_tempSupportLanguage1);
      await languageSettings.setSupportLanguage2(_tempSupportLanguage2);

      // Update UserPreferencesService
      await userPreferencesService.updateLanguagePreferences(
        targetLanguage: _tempTargetLanguage?.code,
        nativeLanguage: _tempNativeLanguage?.code,
        supportLanguage1: _tempSupportLanguage1?.code,
        supportLanguage2: _tempSupportLanguage2?.code,
      );

      // Force GlobalSettingsService update
      if (GlobalSettingsService.instance.isInitialized) {
        await GlobalSettingsService.instance.updateLanguages(
          targetLanguage: _tempTargetLanguage?.code,
          nativeLanguage: _tempNativeLanguage?.code,
          supportLanguage1: _tempSupportLanguage1?.code,
          supportLanguage2: _tempSupportLanguage2?.code,
        );
      }

      // Force LanguageSettings to notify all listeners
      await languageSettings.reloadAndNotify();

      // Add a small delay to ensure all async operations complete
      await Future.delayed(const Duration(milliseconds: 100));

      setState(() {
        _hasUnsavedChanges = false;
      });

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      _logger.log(
          LogCategory.settingsService, 'Language settings saved successfully');
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );

      _logger.log(
          LogCategory.settingsService, 'Error saving language settings: $e',
          isError: true);
    }
  }

  void _resetToCurrentSettings() {
    _loadCurrentSettings();
    setState(() {
      _hasUnsavedChanges = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_hasUnsavedChanges)
            TextButton(
              onPressed: _resetToCurrentSettings,
              child: const Text('Reset'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAIProviderSection(context),
                const Divider(height: 32),
                _buildLanguageSection(context),
                const Divider(height: 32),
                _buildAnalysisLimitsSection(context),
                // Debug section (only in debug mode)
                if (kDebugMode) ...[
                  const Divider(height: 32),
                  _buildDebugSection(context),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sync status indicator
          Consumer<UserPreferencesService>(
            builder: (context, userPrefsService, child) {
              return FutureBuilder<bool>(
                future: userPrefsService.hasUnsyncedChanges(),
                builder: (context, snapshot) {
                  final hasUnsynced = snapshot.data ?? false;
                  final isLoggedIn =
                      Provider.of<UserService>(context, listen: false)
                          .isLoggedIn;

                  if (!isLoggedIn) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Settings saved locally. Sign in to sync across devices.',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (hasUnsynced) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.sync_problem,
                              color: Colors.orange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Settings not synced to cloud. Tap to sync manually.',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final success =
                                  await userPrefsService.syncToSupabase();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success
                                      ? 'Synced successfully!'
                                      : 'Sync failed'),
                                  backgroundColor:
                                      success ? Colors.green : Colors.red,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              setState(() {}); // Refresh the sync status
                            },
                            child: Text('Sync', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_done, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Settings synced to cloud.',
                            style: TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
          // Save button row
          Row(
            children: [
              if (_hasUnsavedChanges)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetToCurrentSettings,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Reset Changes'),
                  ),
                ),
              if (_hasUnsavedChanges) const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _hasUnsavedChanges ? _saveSettings : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: _hasUnsavedChanges
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).disabledColor,
                  ),
                  child: Text(
                    _hasUnsavedChanges ? 'Save Changes' : 'No Changes',
                    style: TextStyle(
                      color: _hasUnsavedChanges
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
        Row(
          children: [
            const Text(
              'Language Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_hasUnsavedChanges)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Unsaved',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            _buildLanguageDropdown(
              context: context,
              label: 'Language to Learn',
              value: _tempTargetLanguage,
              onChanged: (Language? language) {
                setState(() {
                  _tempTargetLanguage = language;
                });
                _markAsChanged();
              },
            ),
            const SizedBox(height: 16),
            _buildLanguageDropdown(
              context: context,
              label: 'Your Language',
              value: _tempNativeLanguage,
              onChanged: (Language? language) {
                setState(() {
                  _tempNativeLanguage = language;
                });
                _markAsChanged();
              },
            ),
            const SizedBox(height: 16),
            _buildLanguageDropdown(
              context: context,
              label: 'Support Language 1',
              value: _tempSupportLanguage1,
              onChanged: (Language? language) {
                setState(() {
                  _tempSupportLanguage1 = language;
                });
                _markAsChanged();
              },
              allowNull: true,
            ),
            const SizedBox(height: 16),
            _buildLanguageDropdown(
              context: context,
              label: 'Support Language 2',
              value: _tempSupportLanguage2,
              onChanged: (Language? language) {
                setState(() {
                  _tempSupportLanguage2 = language;
                });
                _markAsChanged();
              },
              allowNull: true,
            ),
          ],
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

  // Debug section for testing Supabase integration
  Widget _buildDebugSection(BuildContext context) {
    return Consumer<UserPreferencesService>(
      builder: (context, userPrefsService, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Debug Info',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Service Status:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...userPrefsService.getDebugInfo().entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('${entry.key}: ${entry.value}'),
                          ),
                        ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            await userPrefsService.reload();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Preferences reloaded from Supabase'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Text('Reload from Supabase'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final success =
                                await userPrefsService.syncToSupabase();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success
                                    ? 'Successfully synced to Supabase'
                                    : 'Failed to sync to Supabase'),
                                backgroundColor:
                                    success ? Colors.green : Colors.red,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Text('Force Sync'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
