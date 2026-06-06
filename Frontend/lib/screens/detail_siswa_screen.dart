import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../main.dart';

class DetailSiswaScreen extends StatefulWidget {
  final Map<String, dynamic> siswa;

  const DetailSiswaScreen({super.key, required this.siswa});

  @override
  State<DetailSiswaScreen> createState() => _DetailSiswaScreenState();
}

class _DetailSiswaScreenState extends State<DetailSiswaScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _attendanceHistory = [];

  int _pendingTaskCount = 0;
  int _assignedCount = 0;
  int _submittedCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchDetailSiswa();
  }

  Future<void> _fetchDetailSiswa() async {
    try {
      final response = await supabase
          .from('attendance')
          .select('*')
          .eq('user_id', widget.siswa['id'])
          .order('tanggal', ascending: false)
          .order('waktu', ascending: false);

      if (mounted) {
        setState(() {
          _attendanceHistory = List<Map<String, dynamic>>.from(response);
          
          _pendingTaskCount = _attendanceHistory.where((e) => e['task_status'] == 'pending_task').length;
          _assignedCount = _attendanceHistory.where((e) => e['task_status'] == 'assigned').length;
          _submittedCount = _attendanceHistory.where((e) => e['task_status'] == 'submitted').length;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat detail siswa: $e')),
        );
      }
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final namaSiswa = widget.siswa['nama'] ?? 'Tanpa Nama';
    final kelas = widget.siswa['class_room'] ?? '-';
    final nisn = widget.siswa['nisn'] ?? '-';
    final tingkat = _capitalize(widget.siswa['tardiness_level'] ?? 'Aman');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        iconTheme: const IconThemeData(color: AppColors.onBackground),
        title: const Text(
          'Detail Siswa',
          style: TextStyle(
            color: AppColors.onBackground,
            fontWeight: FontWeight.bold,
            fontFamily: 'Manrope',
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStudentInfo(namaSiswa, kelas, nisn, tingkat),
                  const SizedBox(height: 16),
                  _buildTaskStatusOverview(),
                  const SizedBox(height: 16),
                  _buildLateHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildStudentInfo(String namaSiswa, String kelas, String nisn, String tingkat) {
    Color tingkatColor;
    Color tingkatBgColor;
    final lowercaseTingkat = tingkat.toLowerCase();

    if (lowercaseTingkat == 'aman') {
      tingkatColor = AppColors.outline;
      tingkatBgColor = Colors.white;
    } else if (lowercaseTingkat == 'ringan') {
      tingkatColor = Colors.green[800]!;
      tingkatBgColor = Colors.lightGreen[100]!;
    } else if (lowercaseTingkat == 'sedang') {
      tingkatColor = Colors.orange[800]!;
      tingkatBgColor = Colors.orange[100]!;
    } else if (lowercaseTingkat == 'berat' || lowercaseTingkat == 'pemanggilan orang tua') {
      tingkatColor = AppColors.error;
      tingkatBgColor = AppColors.errorContainer;
    } else {
      tingkatColor = AppColors.outline;
      tingkatBgColor = AppColors.surfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(Icons.person, color: AppColors.primary, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        namaSiswa,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onBackground,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tingkatBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tingkat,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: tingkatColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Kelas: $kelas',
                  style: const TextStyle(fontSize: 14, color: AppColors.outline),
                ),
                Text(
                  'NISN: $nisn',
                  style: const TextStyle(fontSize: 14, color: AppColors.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskStatusOverview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ringkasan Tugas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.onBackground,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatusCard(
                  'Perlu Tugas',
                  _pendingTaskCount.toString(),
                  AppColors.error,
                  AppColors.errorContainer,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusCard(
                  'Menunggu\nBukti',
                  _assignedCount.toString(),
                  Colors.orange[800]!,
                  Colors.orange[100]!,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusCard(
                  'Perlu\nDinilai',
                  _submittedCount.toString(),
                  Colors.green[800]!,
                  Colors.lightGreen[100]!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, String count, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLateHistory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Riwayat Keterlambatan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onBackground,
                ),
              ),
              const Spacer(),
              if (_attendanceHistory.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_attendanceHistory.length} Kali',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_attendanceHistory.isEmpty)
            const Text(
              'Belum ada riwayat keterlambatan.',
              style: TextStyle(color: AppColors.outline),
            )
          else
            ..._attendanceHistory.map((history) {
              final String tanggal = history['tanggal'] ?? '-';
              final int duration = history['duration_minutes'] ?? 0;
              final String level = history['level'] ?? '-';
              String statusLabel = '';
              String taskStatus = history['task_status'] ?? 'pending_task';
              
              if (taskStatus == 'pending_task') statusLabel = 'Perlu Tugas';
              else if (taskStatus == 'assigned') statusLabel = 'Menunggu Bukti';
              else if (taskStatus == 'submitted') statusLabel = 'Perlu Dinilai';
              else if (taskStatus == 'graded') statusLabel = 'Tuntas';

              return Column(
                children: [
                  _buildHistoryItem(
                    tanggal,
                    'Terlambat $duration menit',
                    'Tingkat: $level',
                    statusLabel,
                  ),
                  if (history != _attendanceHistory.last)
                    const Divider(color: AppColors.surfaceVariant),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(String date, String status, String reason, String taskStatusLabel) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.outline,
                      ),
                    ),
                    Text(
                      taskStatusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: taskStatusLabel == 'Tuntas' ? Colors.green : AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
