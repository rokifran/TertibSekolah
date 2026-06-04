import 'package:flutter/foundation.dart';

/// Konfigurasi koneksi Supabase untuk aplikasi Tepat Waktu.
///
/// Nilai dibaca dari environment variables yang di-inject saat build/run
/// menggunakan flag `--dart-define-from-file=.env`.
///
/// Cara menjalankan:
///   flutter run --dart-define-from-file=.env
///   flutter build apk --dart-define-from-file=.env
///
/// Atau gunakan VS Code debug config di `.vscode/launch.json` — args sudah
/// dikonfigurasi otomatis, cukup tekan F5 atau pilih "Debug (dengan .env)".
///
/// Jangan pernah hardcode credentials di sini — gunakan file `.env` (gitignored).
class SupabaseConfig {
  SupabaseConfig._(); // prevent instantiation

  /// Project URL — dibaca dari SUPABASE_URL di file .env
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Anon / Public Key — dibaca dari SUPABASE_ANON_KEY di file .env
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Validasi bahwa env vars sudah ter-set dengan benar.
  /// Dipanggil di main() sebelum Supabase.initialize().
  ///
  /// Tidak menggunakan assert() agar tidak crash dengan popup yang membingungkan.
  /// Lempar Exception biasa yang bisa ditampilkan di console dengan pesan jelas.
  static void validate() {
    final List<String> missing = [];

    if (url.isEmpty) missing.add('SUPABASE_URL');
    if (anonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');

    if (missing.isEmpty) return; // semua env vars tersedia

    const message =
        '\n'
        '╔══════════════════════════════════════════════════════╗\n'
        '║         ❌  ENV VARS TIDAK DITEMUKAN                 ║\n'
        '╠══════════════════════════════════════════════════════╣\n'
        '║  Solusi:                                             ║\n'
        '║  1. Di VS Code → tekan F5 → pilih                   ║\n'
        '║     "Debug (dengan .env)"                            ║\n'
        '║  2. Atau jalankan di terminal:                       ║\n'
        '║     flutter run --dart-define-from-file=.env         ║\n'
        '║                                                      ║\n'
        '║  Pastikan file .env ada di folder Frontend/          ║\n'
        '╚══════════════════════════════════════════════════════╝\n';

    if (kDebugMode) debugPrint(message);

    throw Exception(
      'Env vars tidak dikonfigurasi: ${missing.join(', ')}. '
      'Jalankan: flutter run --dart-define-from-file=.env',
    );
  }
}
