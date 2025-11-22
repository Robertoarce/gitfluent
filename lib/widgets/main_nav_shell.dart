import 'package:flutter/material.dart';
import '../screens/translation_screen.dart';
import '../screens/review_screen.dart';
import '../screens/learn_screen.dart';
import '../screens/conversation_screen.dart';
import '../screens/podcast_screen.dart';
import '../screens/settings_screen.dart';

class MainNavShell extends StatefulWidget {
  const MainNavShell({super.key});

  @override
  State<MainNavShell> createState() => _MainNavShellState();
}

class _MainNavShellState extends State<MainNavShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TranslationScreen(),
    ReviewScreen(),
    LearnScreen(),
    ConversationScreen(),
    PodcastScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.translate),
            label: 'Translate',
          ),
          NavigationDestination(
            icon: Icon(Icons.rate_review),
            label: 'Review',
          ),
          NavigationDestination(
            icon: Icon(Icons.school),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.podcasts),
            label: 'Podcast',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
