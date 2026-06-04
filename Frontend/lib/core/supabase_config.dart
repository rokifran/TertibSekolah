/// Konfigurasi koneksi Supabase untuk aplikasi Tepat Waktu.
///
/// Nilai dibaca dari environment variables yang di-inject saat build/run
/// menggunakan flag `--dart-define-from-file=.env`.
///
/// Cara menjalankan:
///   flutter run --dart-define-from-file=.env
///   flutter build apk --dart-define-from-file=.env
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
  static void validate() {
    assert(
      url.isNotEmpty,
      '\n\n❌ SUPABASE_URL tidak ditemukan!\n'
      'Jalankan dengan: flutter run --dart-define-from-file=.env\n',
    );
    assert(
      anonKey.isNotEmpty,
      '\n\n❌ SUPABASE_ANON_KEY tidak ditemukan!\n'
      'Jalankan dengan: flutter run --dart-define-from-file=.env\n',
    );
  }
}
