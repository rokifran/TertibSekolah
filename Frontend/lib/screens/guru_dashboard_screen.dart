import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../core/auth_service.dart';
import 'login_screen.dart';
import 'input_keterlambatan_screen.dart';
import 'evaluasi_tugas_screen.dart';
import 'data_siswa_screen.dart';
import '../main.dart';

class GuruDashboardScreen extends StatefulWidget {
  const GuruDashboardScreen({super.key});

  @override
  State<GuruDashboardScreen> createState() => _GuruDashboardScreenState();
}

class _GuruDashboardScreenState extends State<GuruDashboardScreen> {
  int _selectedIndex = 0;
  int _pendingTaskCount = 0;
  int _assignedCount = 0;
  int _submittedCount = 0;
  int _ringanCount = 0;
  int _sedangCount = 0;
  int _beratCount = 0;

  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoadingActivities = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final taskResponse = await supabase
          .from('terlambat')
          .select('status_evaluasi');
          
      final studentResponse = await supabase
          .from('detail_siswa')
          .select('status_disiplin');

      final activityResponse = await supabase
          .from('terlambat')
          .select('id, created_at, status_evaluasi, tugas_hukuman, durasi_menit, profiles!inner(full_name, detail_siswa(kelas))')
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          final allTasks = List<Map<String, dynamic>>.from(taskResponse);
          _pendingTaskCount = allTasks.where((d) => d['status_evaluasi'] == 'menunggu').length;
          _assignedCount = allTasks.where((d) => d['status_evaluasi'] == 'mengerjakan').length;
          _submittedCount = allTasks.where((d) => d['status_evaluasi'] == 'selesai').length;

          final allStudents = List<Map<String, dynamic>>.from(studentResponse);
          _ringanCount = allStudents.where((d) => d['status_disiplin']?.toString().toLowerCase() == 'ringan').length;
          _sedangCount = allStudents.where((d) => d['status_disiplin']?.toString().toLowerCase() == 'sedang').length;
          _beratCount = allStudents.where((d) {
            final level = d['status_disiplin']?.toString().toLowerCase() ?? '';
            return level == 'berat' || level.contains('orang tua');
          }).length;

          _recentActivities = List<Map<String, dynamic>>.from(activityResponse);
          _isLoadingActivities = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoadingActivities = false;
        });
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      _fetchDashboardData();
    }
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
              style: TextStyle(fontFamily: 'Inter', color: AppColors.onSurfaceVariant),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
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

  @override
  Widget build(BuildContext context) {
    final String currentDate = DateFormat('EEEE, d MMMM y', 'id_ID').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          _selectedIndex == 0 
              ? 'Tertib Sekolah' 
              : _selectedIndex == 1 
                  ? 'Evaluasi Tugas' 
                  : 'Data Siswa',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontFamily: 'Manrope',
          ),
        ),
      ),
      body: _selectedIndex == 0 
          ? _buildDashboardBody(context, currentDate)
          : _selectedIndex == 1
              ? const EvaluasiTugasView()
              : const DataSiswaView(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: AppColors.surfaceContainer,
        selectedItemColor: AppColors.onSecondaryContainer,
        unselectedItemColor: AppColors.onSurfaceVariant,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Tugas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups),
            label: 'Siswa',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardBody(BuildContext context, String currentDate) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Text(
            currentDate,
            style: const TextStyle(
              color: AppColors.outline, // text-text-medium-emphasis roughly outline/grey
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Selamat Pagi, Guru!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'Manrope',
              color: AppColors.onBackground,
            ),
          ),
          const SizedBox(height: 24),

          // Bento Grid Actions
          _buildPrimaryActionCard(context),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSecondaryActionCard(context)),
              const SizedBox(width: 16),
              Expanded(child: _buildTertiaryActionCard(context)),
            ],
          ),
          const SizedBox(height: 32),

          // Horizontal Scroll: Recent Activity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Aktivitas Terkini',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Manrope',
                  color: AppColors.onBackground,
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: _isLoadingActivities
                ? const Center(child: CircularProgressIndicator())
                : _recentActivities.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada aktivitas terkini',
                          style: TextStyle(color: AppColors.outline),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: _recentActivities.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          return _buildActivityCardFromData(_recentActivities[index]);
                        },
                      ),
          ),
          const SizedBox(height: 32),

          // ── Logout Button ──
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  Widget _buildPrimaryActionCard(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const InputKeterlambatanScreen()),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.onPrimary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_circle_outline, color: AppColors.onPrimary),
            ),
            const SizedBox(height: 12),
            const Text(
              'Input Keterlambatan',
              style: TextStyle(
                color: AppColors.onPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                fontFamily: 'Manrope',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Catat siswa terlambat hari ini',
              style: TextStyle(
                color: AppColors.onPrimary.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryActionCard(BuildContext context) {
    return InkWell(
      onTap: () {
        _onItemTapped(1);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.secondaryContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assignment_turned_in, color: AppColors.secondary),
            ),
            const SizedBox(height: 12),
            const Text(
              'Evaluasi Tugas',
              style: TextStyle(
                color: AppColors.onSecondaryContainer,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$_pendingTaskCount perlu tugas\n$_assignedCount menunggu\n$_submittedCount dinilai',
              style: TextStyle(
                color: AppColors.onSecondaryContainer.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTertiaryActionCard(BuildContext context) {
    return InkWell(
      onTap: () {
        _onItemTapped(2);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.groups, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            const Text(
              'Data Siswa',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$_ringanCount ringan\n$_sedangCount sedang\n$_beratCount berat',
              style: const TextStyle(
                color: AppColors.outline,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String description,
    required String time,
    String? className,
    String? tardinessLevel,
  }) {
    // Menentukan warna badge berdasarkan level
    Color levelColor = AppColors.primary;
    Color levelBgColor = AppColors.primaryContainer;
    
    if (tardinessLevel != null) {
      String lvl = tardinessLevel.toLowerCase();
      if (lvl == 'aman') {
        levelColor = AppColors.outline;
        levelBgColor = Colors.white;
      } else if (lvl == 'ringan') {
        levelColor = Colors.green[800]!;
        levelBgColor = Colors.lightGreen[100]!;
      } else if (lvl == 'sedang') {
        levelColor = Colors.orange[800]!;
        levelBgColor = Colors.orange[100]!;
      } else if (lvl == 'berat' || lvl.contains('orang tua')) {
        levelColor = AppColors.error;
        levelBgColor = AppColors.errorContainer;
      }
    }
    return Container(
      width: 256,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      className != null ? '$title ($className)' : title,
                      style: const TextStyle(
                        color: AppColors.onBackground,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (tardinessLevel != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: levelBgColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Level: $tardinessLevel',
                      style: TextStyle(
                        color: levelColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.outline,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  time,
                  style: const TextStyle(
                    color: AppColors.outline,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCardFromData(Map<String, dynamic> data) {
    final user = data['profiles'] as Map<String, dynamic>? ?? {};
    final nama = user['full_name']?.toString() ?? 'Siswa';
    final detailList = user['detail_siswa'];
    String? className;
    if (detailList is List && detailList.isNotEmpty) {
      className = detailList[0]['kelas']?.toString();
    } else if (detailList is Map) {
      className = detailList['kelas']?.toString();
    }
    final status = data['status_evaluasi']?.toString() ?? 'menunggu';
    final duration = data['durasi_menit']?.toString() ?? '0';
    final createdAt = data['created_at']?.toString() ?? '';

    // Parse time roughly
    String timeAgo = '';
    if (createdAt.isNotEmpty) {
      final date = DateTime.tryParse(createdAt);
      if (date != null) {
        final diff = DateTime.now().difference(date);
        if (diff.inDays > 0) {
          timeAgo = '${diff.inDays} hari lalu';
        } else if (diff.inHours > 0) {
          timeAgo = '${diff.inHours} jam lalu';
        } else if (diff.inMinutes > 0) {
          timeAgo = '${diff.inMinutes} menit lalu';
        } else {
          timeAgo = 'Baru saja';
        }
      }
    }

    IconData icon;
    Color iconColor;
    Color iconBgColor;
    String description;
    String title = nama;

    if (status == 'menunggu') {
      icon = Icons.timer_off_outlined;
      iconColor = AppColors.onErrorContainer;
      iconBgColor = AppColors.errorContainer;
      description = 'Terlambat $duration menit';
    } else if (status == 'mengerjakan') {
      icon = Icons.assignment_outlined;
      iconColor = AppColors.onSecondaryContainer;
      iconBgColor = AppColors.secondaryContainer;
      description = 'Mengerjakan tugas';
    } else if (status == 'selesai') {
      icon = Icons.check_circle_outline;
      iconColor = AppColors.onTertiaryContainer;
      iconBgColor = AppColors.tertiaryContainer;
      description = 'Tugas selesai';
    } else {
      icon = Icons.info_outline;
      iconColor = AppColors.outline;
      iconBgColor = AppColors.surfaceVariant;
      description = 'Lainnya';
    }

    return _buildActivityCard(
      icon: icon,
      iconColor: iconColor,
      iconBgColor: iconBgColor,
      title: title,
      className: className,
      tardinessLevel: null,
      description: description,
      time: timeAgo,
    );
  }
}
