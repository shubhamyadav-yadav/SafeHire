import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'analyzers/ai_analyzer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Load environment variables ──
  await dotenv.load(fileName: '.env');

  // ── Supabase init ──
  await Supabase.initialize(
    url:     dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await AIAnalyzer.loadModel();
  runApp(ScamShieldApp());
}

class ScamShieldApp extends StatefulWidget {
  @override
  State<ScamShieldApp> createState() => _ScamShieldAppState();
}

class _ScamShieldAppState extends State<ScamShieldApp> {
  bool isDark = true;

  void toggleTheme() => setState(() => isDark = !isDark);

  ThemeData get _darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0A0E1A),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00E5FF),
      secondary: Color(0xFF00E5FF),
      surface: Color(0xFF111827),
      background: Color(0xFF0A0E1A),
    ),
  );

  ThemeData get _lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF0F4F8),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF0077B6),
      secondary: Color(0xFF0077B6),
      surface: Color(0xFFFFFFFF),
      background: Color(0xFFF0F4F8),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScamShield',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: SplashScreen(toggleTheme: toggleTheme, isDark: isDark),
    );
  }
}