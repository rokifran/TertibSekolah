import '../main.dart';

class TardinessService {
  /// Memperbarui tardiness_level siswa di tabel users berdasarkan
  /// jumlah tugas keterlambatan yang belum diselesaikan (belum di-graded).
  static Future<void> updateStudentTardinessLevel(String userId) async {
    try {
      // Panggil fungsi RPC 'update_tardiness_level' di Supabase
      // Fungsi ini dijalankan sebagai SECURITY DEFINER sehingga memiliki
      // izin untuk mengubah tabel users yang mungkin dilindungi RLS.
      await supabase.rpc(
        'update_tardiness_level',
        params: {'student_id': userId},
      );
    } catch (e) {
      print('Error updating tardiness level via RPC for user $userId: $e');
    }
  }
}
