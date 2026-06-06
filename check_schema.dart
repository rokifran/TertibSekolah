import 'dart:convert';
import 'dart:io';

void main() async {
  final url = Uri.parse('https://raykzkaitdhxbkfdduvf.supabase.co/rest/v1/attendance?limit=1');
  final request = await HttpClient().getUrl(url);
  request.headers.add('apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJheWt6a2FpdGRoeGJrZmRkdXZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1NzUzMjEsImV4cCI6MjA5NjE1MTMyMX0.AbHuXAVqLG-oWZWgmK-T67v2nRp5EGuJ6emRfczvEGo');
  request.headers.add('Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJheWt6a2FpdGRoeGJrZmRkdXZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1NzUzMjEsImV4cCI6MjA5NjE1MTMyMX0.AbHuXAVqLG-oWZWgmK-T67v2nRp5EGuJ6emRfczvEGo');
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  print('Attendance: \$responseBody');

  final url2 = Uri.parse('https://raykzkaitdhxbkfdduvf.supabase.co/rest/v1/users?limit=1');
  final request2 = await HttpClient().getUrl(url2);
  request2.headers.add('apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJheWt6a2FpdGRoeGJrZmRkdXZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1NzUzMjEsImV4cCI6MjA5NjE1MTMyMX0.AbHuXAVqLG-oWZWgmK-T67v2nRp5EGuJ6emRfczvEGo');
  request2.headers.add('Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJheWt6a2FpdGRoeGJrZmRkdXZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1NzUzMjEsImV4cCI6MjA5NjE1MTMyMX0.AbHuXAVqLG-oWZWgmK-T67v2nRp5EGuJ6emRfczvEGo');
  final response2 = await request2.close();
  final responseBody2 = await response2.transform(utf8.decoder).join();
  print('Users: \$responseBody2');
}
