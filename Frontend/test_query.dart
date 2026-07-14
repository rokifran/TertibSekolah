import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = SupabaseClient(
    "https://gaiagxlmtancqreovmai.supabase.co",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdhaWFneGxtdGFuY3FyZW92bWFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMxNzEwMzcsImV4cCI6MjA5ODc0NzAzN30.fVgoi594jrSrYlFFhYfeJeIarGEPgQxwfrf4Ksk0joA"
  );

  try {
    print('--- DETAIL SISWA ---');
    final detailSiswa = await supabase.from('detail_siswa').select('user_id, kelas, nisn, status_disiplin, total_terlambat, total_menit_terlambat');
    for (var row in detailSiswa) {
      print(row);
    }

    print('\n--- TERLAMBAT ---');
    final terlambat = await supabase.from('terlambat').select('id, user_id, durasi_menit, status_evaluasi, tanggal_terlambat');
    for (var row in terlambat) {
      print(row);
    }
  } catch (e) {
    print('Error: $e');
  }
}
