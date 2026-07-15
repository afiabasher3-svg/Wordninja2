import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';

const supabaseUrl = 'https://ncxpgtajpyhtdqmqzeud.supabase.co';
const supabaseKey = 'sb_publishable_8H9yZx6lXRhifYD8NwFmzQ_hTzEDfhI';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const WordNinjaApp());
}

class WordNinjaApp extends StatelessWidget {
  const WordNinjaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Word Ninja',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A1A),
      ),
      home: const LoginScreen(),
    );
  }
}
