import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import 'input_keterlambatan_screen.dart';
import 'evaluasi_tugas_screen.dart';
import 'data_siswa_screen.dart';

class GuruDashboardScreen extends StatefulWidget {
  const GuruDashboardScreen({super.key});

  @override
  State<GuruDashboardScreen> createState() => _GuruDashboardScreenState();
}

class _GuruDashboardScreenState extends State<GuruDashboardScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                _buildActivityCard(
                  icon: Icons.timer_off_outlined,
                  iconColor: AppColors.onErrorContainer,
                  iconBgColor: AppColors.errorContainer,
                  title: 'Budi Santoso',
                  className: '10-A',
                  tardinessLevel: 'Sedang',
                  description: 'Terlambat 15 menit - Macet',
                  time: '07:15 AM',
                ),
                const SizedBox(width: 16),
                _buildActivityCard(
                  icon: Icons.check_circle_outline,
                  iconColor: AppColors.onSecondaryContainer, // approx for on-secondary-fixed
                  iconBgColor: AppColors.secondaryContainer, // approx for secondary-fixed
                  title: 'Tugas Matematika',
                  description: 'Dinilai untuk Kelas 10-B',
                  time: 'Kemarin',
                ),
                const SizedBox(width: 16),
                _buildActivityCard(
                  icon: Icons.person_add_outlined,
                  iconColor: AppColors.onSurface,
                  iconBgColor: AppColors.surfaceVariant,
                  title: 'Siswa Baru',
                  description: 'Data ditambahkan ke 10-A',
                  time: '2 hari lalu',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Logout Action
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text(
                'Logout',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
              '3 perlu dinilai',
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
            const Text(
              'Kelas 10-A',
              style: TextStyle(
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
        levelColor = Colors.green[700]!;
        levelBgColor = Colors.green[100]!;
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
}
