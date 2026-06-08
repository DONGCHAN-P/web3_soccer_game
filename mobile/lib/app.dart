import 'package:flutter/material.dart';
import 'main.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

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
      home: supabase.auth.currentSession != null
          ? const HomeScreen()
          : const AuthScreen(),
    );
  }
}
