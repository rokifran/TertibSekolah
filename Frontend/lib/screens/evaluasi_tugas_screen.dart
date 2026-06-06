import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import 'form_evaluasi_tugas_screen.dart';

class EvaluasiTugasScreen extends StatelessWidget {
  const EvaluasiTugasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        iconTheme: const IconThemeData(color: AppColors.onBackground),
        title: const Text(
          'Evaluasi Tugas',
          style: TextStyle(
            color: AppColors.onBackground,
            fontWeight: FontWeight.bold,
            fontFamily: 'Manrope',
          ),
        ),
      ),
      body: const EvaluasiTugasView(),
    );
  }
}

class EvaluasiTugasView extends StatefulWidget {
  const EvaluasiTugasView({super.key});

  @override
  State<EvaluasiTugasView> createState() => _EvaluasiTugasViewState();
}

class _EvaluasiTugasViewState extends State<EvaluasiTugasView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _siswaList = [];

  @override
  void initState() {
    super.initState();
    _fetchSiswaPerluEvaluasi();
  }

  Future<void> _fetchSiswaPerluEvaluasi() async {
    try {
      final response = await supabase
          .from('users')
          .select('id, nama, class_room, tardiness_level')
          .eq('role_id', 3)
          .neq('tardiness_level', 'aman')
          .order('nama');
      
      if (mounted) {
        setState(() {
          _siswaList = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tugas Perlu Dinilai',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'Manrope',
              color: AppColors.onBackground,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Berikut adalah daftar siswa yang perlu dievaluasi (Tingkat kehadiran tidak aman).',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_siswaList.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'Semua siswa berstatus aman.\nTidak ada tugas evaluasi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.outline),
                ),
              ),
            )
          else
            ..._siswaList.map((siswa) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _buildEvaluasiCard(
                    context,
                    idSiswa: siswa['id'].toString(),
                    namaSiswa: siswa['nama'] ?? 'Tanpa Nama',
                    tugas: 'Pembinaan Kedisiplinan',
                    kelas: siswa['class_room'] ?? '-',
                    tanggal: 'Menunggu Evaluasi',
                    tingkat: _capitalize(siswa['tardiness_level'] ?? 'Sedang'),
                  ),
                )),
        ],
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Widget _buildEvaluasiCard(BuildContext context, {required String idSiswa, required String namaSiswa, required String tugas, required String kelas, required String tanggal, required String tingkat}) {
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
      tingkatColor = AppColors.tertiary;
      tingkatBgColor = AppColors.tertiaryContainer.withValues(alpha: 0.3);
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assignment, color: AppColors.secondary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            namaSiswa,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Manrope',
                              color: AppColors.onBackground,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: tingkatBgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Tingkat $tingkat',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: tingkatColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$tugas • Kelas $kelas',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.surfaceVariant),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: AppColors.outline),
                  const SizedBox(width: 6),
                  Text(
                    tanggal,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FormEvaluasiTugasScreen(
                        idSiswa: idSiswa,
                        namaSiswa: namaSiswa,
                        tugas: tugas,
                        kelas: kelas,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_document, size: 16),
                label: const Text('Nilai'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
