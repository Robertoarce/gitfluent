import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'AI Provider',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ...AIProvider.values.map(
                (provider) => RadioListTile<AIProvider>(
                  title: Text(settings.getProviderName(provider)),
                  subtitle: Text('API Key: ${settings.getProviderApiKeyName(provider)}'),
                  value: provider,
                  groupValue: settings.currentProvider,
                  onChanged: (AIProvider? value) {
                    if (value != null) {
                      settings.setProvider(value);
                    }
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Note: Make sure to add the corresponding API key in your .env file.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
} 