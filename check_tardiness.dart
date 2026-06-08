import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

Future<void> main() async {
  // Read .env file manually since we're not running via flutter run
  final envFile = File('Frontend/.env');
  String url = '';
  String key = '';
  if (await envFile.exists()) {
    final lines = await envFile.readAsLines();
    for (var line in lines) {
      if (line.startsWith('SUPABASE_URL=')) url = line.split('=')[1].replaceAll('"', '');
      if (line.startsWith('SUPABASE_ANON_KEY=')) key = line.split('=')[1].replaceAll('"', '');
    }
  }

  final supabase = SupabaseClient(url, key);

  try {
    // Check Robby Efruan
    final user = await supabase.from('users').select('*').eq('nama', 'Robby Efruan').single();
    print('User: ${user['nama']}');
    print('Current tardiness_level: ${user['tardiness_level']}');
    print('User ID: ${user['id']}');

    // Check attendance for Robby Efruan
    final attendance = await supabase.from('attendance').select('*').eq('user_id', user['id']);
    print('Total attendance records: ${attendance.length}');
    for (var a in attendance) {
      print(' - ID: ${a['id']}, status: ${a['task_status']}');
    }

    // Try to calculate pending tasks
    final pendingTasks = await supabase.from('attendance').select('id').eq('user_id', user['id']).neq('task_status', 'graded');
    print('Pending tasks: ${pendingTasks.length}');

    // Try to update tardiness_level
    print('Attempting to update to aman...');
    await supabase.from('users').update({'tardiness_level': 'aman'}).eq('id', user['id']);
    print('Update successful!');

    // Read back
    final updated = await supabase.from('users').select('tardiness_level').eq('id', user['id']).single();
    print('New tardiness_level: ${updated['tardiness_level']}');
  } catch (e) {
    print('ERROR: $e');
  }
}
