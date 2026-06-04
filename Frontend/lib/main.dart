import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const TertibSekolahApp());
}

class TertibSekolahApp extends StatelessWidget {
  const TertibSekolahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tepat Waktu',
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
