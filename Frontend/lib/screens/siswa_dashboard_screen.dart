import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../theme/app_colors.dart';
import '../core/auth_service.dart';
import '../main.dart';
import 'login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SiswaDashboardScreen extends StatefulWidget {
  final AuthResult authResult;

  const SiswaDashboardScreen({super.key, required this.authResult});

  @override
  State<SiswaDashboardScreen> createState() => _SiswaDashboardScreenState();
}

class _SiswaDashboardScreenState extends State<SiswaDashboardScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  int _totalKeterlambatan = 0;
  String _tardinessLevel = 'Aman';
  String _classRoom = '-';
  List<Map<String, dynamic>> _tasks = [];
  RealtimeChannel? _attendanceChannel;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _setupRealtime();
  }

  void _setupRealtime() {
    _attendanceChannel = supabase
        .channel('public:attendance:siswa_${widget.authResult.userId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'terlambat',
          callback: (payload) {
            if (mounted) _fetchDashboardData();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _attendanceChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final userRes = await supabase
          .from('detail_siswa')
          .select('status_disiplin, kelas')
          .eq('user_id', widget.authResult.userId)
          .maybeSingle();

      final attendanceRes = await supabase
          .from('terlambat')
          .select('*, bukti_evaluasi(*)')
          .eq('user_id', widget.authResult.userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          if (userRes != null) {
            _tardinessLevel = userRes['status_disiplin'] ?? 'Aman';
            _classRoom = userRes['kelas'] ?? '-';
          }
          _tasks = List<Map<String, dynamic>>.from(attendanceRes);
          _totalKeterlambatan = _tasks.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat data: $e')));
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Keluar',
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar?',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: const Text('Keluar', style: TextStyle(fontFamily: 'Inter')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await AuthService.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    List<String> nameParts = name.trim().split(RegExp(r'\s+'));
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }
    return nameParts[0][0].toUpperCase();
  }

  Future<void> _uploadProof(String attendanceId) async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      for (int i = 0; i < pickedFiles.length; i++) {
        final pickedFile = pickedFiles[i];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName =
            '${widget.authResult.userId}/${attendanceId}_${timestamp}_$i.jpg';

        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          final compressedBytes = await FlutterImageCompress.compressWithList(
            bytes,
            quality: 60,
          );
          await supabase.storage
              .from('task_proofs')
              .uploadBinary(fileName, compressedBytes);
        } else {
          final tempDir = Directory.systemTemp;
          final targetPath = '${tempDir.path}/compressed_${timestamp}_$i.jpg';

          var result = await FlutterImageCompress.compressAndGetFile(
            pickedFile.path,
            targetPath,
            quality: 60,
          );

          if (result == null) continue;

          final compressedFile = File(result.path);

          await supabase.storage
              .from('task_proofs')
              .upload(fileName, compressedFile);

          // Clean up local compressed file
          if (await compressedFile.exists()) {
            await compressedFile.delete();
          }
        }

        await supabase.from('bukti_evaluasi').insert({
          'terlambat_id': attendanceId,
          'photo_path': fileName,
        });
      }

      await supabase
          .from('terlambat')
          .update({'status_evaluasi': 'menunggu_nilai'})
          .eq('id', attendanceId);

      _fetchDashboardData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bukti berhasil diunggah!')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal unggah: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Row(
          children: [
            Icon(Icons.school, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Tertib Sekolah',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontFamily: 'Manrope',
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedIndex == 0
          ? _buildDashboardBody(context)
          : _buildBuktiBody(context),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: AppColors.surfaceContainer,
        selectedItemColor: AppColors.onSecondaryContainer,
        unselectedItemColor: AppColors.onSurfaceVariant,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Bukti'),
        ],
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildDashboardBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileSummary(),
          const SizedBox(height: 24),
          _buildBentoGrid(),
          const SizedBox(height: 24),
          _buildPunishmentStatus(),
          const SizedBox(height: 24),
          _buildActionButtons(),
          const SizedBox(height: 32),
          // Logout Button
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text(
                'Logout',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSummary() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, ${widget.authResult.nama}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Manrope',
                  color: AppColors.onBackground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kelas $_classRoom',
                style: const TextStyle(fontSize: 16, color: AppColors.outline),
              ),
            ],
          ),
        ),
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryContainer, width: 2),
          ),
          child: Text(
            _getInitials(widget.authResult.nama),
            style: const TextStyle(
              color: AppColors.onPrimaryContainer,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Manrope',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBentoGrid() {
    Color levelColor = AppColors.primary;
    String levelLabel = 'Sangat Baik';

    final lowercaseTingkat = _tardinessLevel.toLowerCase();
    if (lowercaseTingkat == 'ringan') {
      levelColor = Colors.green[800]!;
      levelLabel = 'Perlu Perhatian';
    } else if (lowercaseTingkat == 'sedang') {
      levelColor = Colors.orange[800]!;
      levelLabel = 'Hati-hati';
    } else if (lowercaseTingkat == 'berat' ||
        lowercaseTingkat.contains('orang tua')) {
      levelColor = AppColors.error;
      levelLabel = 'Sangat Kurang';
    }

    return Column(
      children: [
        // Discipline Overview Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tingkat Kedisiplinan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Manrope',
                  color: AppColors.onBackground,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Status kedisiplinan Anda saat ini.',
                style: TextStyle(fontSize: 14, color: AppColors.outline),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: levelColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    levelLabel,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Manrope',
                      color: levelColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Quick Stats Row
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.timer,
                      color: AppColors.tertiary,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Total Keterlambatan',
                      style: TextStyle(fontSize: 11, color: AppColors.outline),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_totalKeterlambatan Kali',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Manrope',
                        color: AppColors.onBackground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    Icon(Icons.star, color: AppColors.primary, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Nilai Evaluasi',
                      style: TextStyle(fontSize: 11, color: AppColors.outline),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'N/A', // Mock value, as evaluations table is not fully utilized
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Manrope',
                        color: AppColors.onBackground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPunishmentStatus() {
    final int pendingTaskCount = _tasks
        .where((t) => t['status_evaluasi'] == 'menunggu')
        .length;
    final int assignedCount = _tasks
        .where((t) => t['status_evaluasi'] == 'mengerjakan')
        .length;
    final int submittedCount = _tasks
        .where((t) => t['status_evaluasi'] == 'menunggu_nilai')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status Penyelesaian Hukuman',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Manrope',
            color: AppColors.onBackground,
          ),
        ),
        const SizedBox(height: 16),
        _buildStatusRow(
          icon: Icons.hourglass_empty,
          color: Colors.orange[800]!,
          title: 'Menunggu Tugas',
          subtitle: 'Menunggu tugas dari guru',
          count: pendingTaskCount,
        ),
        const SizedBox(height: 12),
        _buildStatusRow(
          icon: Icons.assignment_late,
          color: AppColors.error,
          title: 'Belum Dikerjakan',
          subtitle: 'Perlu segera diselesaikan',
          count: assignedCount,
        ),
        const SizedBox(height: 12),
        _buildStatusRow(
          icon: Icons.pending_actions,
          color: AppColors.secondary,
          title: 'Menunggu Penilaian',
          subtitle: 'Tugas sudah diunggah',
          count: submittedCount,
        ),
      ],
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required int count,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onBackground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: count > 0 ? color : AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: count > 0 ? Colors.white : AppColors.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          setState(() {
            _selectedIndex = 1;
          });
        },
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryContainer,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.upload_file),
        label: const Text(
          'Unggah Bukti',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }

  Widget _buildBuktiBody(BuildContext context) {
    final pendingTasks = _tasks
        .where(
          (t) =>
              t['status_evaluasi'] != null && t['status_evaluasi'] != 'selesai',
        )
        .toList();
    final completedTasks = _tasks
        .where((t) => t['status_evaluasi'] == 'selesai')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tugas Hukuman',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'Manrope',
              color: AppColors.onBackground,
            ),
          ),
          const SizedBox(height: 32),

          if (pendingTasks.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'Tidak ada tugas yang menunggu penyelesaian.',
                  style: TextStyle(color: AppColors.outline),
                ),
              ),
            )
          else
            ...pendingTasks.map((task) => _buildTaskCard(task)),

          const SizedBox(height: 32),
          const Text(
            'Riwayat Hukuman Selesai',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'Manrope',
              color: AppColors.onBackground,
            ),
          ),
          const SizedBox(height: 16),
          if (completedTasks.isEmpty)
            const Text(
              'Belum ada riwayat tugas.',
              style: TextStyle(color: AppColors.outline),
            )
          else
            ...completedTasks.map((task) => _buildTaskCard(task)),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final status = task['status_evaluasi'] ?? 'menunggu';
    final isPendingTask = status == 'menunggu';
    final isSubmitted = status == 'menunggu_nilai';

    final evaluationList = task['bukti_evaluasi'];
    List<Map<String, dynamic>> evaluations = [];
    if (evaluationList is List) {
      evaluations = List<Map<String, dynamic>>.from(evaluationList);
    } else if (evaluationList is Map) {
      evaluations = [Map<String, dynamic>.from(evaluationList)];
    }

    final isGraded = status == 'selesai' || task['nilai'] != null;
    final evaluation = task;

    final taskDescription = isPendingTask
        ? 'Menunggu Tugas dari Guru'
        : (task['tugas_hukuman'] ?? 'Tugas Kedisiplinan');
    final tanggal = task['tanggal_terlambat'] ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 48,
                decoration: BoxDecoration(
                  color: isGraded
                      ? AppColors.primary
                      : (isSubmitted ? AppColors.secondary : AppColors.error),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      taskDescription,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Manrope',
                        color: AppColors.onBackground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Terkait Keterlambatan: $tanggal',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.outline,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isGraded) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.surfaceContainerHigh),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${evaluation['nilai'] ?? '-'}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tugas telah dinilai oleh guru',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isGraded
                      ? Icons.check_circle
                      : (isSubmitted
                            ? Icons.pending_actions
                            : (isPendingTask
                                  ? Icons.hourglass_empty
                                  : Icons.warning_amber)),
                  color: isGraded
                      ? AppColors.primary
                      : (isSubmitted
                            ? AppColors.secondary
                            : (isPendingTask
                                  ? AppColors.outline
                                  : AppColors.error)),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isGraded
                      ? 'Status: Tuntas (Dinilai)'
                      : (isSubmitted
                            ? 'Status: Menunggu Evaluasi'
                            : (isPendingTask
                                  ? 'Status: Menunggu Tugas'
                                  : 'Status: Menunggu Bukti')),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onBackground,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          if (status == 'mengerjakan' || status == 'menunggu_nilai') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _uploadProof(task['id']),
                icon: const Icon(Icons.upload_file),
                label: Text(status == 'menunggu_nilai' ? 'Tambah Bukti' : 'Unggah Bukti'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ),
          ],
          if (evaluations.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Bukti Terunggah (${evaluations.length}):',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
                color: AppColors.onBackground,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: evaluations.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final eval = evaluations[index];
                  final photoPath = eval['photo_path'];
                  if (photoPath == null) return const SizedBox.shrink();
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: GestureDetector(
                      onTap: () => _showImagePreview(context, photoPath),
                      child: Image.network(
                        supabase.storage
                            .from('task_proofs')
                            .getPublicUrl(photoPath),
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 120,
                          color: AppColors.surfaceContainerHigh,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image, color: AppColors.error),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showImagePreview(BuildContext context, String photoPath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  supabase.storage.from('task_proofs').getPublicUrl(photoPath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Gagal memuat gambar'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
