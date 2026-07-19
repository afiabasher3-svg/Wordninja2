import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reset_password_screen.dart';

const supabaseUrl = 'https://ncxpgtajpyhtdqmqzeud.supabase.co';
const supabaseKey = 'sb_publishable_8H9yZx6lXRhifYD8NwFmzQ_hTzEDfhI';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const WordNinjaApp());
}

class WordNinjaApp extends StatefulWidget {
  const WordNinjaApp({super.key});

  @override
  State<WordNinjaApp> createState() => _WordNinjaAppState();
}

class _WordNinjaAppState extends State<WordNinjaApp> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return MaterialApp(
      title: 'Word Ninja',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A1A),
      ),
      home: session != null ? const HomeScreen() : const LoginScreen(),
    );
  }
}
