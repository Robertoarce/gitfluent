import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'services/auth_service.dart';
import 'services/supabase_auth_service.dart';
import 'services/database_service.dart';
import 'services/supabase_database_service.dart';
import 'services/user_service.dart';
import 'services/translation_service.dart';
import 'services/course_service.dart';
import 'services/chat_service.dart';
import 'services/podcast_service.dart';
import 'widgets/main_nav_shell.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    debugPrint('Environment loaded successfully');
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }

  // Initialize Supabase
  try {
    debugPrint('Initializing Supabase...');
    await Supabase.initialize(
      url: SupabaseConfig.projectUrl,
      anonKey: SupabaseConfig.anonKey,
    );
    debugPrint('-------------Supabase initialized successfully-------------');
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
        // Auth Service
        Provider<AuthService>(
          create: (_) {
            final authService = SupabaseAuthService();
            authService.initialize();
            return authService;
          },
        ),
        // Database Service
        Provider<DatabaseService>(
          create: (_) => SupabaseDatabaseService(),
        ),
        // User Service (depends on Auth and Database)
        ChangeNotifierProxyProvider2<AuthService, DatabaseService, UserService>(
          create: (context) => UserService(
            authService: Provider.of<AuthService>(context, listen: false),
            databaseService: Provider.of<DatabaseService>(context, listen: false),
          ),
          update: (context, auth, db, previous) =>
              previous ?? UserService(authService: auth, databaseService: db),
        ),
        // Translation Service
        Provider<TranslationService>(
          create: (_) => TranslationService(),
        ),
        // Course Service
        Provider<CourseService>(
          create: (_) => CourseService(),
        ),
        // Chat Service
        ChangeNotifierProvider<ChatService>(
          create: (_) => ChatService(),
        ),
        // Podcast Service
        Provider<PodcastService>(
          create: (_) => PodcastService(),
        ),
      ],
      child: MaterialApp(
        title: 'GitFluent',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
        routes: {
          '/home': (context) => const MainNavShell(),
          '/auth': (context) => const AuthScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          return const MainNavShell();
        }
        
        return const AuthScreen();
      },
    );
  }
}
