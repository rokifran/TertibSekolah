import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../core/auth_service.dart';
import '../main.dart';
import 'login_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final userRes = await supabase
          .from('users')
          .select('tardiness_level, class_room')
          .eq('id', widget.authResult.userId)
          .single();

      final attendanceRes = await supabase
          .from('attendance')
          .select('id')
          .eq('user_id', widget.authResult.userId);

      if (mounted) {
        setState(() {
          _tardinessLevel = userRes['tardiness_level'] ?? 'Aman';
          _classRoom = userRes['class_room'] ?? '-';
          _totalKeterlambatan = (attendanceRes as List).length;
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
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fitur Tambah Foto belum tersedia'),
                  ),
                );
              },
              backgroundColor: AppColors.tertiary,
              foregroundColor: AppColors.onTertiary,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add_a_photo),
            )
          : null,
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
        Container(
          padding: const EdgeInsets.all(20),
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
                        color: AppColors.tertiaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.cleaning_services,
                        color: AppColors.tertiary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Belum Ada Hukuman',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onBackground,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '-',
                            style: TextStyle(
                              fontSize: 14,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: AppColors.outline,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tuntas',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
    // Mock URLs based on design
    final List<String> mockPhotos = [
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAQejvaVdyuLrp-OZ1ty9twd93S-46Lm5d9xlhw44dSUe8k0NGCn3rEVkzRCyoXo12ovvEiiFSKJ-XUTLtJDIQRg8hrFlhWXlzuw19E4_YIMYie--6RTTJsyqj6NwAWlf_WcHZez2Yl-7JU7zgQG8Ssi-7j_m5bBFK6GZtcGnvV299UyoQDelwqNjFqnVpZtjiO4EEylKxJYftuELDxNrkojhpWFsn4kG21RP8K7KZqTKNyEsG5ZIVpRh242XzAGXv0dJ2mZsZvFaU',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuB9hIj2IntwU7KMf936QU6XcA6myLTYRJpPRrLyh4zias86ODByoeSOHz837heHznHG8Y_2DpZbXiXVOQ7BsFtKfb1fJ-L1hGvTrTG__TAykt7cPgGwB_-bOUhyNkAkw5WxyFcmcZy4Fobm52215Dx4mVW7lgLsVCV9kmFDmVhL2TjH0nBpzogEQVMcQGUilu8huD0UuTZbzVUeQKXhwtSrwGytsHUwg7Jw8_c5vsDZk5sI6roHK4Xbm17m3jtKPLo9JkXXdP8VxYU',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAPWvw3-EO_7NNRJnxvZqDSm70fxWfr7t3h8wZFrADUt3ZAWzKqap1Dsuv8lYfOaYJU8HlzJKg6ey03GFXvWQhsX0kI-cqwzY_h6osPUg5vhg6R_2c_rb6cm0sAkWGe9DdMANksU2WEy27D2R_79oUMltGPdCBE_hiPxVg5OkdFDtCEDusXdpq0sCXFV_2tiKh_MIsL4aHhpn0m4JetYYziihmF4flLxmqn9vB-118irWBTII4KhD1uAhIS5h-MV-8OD0c8uPrTyuY',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAo531hh8dCHZ7fFy7MN0oPf4JfVcgcUm5ypmUeYHU6EGHaljZrWWPEKQ6T9MDT0TenO1abU4cnkWz2eG_ZJH2zT3Elhse0dZHddYuwY4nUEaKJCSjKy9IoFqSds7z43pNgcd28ISaIzeM5koqghFllpsaUbkHBcGMpShJ-k2XC49jXY9X_dwV7hSbMWwq0fcNsT6KVccA8ljiYRI1wRRxdoWNkw8N1vp_bunp9SkVor45x4QGgMSERb--CtP4OK0uU0JEwSaMC0Rs',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'Bukti Penyelesaian',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Manrope',
                  color: AppColors.onBackground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Task Detail Card
          Container(
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
                        color: AppColors.secondaryVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tugas Membersihkan Aula',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Manrope',
                              color: AppColors.onBackground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Diserahkan pada 12 Okt 2023, 14:30',
                            style: TextStyle(
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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pending_actions,
                        color: AppColors.primaryLight,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Status: Menunggu Evaluasi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onBackground,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Gallery Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Galeri Dokumentasi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Manrope',
                  color: AppColors.onBackground,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${mockPhotos.length} Foto',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: mockPhotos.length,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.surfaceContainer,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  mockPhotos[index],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: AppColors.outline,
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 80), // Padding for FAB
        ],
      ),
    );
  }
}
