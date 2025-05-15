import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/language_settings_service.dart';

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
                  subtitle: Text('API Key: ${settings.getProviderApiKeyName(provider)}'),
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
} 