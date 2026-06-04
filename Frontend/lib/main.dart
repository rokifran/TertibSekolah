import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_config.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const TertibSekolahApp());
}

/// Shortcut global accessor — gunakan di mana saja:
/// `supabase.from('attendance').select()`
final supabase = Supabase.instance.client;

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
