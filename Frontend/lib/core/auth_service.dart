import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

/// Hasil login yang membawa data user dan role-nya.
class AuthResult {
  final String userId;
  final String nama;
  final String email;
  final String roleName; // 'Admin', 'Guru', 'Siswa'

  const AuthResult({
    required this.userId,
    required this.nama,
    required this.email,
    required this.roleName,
  });

  bool get isAdmin => roleName == 'Admin';
  bool get isGuru => roleName == 'Guru';
  bool get isSiswa => roleName == 'Siswa';
}

/// Exception khusus untuk error autentikasi yang bisa ditampilkan ke user.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Service untuk menangani semua operasi autentikasi.
class AuthService {
  AuthService._();

  /// Sign in menggunakan email & password, lalu ambil data role dari tabel users.
  ///
  /// Throws [AuthException] jika:
  /// - Kredensial salah
  /// - Akun tidak ditemukan di tabel users
  /// - Koneksi gagal
  static Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Autentikasi via Supabase Auth
      final response = await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException('Login gagal. Silakan coba lagi.');
      }

      // 2. Ambil data profile + role via RPC (bypass RLS dengan SECURITY DEFINER)
      //    Query langsung ke tabel users menyebabkan infinite recursion di RLS policy.
      final dynamic rpcResult = await supabase.rpc('get_my_profile');

      if (rpcResult == null) {
        // User ada di Auth tapi tidak ada di tabel users
        await supabase.auth.signOut();
        throw const AuthException(
          'Akun tidak terdaftar dalam sistem.\nHubungi administrator.',
        );
      }

      final userData = rpcResult as Map<String, dynamic>;
      final roleName = userData['role_name'] as String? ?? 'Unknown';

      return AuthResult(
        userId: user.id,
        nama: userData['nama'] as String? ?? '',
        email: userData['email'] as String? ?? email,
        roleName: roleName,
      );
    } on AuthException {
      rethrow;
    } on AuthApiException catch (e) {
      // Error dari Supabase Auth (kredensial salah, dll.)
      if (e.message.contains('Invalid login credentials')) {
        throw const AuthException('Email atau password salah.');
      }
      if (e.message.contains('Email not confirmed')) {
        throw const AuthException('Email belum dikonfirmasi. Cek inbox Anda.');
      }
      throw AuthException('Login gagal: ${e.message}');
    } catch (e) {
      throw AuthException('Terjadi kesalahan: ${e.toString()}');
    }
  }

  /// Sign out user yang sedang login.
  static Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  /// Mengecek apakah ada session aktif (user sudah login sebelumnya).
  static Session? get currentSession => supabase.auth.currentSession;
}
