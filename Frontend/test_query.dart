import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(
    Platform.environment['SUPABASE_URL'] ?? '',
    Platform.environment['SUPABASE_KEY'] ?? ''
  );

  try {
    final response = await supabase
        .from('attendance')
        .select('id, task_description, task_status, tanggal, users!attendance_user_id_fkey!inner(nama, class_room, tardiness_level)')
        .neq('task_status', 'graded')
        .order('created_at');
    print(response);
  } catch (e) {
    print('Error: $e');
  }
}
