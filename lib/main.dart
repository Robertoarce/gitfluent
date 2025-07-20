import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/chat_service.dart';
import 'services/settings_service.dart';
import 'services/language_settings_service.dart';
import 'services/vocabulary_service.dart';
import 'services/user_service.dart';
import 'services/supabase_auth_service.dart';
import 'services/supabase_database_service.dart';
import 'models/user.dart' as app_user;
import 'screens/chat_screen.dart';
import 'screens/auth_screen.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    debugPrint('Environment loaded successfully');

    // Check if required environment variables are present
    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];
    final serviceKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'];

    debugPrint('Environment check:');
    debugPrint(' - SUPABASE_URL: ${url != null ? 'present' : 'MISSING!'}');
    debugPrint(
        ' - SUPABASE_ANON_KEY: ${anonKey != null ? 'present' : 'MISSING!'}');
    debugPrint(
        ' - SUPABASE_SERVICE_ROLE_KEY: ${serviceKey != null ? 'present' : 'MISSING!'}');

    if (url == null || anonKey == null || serviceKey == null) {
      debugPrint(
          'WARNING: One or more required environment variables are missing!');
      debugPrint('This will cause issues with Supabase functionality.');
    }
  } catch (e) {
    debugPrint('Error loading .env file: $e');
    debugPrint('This will cause issues with Supabase functionality.');
  }

  // Log Supabase configuration
  SupabaseConfig.logConfigInfo();

  // Initialize Supabase
  try {
    debugPrint('Initializing Supabase...');
    await Supabase.initialize(
      url: SupabaseConfig.projectUrl,
      anonKey: SupabaseConfig.anonKey,
    );
    debugPrint('Supabase initialized successfully');
  } catch (e) {
    debugPrint('Error initializing Supabase: $e');
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

        // Language settings that sync with user preferences
        ChangeNotifierProxyProvider<UserService, LanguageSettings>(
          create: (context) {
            final languageSettings = context.read<LanguageSettings>();
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

        // Chat service depends on settings service
        ChangeNotifierProxyProvider<SettingsService, ChatService>(
          create: (context) =>
              ChatService(settings: context.read<SettingsService>()),
          update: (context, settings, previous) =>
              ChatService(settings: settings),
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
                },
                builder: (context, child) {
                  return ShadAppBuilder(child: child!);
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

    // Load user vocabulary from Supabase if logged in
    final userService = context.read<UserService>();
    if (userService.isLoggedIn) {
      debugPrint(
          'Loading vocabulary for user: ${userService.currentUser?.email}');

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
          final languageSettings = context.read<LanguageSettings>();
          await languageSettings
              .loadFromUserPreferences(userService.currentUser!.preferences);
          debugPrint('Loaded language preferences from database');
        } catch (e) {
          debugPrint('Error loading language preferences from database: $e');
        }
      }

      // Load user vocabulary
      try {
        final items = await vocabularyService.getUserVocabulary();
        debugPrint('Loaded ${items.length} vocabulary items from Supabase');
      } catch (e) {
        debugPrint('Error loading vocabulary from Supabase: $e');
      }
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
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<UserService>().signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Upgrade to Premium',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Get access to AI-powered chat features',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                await context.read<UserService>().upgradeToPremium();
              },
              child: const Text('Upgrade Now'),
            ),
          ],
        ),
      ),
    );
  }
}
