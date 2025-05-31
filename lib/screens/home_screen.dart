import 'package:flutter/material.dart';
import 'vocabulary_screen.dart';
// import 'conversation_screen.dart'; // Will be added later

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        // The leading hamburger icon to open the drawer is automatically added
        // by Scaffold if a drawer is present.
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                // Optional: Navigate to HomeScreen if not already there, though usually just closing drawer is fine.
                // if (ModalRoute.of(context)?.settings.name != '/') { // Assuming '/' is home route
                //   Navigator.pushReplacementNamed(context, '/');
                // }
              },
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Vocabulary'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const VocabularyScreen()),
                );
              },
            ),
            // ListTile(
            //   leading: const Icon(Icons.chat),
            //   title: const Text('Conversation'),
            //   onTap: () {
            //     Navigator.pop(context); // Close the drawer
            //     // Navigator.push(
            //     //   context,
            //     //   MaterialPageRoute(builder: (context) => const ConversationScreen()), // To be implemented
            //     // );
            //   },
            // ),
          ],
        ),
      ),
      body: const Center(
        child: Text(
          'Welcome to Your App!',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
