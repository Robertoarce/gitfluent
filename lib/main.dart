import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/chat_service.dart';
import 'services/settings_service.dart';
import 'services/language_settings_service.dart';
import 'services/vocabulary_service.dart';
import 'services/flashcard_service.dart';
import 'services/user_service.dart';
import 'services/supabase_auth_service.dart';
import 'services/supabase_database_service.dart';
import 'models/user.dart' as app_user;
import 'screens/chat_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/user_vocabulary_screen.dart';
import 'screens/flashcard_start_screen.dart';
import 'screens/settings_screen.dart';
import 'config/supabase_config.dart';
import 'utils/flashcard_route_transitions.dart';
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
    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];
    final serviceKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'];

    DebugHelper.printDebug('config', 'Environment check:');
    DebugHelper.printDebug(
        'config', ' - SUPABASE_URL: ${url != null ? 'present' : 'MISSING!'}');
    DebugHelper.printDebug('config',
        ' - SUPABASE_ANON_KEY: ${anonKey != null ? 'present' : 'MISSING!'}');
    DebugHelper.printDebug('config',
        ' - SUPABASE_SERVICE_ROLE_KEY: ${serviceKey != null ? 'present' : 'MISSING!'}');

    if (url == null || anonKey == null || serviceKey == null) {
      DebugHelper.printDebug('config',
          'WARNING: One or more required environment variables are missing!');
      DebugHelper.printDebug(
          'config', 'This will cause issues with Supabase functionality.');
    }
  } catch (e) {
    DebugHelper.printDebug('config', 'Error loading .env file: $e');
    DebugHelper.printDebug(
        'config', 'This will cause issues with Supabase functionality.');
  }

  // Log Supabase configuration
  SupabaseConfig.logConfigInfo();

  // Initialize Supabase
  try {
    DebugHelper.printDebug('config', 'Initializing Supabase...');
    await Supabase.initialize(
      url: SupabaseConfig.projectUrl,
      anonKey: SupabaseConfig.anonKey,
    );
    DebugHelper.printDebug('config', 'Supabase initialized successfully');
  } catch (e) {
    DebugHelper.printDebug('config', 'Error initializing Supabase: $e');
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
        Provider<SupabaseAuthService>(
          create: (_) {
            final authService = SupabaseAuthService();
            authService.initialize();
            return authService;
          },
        ),
        Provider<SupabaseDatabaseService>(
          create: (_) => SupabaseDatabaseService(),
        ),
        ChangeNotifierProxyProvider2<SupabaseAuthService,
            SupabaseDatabaseService, UserService>(
          create: (context) => UserService(
            authService: context.read<SupabaseAuthService>(),
            databaseService: context.read<SupabaseDatabaseService>(),
          ),
          update: (context, authService, databaseService, previous) =>
              previous ??
              UserService(
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
      ],
      child: Consumer<UserService>(
        builder: (context, userService, child) {
          return ShadApp.custom(
            themeMode: ThemeMode.light,
            theme: ShadThemeData(
              brightness: Brightness.light,
              colorScheme: const ShadBlueColorScheme.light(),
            ),
            darkTheme: ShadThemeData(
              brightness: Brightness.dark,
              colorScheme: const ShadBlueColorScheme.dark(),
            ),
            appBuilder: (context) {
              return MaterialApp(
                title: 'GitFluent',
                theme: Theme.of(context),
                home: _buildHome(userService),
                routes: {
                  '/auth': (context) => const AuthScreen(),
                  '/home': (context) => const AppHome(),
                  '/flashcards': (context) => const FlashcardStartScreen(),
                  '/vocabulary': (context) => const UserVocabularyScreen(),
                  '/settings': (context) => const SettingsScreen(),
                },
                builder: (context, child) {
                  return DebugOverlay(
                    key: debugOverlayKey,
                    child: ShadAppBuilder(child: child!),
                  );
                },
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
            .read<SupabaseDatabaseService>()
            .isPremiumUser(userService.currentUser!.id);
        if (isPremium != userService.isPremium) {
          debugPrint('Updating premium status from database: $isPremium');
          // This will update the user model and trigger UI refresh
          await userService.upgradeToPremium();
        }
      }

      // Load language preferences from database
      if (userService.currentUser != null) {
        try {
          debugPrint(
              '🌍 AppHome._initializeServices: Loading language preferences from user profile...');
          debugPrint(
              '🌍 AppHome._initializeServices: User preferences: ${userService.currentUser!.preferences.toJson()}');

          final languageSettings = context.read<LanguageSettings>();

          // Log current language settings before loading from Supabase
          debugPrint(
              '🌍 AppHome._initializeServices: Current language settings BEFORE Supabase load:');
          debugPrint(
              '   - Target Language: ${languageSettings.targetLanguage?.code} (${languageSettings.targetLanguage?.name})');
          debugPrint(
              '   - Native Language: ${languageSettings.nativeLanguage?.code} (${languageSettings.nativeLanguage?.name})');
          debugPrint(
              '   - Support Language 1: ${languageSettings.supportLanguage1?.code} (${languageSettings.supportLanguage1?.name})');
          debugPrint(
              '   - Support Language 2: ${languageSettings.supportLanguage2?.code} (${languageSettings.supportLanguage2?.name})');

          await languageSettings
              .loadFromUserPreferences(userService.currentUser!);

          // Log language settings after loading from Supabase
          debugPrint(
              '🌍 AppHome._initializeServices: Language settings AFTER Supabase load:');
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
            '✅ AppHome._initializeServices: Loaded ${items.length} vocabulary items from Supabase');
      } catch (e) {
        debugPrint(
            '❌ AppHome._initializeServices: Error loading vocabulary from Supabase: $e');
      }
    } else {
      debugPrint(
          '⚠️ AppHome._initializeServices: User not logged in - skipping Supabase data loading');
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
