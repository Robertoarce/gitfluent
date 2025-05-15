import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'screens/chat_screen.dart';
import 'services/chat_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  final settingsService = SettingsService();
  await settingsService.init();
  
  runApp(MyApp(settingsService: settingsService));
}

class MyApp extends StatelessWidget {
  final SettingsService settingsService;
  
  const MyApp({super.key, required this.settingsService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsService),
        ChangeNotifierProxyProvider<SettingsService, ChatService>(
          create: (context) => ChatService(settings: settingsService),
          update: (context, settings, previous) =>
              ChatService(settings: settings),
        ),
      ],
      child: MaterialApp(
        title: 'LLM Chat App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const ChatScreen(),
      ),
    );
  }
} 