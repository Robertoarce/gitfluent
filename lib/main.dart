import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter/foundation.dart'; // Add this import for kDebugMode
import 'config/custom_theme.dart';
import 'services/chat_service.dart';
import 'services/conversation_service.dart';
import 'services/settings_service.dart';
import 'services/language_settings_service.dart';
import 'services/vocabulary_service.dart';
import 'services/flashcard_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/user_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/firebase_database_service.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'models/user.dart' as app_user;
import 'screens/chat_screen.dart';
import 'screens/conversation_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/user_vocabulary_screen.dart';
import 'screens/flashcard_start_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/app_navigation.dart';
import 'utils/debug_helper.dart';
import 'widgets/debug_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize debug helper
  await DebugHelper.initialize();

  try {
    await dotenv.load(fileName: ".env");
    DebugHelper.printDebug('config', 'Environment loaded successfully');

    // Check if required environment variables are present
    final googleApiKey = dotenv.env['GOOGLE_API_KEY'];

    if (googleApiKey == null) {
      DebugHelper.printDebug('config',
          'WARNING: GOOGLE_API_KEY is missing! AI features will not work.');
    }

    // Initialize Firebase
    await Firebase.initializeApp();
    DebugHelper.printDebug('config', 'Firebase initialized successfully');
  } catch (e) {
    DebugHelper.printDebug('config', 'Error initializing app: $e');
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

        // User system services
        Provider<AuthService>(
          create: (_) => FirebaseAuthService(),
        ),
        Provider<DatabaseService>(
          create: (_) => FirebaseDatabaseService(),
        ),
        ChangeNotifierProxyProvider2<AuthService, DatabaseService, UserService>(
          create: (context) {
            final userService = UserService(
              authService: context.read<AuthService>(),
              databaseService: context.read<DatabaseService>(),
            );
            // Auto-login in debug mode
            if (kDebugMode) {
              _debugAutoLogin(userService);
            }
            return userService;
          },
          update: (context, authService, databaseService, previous) {
            if (previous != null) {
              return previous;
            }
            final userService = UserService(
              authService: authService,
              databaseService: databaseService,
            );
            // Auto-login in debug mode
            if (kDebugMode) {
              _debugAutoLogin(userService);
            }
            return userService;
          },
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

        // Flashcard service that depends on both user service and vocabulary service
        ChangeNotifierProxyProvider2<UserService, VocabularyService,
            FlashcardService>(
          create: (context) {
            final flashcardService = FlashcardService();
            flashcardService.setUserService(context.read<UserService>());
            flashcardService
                .setVocabularyService(context.read<VocabularyService>());
            return flashcardService;
          },
          update: (context, userService, vocabularyService, previous) {
            if (previous != null) {
              previous.setUserService(userService);
              previous.setVocabularyService(vocabularyService);
              return previous;
            } else {
              final flashcardService = FlashcardService();
              flashcardService.setUserService(userService);
              flashcardService.setVocabularyService(vocabularyService);
              return flashcardService;
            }
          },
        ),

        // Language settings that sync with user preferences
        ChangeNotifierProxyProvider<UserService, LanguageSettings>(
          create: (context) {
            final languageSettings = LanguageSettings();
            _initializeLanguageSettings(languageSettings);
            languageSettings.setUserService(context.read<UserService>());
            return languageSettings;
          },
          update: (context, userService, previous) {
            if (previous != null) {
              previous.setUserService(userService);
              return previous;
            }
            return previous!;
          },
        ),

        // Chat service depends on both settings service and language settings
        ChangeNotifierProxyProvider2<SettingsService, LanguageSettings,
            ChatService>(
          create: (context) => ChatService(
            settings: context.read<SettingsService>(),
            languageSettings: context.read<LanguageSettings>(),
          ),
          update: (context, settings, languageSettings, previous) =>
              ChatService(
            settings: settings,
            languageSettings: languageSettings,
          ),
        ),

        // Conversation service depends on settings, language settings, and vocabulary service
        ChangeNotifierProxyProvider3<SettingsService, LanguageSettings,
            VocabularyService, ConversationService>(
          create: (context) => ConversationService(
            settings: context.read<SettingsService>(),
            languageSettings: context.read<LanguageSettings>(),
            vocabularyService: context.read<VocabularyService>(),
          ),
          update: (context, settings, languageSettings, vocabularyService,
                  previous) =>
              ConversationService(
            settings: settings,
            languageSettings: languageSettings,
            vocabularyService: vocabularyService,
          ),
        ),
      ],
      child: Consumer<UserService>(
        builder: (context, userService, child) {
          return MaterialApp(
            title: 'AI Language Tutor',
            theme: CustomTheme.lightTheme,
            darkTheme: CustomTheme.darkTheme,
            themeMode: ThemeMode.light,
            home: _buildHome(userService),
            routes: {
              '/auth': (context) => const AuthScreen(),
              '/home': (context) => const AppHome(),
              '/flashcards': (context) => const FlashcardStartScreen(),
              '/vocabulary': (context) => const UserVocabularyScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/conversation': (context) => Consumer3<ConversationService,
                      VocabularyService, LanguageSettings>(
                    builder: (context, conversationService, vocabularyService,
                        languageSettings, child) {
                      return ConversationScreen(
                        conversationService: conversationService,
                        vocabularyService: vocabularyService,
                        languageSettings: languageSettings,
                      );
                    },
                  ),
            },
            builder: (context, child) {
              return DebugOverlay(
                key: debugOverlayKey,
                child: child!,
              );
            },
          );
        },
      ),
    );
  }

  // Helper method to initialize settings service
  static Future<void> _initializeSettingsService(
      SettingsService settingsService) async {
    try {
      await settingsService.init();
      debugPrint('SettingsService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing SettingsService: $e');
    }
  }

  // Helper method to initialize language settings
  static Future<void> _initializeLanguageSettings(
      LanguageSettings languageSettings) async {
    try {
      await languageSettings.init();
      debugPrint('LanguageSettings initialized successfully');
    } catch (e) {
      debugPrint('Error initializing LanguageSettings: $e');
    }
  }

  // Debug auto-login helper method
  static Future<void> _debugAutoLogin(UserService userService) async {
    if (!kDebugMode) return;

    try {
      DebugHelper.printDebug(
          'config', '🚀 DEBUG MODE: Attempting auto-login...');

      const debugEmail = 'test@debug.com';
      const debugPassword = 'debugpassword123';

      // Try to sign in with a test account first
      var result = await userService.signIn(debugEmail, debugPassword);

      if (!result.success) {
        DebugHelper.printDebug(
            'config', '👤 DEBUG AUTO-LOGIN: Test user not found, creating...');

        // Create the test user if login failed
        result = await userService.signUp(
          debugEmail,
          debugPassword,
          'Debug',
          'User',
        );

        if (result.success) {
          DebugHelper.printDebug(
              'config', '✨ DEBUG AUTO-LOGIN: Test user created successfully');
        } else {
          DebugHelper.printDebug('config',
              '❌ DEBUG AUTO-LOGIN: Failed to create test user: ${result.error}');
          return;
        }
      }

      if (result.success) {
        DebugHelper.printDebug('config',
            '✅ DEBUG AUTO-LOGIN: Successfully logged in as test user');

        // Give the system a moment to fully initialize the user
        await Future.delayed(const Duration(milliseconds: 500));

        // Ensure user is premium
        await userService.upgradeToPremium();
        DebugHelper.printDebug(
            'config', '⭐ DEBUG AUTO-LOGIN: User upgraded to premium');

        // Don't override language settings - let them load from database
        DebugHelper.printDebug('config',
            '🌍 DEBUG AUTO-LOGIN: Skipping language override - using database settings');
      } else {
        DebugHelper.printDebug('config',
            '⚠️ DEBUG AUTO-LOGIN: Login failed, continuing without auto-login');
      }
    } catch (e) {
      DebugHelper.printDebug(
          'config', '❌ DEBUG AUTO-LOGIN: Error during auto-login: $e');
      // Continue normally if auto-login fails
    }
  }

  Widget _buildHome(UserService userService) {
    // Show loading while checking auth state
    if (userService.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.grey, // Set background to grey
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show auth screen if not logged in
    if (!userService.isLoggedIn) {
      return const AuthScreen(); // AuthScreen already has a white background
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

    // Initialize flashcard service
    final flashcardService = context.read<FlashcardService>();
    if (!flashcardService.isInitialized) {
      await flashcardService.init();
    }

    // Load user vocabulary from Supabase if logged in
    final userService = context.read<UserService>();
    debugPrint('🔍 AppHome._initializeServices: Checking user login status...');
    debugPrint(
        '🔍 AppHome._initializeServices: User logged in: ${userService.isLoggedIn}');

    if (userService.isLoggedIn) {
      debugPrint(
          '✅ AppHome._initializeServices: User is logged in - ${userService.currentUser?.email}');

      // Check premium status from database to ensure it's up to date
      if (userService.currentUser != null) {
        final isPremium = await context
            .read<DatabaseService>()
            .isPremiumUser(userService.currentUser!.id);
        if (isPremium != userService.isPremium) {
          debugPrint('Updating premium status from database: $isPremium');
          // This will update the user model and trigger UI refresh
          await userService.upgradeToPremium();
        }
      }

      // Language preferences are automatically loaded by LanguageSettings via UserService listener
      // No manual loading needed here - the setUserService() call above handles this automatically
      if (userService.currentUser != null) {
        try {
          debugPrint(
              '🌍 AppHome._initializeServices: Language preferences will be loaded automatically by LanguageSettings listener');
          debugPrint(
              '🌍 AppHome._initializeServices: User preferences: ${userService.currentUser!.preferences.toJson()}');

          final languageSettings = context.read<LanguageSettings>();

          // Log current language settings (these will be updated automatically by the listener)
          debugPrint(
              '🌍 AppHome._initializeServices: Current language settings:');
          debugPrint(
              '   - Target Language: ${languageSettings.targetLanguage?.code} (${languageSettings.targetLanguage?.name})');
          debugPrint(
              '   - Native Language: ${languageSettings.nativeLanguage?.code} (${languageSettings.nativeLanguage?.name})');
          debugPrint(
              '   - Support Language 1: ${languageSettings.supportLanguage1?.code} (${languageSettings.supportLanguage1?.name})');
          debugPrint(
              '   - Support Language 2: ${languageSettings.supportLanguage2?.code} (${languageSettings.supportLanguage2?.name})');

          debugPrint(
              '✅ AppHome._initializeServices: Language preferences loaded successfully from database');
        } catch (e) {
          debugPrint(
              '❌ AppHome._initializeServices: Error loading language preferences from database: $e');
        }
      } else {
        debugPrint(
            '⚠️ AppHome._initializeServices: User is logged in but currentUser is null');
      }

      // Load user vocabulary
      try {
        final items = await vocabularyService.getUserVocabulary();
        debugPrint(
            '✅ AppHome._initializeServices: Loaded ${items.length} vocabulary items from Database');
      } catch (e) {
        debugPrint(
            '❌ AppHome._initializeServices: Error loading vocabulary from Database: $e');
      }
    } else {
      debugPrint(
          '⚠️ AppHome._initializeServices: User not logged in - skipping data loading');
    }
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
            icon: const Icon(Icons.quiz),
            onPressed: () {
              AppNavigation.toFlashcards(context);
            },
            tooltip: 'Study Flashcards',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<UserService>().signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Available Features Section
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Features',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _buildFeatureCard(
                          context,
                          'Study Flashcards',
                          'Practice vocabulary with interactive flashcards',
                          Icons.quiz,
                          Colors.blue,
                          () {
                            AppNavigation.toFlashcards(context);
                          },
                        ),
                        _buildFeatureCard(
                          context,
                          'My Vocabulary',
                          'View and manage your vocabulary collection',
                          Icons.book,
                          Colors.green,
                          () {
                            AppNavigation.toVocabulary(context);
                          },
                        ),
                        _buildFeatureCard(
                          context,
                          'Settings',
                          'Configure your language preferences',
                          Icons.settings,
                          Colors.orange,
                          () {
                            AppNavigation.toSettings(context);
                          },
                        ),
                        _buildFeatureCard(
                          context,
                          'AI Chat',
                          'Upgrade for AI-powered conversations',
                          Icons.chat,
                          Colors.purple,
                          () async {
                            await context
                                .read<UserService>()
                                .upgradeToPremium();
                          },
                          isPremiumFeature: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Premium Upgrade Section
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.shade100,
                          Colors.blue.shade100,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.purple.shade300),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.star,
                          size: 48,
                          color: Colors.purple.shade600,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Upgrade to Premium',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Unlock AI-powered chat features for advanced language learning',
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await context
                                .read<UserService>()
                                .upgradeToPremium();
                          },
                          icon: const Icon(Icons.upgrade),
                          label: const Text('Upgrade Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isPremiumFeature = false,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: color,
                    ),
                  ),
                  if (isPremiumFeature)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.star,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
