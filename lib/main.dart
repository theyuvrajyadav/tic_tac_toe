import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tic_tac_toe/splash_screen.dart';
import 'package:tic_tac_toe/tic_tac_toe_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(AppRoot(prefs: prefs));
}

class AppRoot extends StatelessWidget {
  final SharedPreferences prefs;
  const AppRoot({required this.prefs, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(prefs: prefs), // 👈 splash first
    );
  }
}

class MyApp extends StatefulWidget {
  final SharedPreferences prefs;
  const MyApp({required this.prefs, Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _mode = ThemeMode.light;

  Color _seedColor = Colors.deepOrange;
  final List<Color> _seeds = [
    Colors.deepOrange,
    Colors.teal,
    Colors.purple,
    Colors.indigo,
    Colors.green,
  ];
  int _accentIndex = 0;

  void _toggleThemeMode() {
    setState(() {
      if (_mode == ThemeMode.light) {
        _mode = ThemeMode.dark;
      } else if (_mode == ThemeMode.dark) {
        _mode = ThemeMode.system;
      } else {
        _mode = ThemeMode.light;
      }
    });
  }

  void _cycleAccent() {
    setState(() {
      _accentIndex = (_accentIndex + 1) % _seeds.length;
      _seedColor = _seeds[_accentIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tic Tac Toe',
      themeMode: _mode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light, // 👈 Force same brightness
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark, // 👈 Force same brightness
        ),
        useMaterial3: true,
      ),
      home: TicTacToePage(
        prefs: widget.prefs,
        onToggleTheme: _toggleThemeMode,
        onCycleAccent: _cycleAccent,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
