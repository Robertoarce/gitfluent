import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/chat_service.dart';
import 'services/settings_service.dart';
import 'services/language_settings_service.dart';
import 'services/vocabulary_service.dart';
import 'services/user_service.dart';
import 'services/local_auth_service.dart';
import 'services/local_database_service.dart';
import 'models/user.dart' as app_user;
import 'screens/chat_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/user_vocabulary_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('Environment loaded successfully');
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core services - need to be initialized
        ChangeNotifierProvider(
          create: (_) {
            final settingsService = SettingsService();
            _initializeSettingsService(settingsService);
            return settingsService;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final languageSettings = LanguageSettings();
            _initializeLanguageSettings(languageSettings);
            return languageSettings;
          },
        ),
        
        // User system services
        Provider<LocalAuthService>(
          create: (_) {
            final authService = LocalAuthService();
            // Initialize and create demo users immediately
            _initializeDemoUsers(authService);
            return authService;
          },
        ),
        Provider<LocalDatabaseService>(
          create: (_) => LocalDatabaseService(),
        ),
        ChangeNotifierProxyProvider2<LocalAuthService, LocalDatabaseService, UserService>(
          create: (context) => UserService(
            authService: context.read<LocalAuthService>(),
            databaseService: context.read<LocalDatabaseService>(),
          ),
          update: (context, authService, databaseService, previous) =>
              previous ?? UserService(
                authService: authService,
                databaseService: databaseService,
              ),
        ),
        
        // Vocabulary service that depends on user service
        ChangeNotifierProxyProvider<UserService, VocabularyService>(
          create: (context) {
            final vocabularyService = VocabularyService();
            vocabularyService.setUserService(context.read<UserService>());
            return vocabularyService;
          },
          update: (context, userService, previous) {
            if (previous != null) {
              previous.setUserService(userService);
              return previous;
            } else {
              final vocabularyService = VocabularyService();
              vocabularyService.setUserService(userService);
              return vocabularyService;
            }
          },
        ),
        
        // Chat service depends on settings service
        ChangeNotifierProxyProvider<SettingsService, ChatService>(
          create: (context) => ChatService(settings: context.read<SettingsService>()),
          update: (context, settings, previous) => ChatService(settings: settings),
        ),
      ],
      child: Consumer<UserService>(
        builder: (context, userService, child) {
          return MaterialApp(
            title: 'GitFluent',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color.fromARGB(255, 71, 175, 227),
              ),
              useMaterial3: true,
            ),
            home: _buildHome(userService),
            routes: {
              '/auth': (context) => const AuthScreen(),
              '/home': (context) => const AppHome(),
            },
          );
        },
      ),
    );
  }

  // Helper method to initialize settings service
  static Future<void> _initializeSettingsService(SettingsService settingsService) async {
    try {
      await settingsService.init();
      debugPrint('SettingsService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing SettingsService: $e');
    }
  }

  // Helper method to initialize language settings
  static Future<void> _initializeLanguageSettings(LanguageSettings languageSettings) async {
    try {
      await languageSettings.init();
      debugPrint('LanguageSettings initialized successfully');
    } catch (e) {
      debugPrint('Error initializing LanguageSettings: $e');
    }
  }

  // Helper method to initialize demo users
  static Future<void> _initializeDemoUsers(LocalAuthService authService) async {
    try {
      await authService.initialize();
      await authService.createTestRegularUser();
      await authService.createTestPremiumUser();
      authService.printDebugInfo();
      debugPrint('Demo users created successfully');
    } catch (e) {
      debugPrint('Error creating demo users: $e');
    }
  }

  Widget _buildHome(UserService userService) {
    // Show loading while checking auth state
    if (userService.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show auth screen if not logged in
    if (!userService.isLoggedIn) {
      return const AuthScreen();
    }

    // Show main app if logged in
    return const AppHome();
  }
}

class AppHome extends StatefulWidget {
  const AppHome({super.key});

  @override
  State<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize vocabulary service
    final vocabularyService = context.read<VocabularyService>();
    if (!vocabularyService.isInitialized) {
      await vocabularyService.init();
    }
    
    // Print debug info
    context.read<LocalAuthService>().printDebugInfo();
    context.read<LocalDatabaseService>().printDebugInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<UserService>(
        builder: (context, userService, child) {
          final user = userService.currentUser;
          
          if (user == null) {
            return const AuthScreen();
          }

          // Check if user is premium for AI features
          if (!user.isPremium) {
            return _buildNonPremiumHome(user);
          }

          // Premium user gets full chat functionality
          return const ChatScreen();
        },
      ),
    );
  }

  Widget _buildNonPremiumHome(app_user.User user) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${user.firstName}!'),
        backgroundColor: const Color.fromARGB(255, 71, 175, 227),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<UserService>().signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                'Premium Feature',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'AI-powered language learning is available for premium users only.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  await context.read<UserService>().upgradeToPremium();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Congratulations! You are now a premium user!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.star),
                label: const Text('Upgrade to Premium'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _showVocabularyHistory(context);
                },
                child: const Text('View Vocabulary History'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVocabularyHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserVocabularyScreen(),
      ),
    );
  }
} 