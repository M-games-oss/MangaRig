import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MangaRiggerApp());
}

class MangaRiggerApp extends StatelessWidget {
  const MangaRiggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manga Rigger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF101013),
      ),
      home: const HomeScreen(),
    );
  }
}
