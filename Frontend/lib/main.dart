import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_config.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';

import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pastikan env vars tersedia sebelum inisialisasi
  SupabaseConfig.validate();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  await initializeDateFormatting('id_ID', null);

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
