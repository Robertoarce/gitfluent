import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/chat_service.dart';
import 'services/logging_service.dart';
import 'services/settings_service.dart';
import 'services/language_settings_service.dart';
import 'services/vocabulary_service.dart';
import 'services/user_service.dart';
import 'services/supabase_auth_service.dart';
import 'services/supabase_database_service.dart';
import 'services/conversation_service.dart';
import 'models/user.dart' as app_user;
import 'screens/chat_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/user_vocabulary_screen.dart';
import 'screens/vocabulary_screen.dart';
import 'screens/conversation_screen.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize LoggingService early
  await LoggingService().init();
  final logger = LoggingService();

  try {
    await dotenv.load(fileName: ".env");
    logger.log(LogCategory.appLifecycle, 'Environment loaded successfully');

    // Check if required environment variables are present
    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];
    final serviceKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'];

    logger.log(LogCategory.appLifecycle, 'Environment check:');
    logger.log(LogCategory.appLifecycle,
        ' - SUPABASE_URL: ${url != null ? 'present' : 'MISSING!'}');
    logger.log(LogCategory.appLifecycle,
        ' - SUPABASE_ANON_KEY: ${anonKey != null ? 'present' : 'MISSING!'}');
    logger.log(LogCategory.appLifecycle,
        ' - SUPABASE_SERVICE_ROLE_KEY: ${serviceKey != null ? 'present' : 'MISSING!'}');

    if (url == null || anonKey == null || serviceKey == null) {
      logger.log(LogCategory.appLifecycle,
          'WARNING: One or more required environment variables are missing!',
          isError: true);
      logger.log(LogCategory.appLifecycle,
          'This will cause issues with Supabase functionality.',
          isError: true);
    }
  } catch (e) {
    logger.log(LogCategory.appLifecycle, 'Error loading .env file: $e',
        isError: true);
    logger.log(LogCategory.appLifecycle,
        'This will cause issues with Supabase functionality.',
        isError: true);
  }

  // Log Supabase configuration
  SupabaseConfig.logConfigInfo();

  // Initialize Supabase
  try {
    logger.log(LogCategory.supabase, 'Initializing Supabase...');
    await Supabase.initialize(
      url: SupabaseConfig.projectUrl,
      anonKey: SupabaseConfig.anonKey,
      debug: false,
    );
    logger.log(LogCategory.supabase, 'Supabase initialized successfully');
  } catch (e) {
    logger.log(LogCategory.supabase, 'Error initializing Supabase: $e',
        isError: true);
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

        // Chat service depends on settings service
        ChangeNotifierProxyProvider<SettingsService, ChatService>(
          create: (context) =>
              ChatService(settings: context.read<SettingsService>()),
          update: (context, settings, previous) =>
              ChatService(settings: settings),
        ),
        // Add ConversationService provider
        ChangeNotifierProxyProvider<SettingsService, ConversationService>(
          create: (context) =>
              ConversationService(settings: context.read<SettingsService>()),
          update: (context, settings, previous) => ConversationService(
              settings: settings), // Or manage state update if needed
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
    final logger = LoggingService();
    try {
      await settingsService.init();
      logger.log(LogCategory.settingsService,
          'SettingsService initialized successfully');
    } catch (e) {
      logger.log(
          LogCategory.settingsService, 'Error initializing SettingsService: $e',
          isError: true);
    }
  }

  // Helper method to initialize language settings
  static Future<void> _initializeLanguageSettings(
      LanguageSettings languageSettings) async {
    final logger = LoggingService();
    try {
      await languageSettings.init();
      logger.log(LogCategory.settingsService,
          'LanguageSettings initialized successfully');
    } catch (e) {
      logger.log(LogCategory.settingsService,
          'Error initializing LanguageSettings: $e',
          isError: true);
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

// Import TranslationScreen if not already imported
// import './screens/vocabulary_screen.dart'; // Updated comment
// Import ConversationScreen later
// import './screens/conversation_screen.dart';

class AppHome extends StatefulWidget {
  const AppHome({super.key});

  @override
  State<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  // Add a key for the Scaffold to allow opening the drawer programmatically if needed
  // final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // Removed

  // State to manage which screen is currently displayed in the body
  int _selectedIndex = 0; // 0 for Chat, 1 for Vocabulary
  bool _isConversationScreenActive = false;

  // Screens to be displayed in the body
  static final List<Widget> _widgetOptions = <Widget>[
    const ChatScreen(), // Removed scaffoldKey
    const VocabularyScreen(),
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      // Conversation tab
      setState(() {
        _isConversationScreenActive = true;
      });
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ConversationScreen()),
      ).then((_) {
        // When ConversationScreen is popped, set _isConversationScreenActive back to false
        setState(() {
          _isConversationScreenActive = false;
        });
      });
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

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
      logger.log(LogCategory.appLifecycle,
          'Loading vocabulary for user: ${userService.currentUser?.email}');

      // Check premium status from database to ensure it's up to date
      if (userService.currentUser != null) {
        final isPremium = await context
            .read<SupabaseDatabaseService>()
            .isPremiumUser(userService.currentUser!.id);
        if (isPremium != userService.isPremium) {
          logger.log(LogCategory.appLifecycle,
              'Updating premium status from database: $isPremium');
          // This will update the user model and trigger UI refresh
          await userService
              .upgradeToPremium(); // or a method to just update the status
        }
      }

      // Load user vocabulary (this was already here, seems fine)
      try {
        // final items = await vocabularyService.getUserVocabulary(); // This now happens in vocab service init
        // debugPrint('Loaded ${items.length} vocabulary items from Supabase');
      } catch (e) {
        logger.log(LogCategory.appLifecycle,
            'Error loading vocabulary from Supabase: $e');
      }
    }
    // Ensure the UI rebuilds if needed after services are initialized
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // key: _scaffoldKey, // Assign the key // Removed
      // drawer: Drawer( // Removed Drawer
      //   child: ListView(
      //     padding: EdgeInsets.zero,
      //     children: <Widget>[
      //       const DrawerHeader(
      //         decoration: BoxDecoration(
      //           color: Colors.blue, // Or use Theme.of(context).primaryColor
      //         ),
      //         child: Text(
      //           'Menu',
      //           style: TextStyle(
      //             color: Colors.white,
      //             fontSize: 24,
      //           ),
      //         ),
      //       ),
      //       ListTile(
      //         leading: const Icon(Icons.chat_bubble_outline), // Icon for Chat
      //         title: const Text('Chat'),
      //         onTap: () {
      //           Navigator.pop(context); // Close the drawer
      //           setState(() {
      //             // _currentScreen = const ChatScreen(); // Switch to ChatScreen
      //             // No need to change _currentScreen as it's now a method returning ChatScreen with key
      //           });
      //         },
      //       ),
      //       ListTile(
      //         leading: const Icon(Icons.translate),
      //         title: const Text('Vocabulary'),
      //         onTap: () {
      //           Navigator.pop(context); // Close the drawer
      //           Navigator.push(
      //             context,
      //             MaterialPageRoute(
      //                 builder: (context) => const VocabularyScreen()),
      //           );
      //         },
      //       ),
      //       ListTile(
      //         leading: const Icon(Icons.speaker_notes), // Icon for Conversation
      //         title: const Text('Conversation'),
      //         onTap: () {
      //           Navigator.pop(context); // Close the drawer
      //           Navigator.push(
      //             context,
      //             MaterialPageRoute(
      //                 builder: (context) => const ConversationScreen()),
      //           );
      //         },
      //       ),
      //     ],
      //   ),
      // ),
      body: IndexedStack(
        // Use IndexedStack to keep state of screens
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: _isConversationScreenActive
          ? null // Hide BottomNavigationBar when ConversationScreen is active
          : BottomNavigationBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline),
                  label: 'Chat',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.translate),
                  label: 'Vocabulary',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.speaker_notes),
                  label: 'Conversation',
                ),
              ],
              currentIndex: _selectedIndex,
              selectedItemColor: Theme.of(context).primaryColor,
              onTap: _onItemTapped,
            ),
    );
  }
}

// REMOVE the following if AppHome is now the main scaffold.
// We will keep home_screen.dart for now, but it might not be directly used in main.dart routes.
// Ensure correct imports at the top of main.dart
// import 'screens/home_screen.dart'; // This line might be removed or changed
// import 'screens/chat_screen.dart'; // Already there
// import 'screens/vocabulary_screen.dart'; // Updated comment


// ... The rest of your main.dart code ... 