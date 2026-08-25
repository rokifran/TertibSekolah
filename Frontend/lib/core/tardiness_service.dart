class TardinessService {
  /// Memperbarui tardiness_level siswa di tabel users berdasarkan
  /// jumlah tugas keterlambatan yang belum diselesaikan (belum di-graded).
  static Future<void> updateStudentTardinessLevel(String userId) async {
    try {
      // Tidak perlu lagi memanggil RPC karena sudah di-handle oleh
      // Database Trigger 'trg_update_siswa_tardiness' di Supabase.
    } catch (e) {
      print('Error updating tardiness level via RPC for user $userId: $e');
    }
  }
}
