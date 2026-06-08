import 'package:flutter/material.dart';
import 'main.dart';

class SoccerManagerApp extends StatelessWidget {
  const SoccerManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soccer Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4FC3F7),
          surface: Color(0xFF0C0F1A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0C0F1A),
        useMaterial3: true,
      ),
      home: const _RootRedirect(),
    );
  }
}

class _RootRedirect extends StatelessWidget {
  const _RootRedirect();

  @override
  Widget build(BuildContext context) {
    // Auth screen and HomeScreen are imported lazily to avoid circular imports.
    // The actual routing is handled here based on session state.
    final session = supabase.auth.currentSession;
    if (session != null) {
      // Import deferred to avoid circular deps — loaded at runtime
      return const _HomeLoader();
    }
    return const _AuthLoader();
  }
}

// Placeholder widgets — replaced by actual screens in Task 7+
class _HomeLoader extends StatelessWidget {
  const _HomeLoader();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('Loading...', style: TextStyle(color: Colors.white))),
      );
}

class _AuthLoader extends StatelessWidget {
  const _AuthLoader();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('Auth Screen', style: TextStyle(color: Colors.white))),
      );
}
