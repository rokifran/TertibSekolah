import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../main.dart';

class FormEvaluasiTugasScreen extends StatefulWidget {
  final String attendanceId;
  final String namaSiswa;
  final String tugas;
  final String kelas;

  const FormEvaluasiTugasScreen({
    super.key,
    required this.attendanceId,
    required this.namaSiswa,
    required this.tugas,
    required this.kelas,
  });

  @override
  State<FormEvaluasiTugasScreen> createState() =>
      _FormEvaluasiTugasScreenState();
}

class _FormEvaluasiTugasScreenState extends State<FormEvaluasiTugasScreen> {
  final _scoreController = TextEditingController();

  bool _isLoadingHistory = true;
  List<Map<String, dynamic>> _lateHistory = [];
  List<String> _evidencePhotos = [];

  @override
  void initState() {
    super.initState();
    _fetchTaskDetails();
  }

  Future<void> _fetchTaskDetails() async {
    try {
      final response = await supabase
          .from('terlambat')
          .select('*, bukti_evaluasi(*)')
          .eq('id', widget.attendanceId)
          .single();

      if (mounted) {
        setState(() {
          final buktiList = response['bukti_evaluasi'];
          _evidencePhotos = [];
          if (buktiList is List) {
            for (final bukti in buktiList) {
              final path = bukti['photo_path'];
              if (path != null) {
                _evidencePhotos.add(path);
              }
            }
          } else if (buktiList is Map) {
            final path = buktiList['photo_path'];
            if (path != null) {
              _evidencePhotos.add(path);
            }
          }
          _lateHistory = [response];
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat tugas: $e')));
      }
    }
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

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
          'Nilai Tugas Siswa',
          style: TextStyle(
            color: AppColors.onBackground,
            fontWeight: FontWeight.bold,
            fontFamily: 'Manrope',
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStudentInfo(),
            const SizedBox(height: 16),
            _buildLateHistory(),
            const SizedBox(height: 16),
            _buildTaskProof(),
            const SizedBox(height: 16),
            _buildEvaluationForm(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildStudentInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Row(
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
                Text(
                  widget.namaSiswa,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kelas: ${widget.kelas}',
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
              const Icon(Icons.access_time, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Informasi Keterlambatan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onBackground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingHistory)
            const Center(child: CircularProgressIndicator())
          else if (_lateHistory.isEmpty)
            const Text(
              'Data keterlambatan tidak ditemukan.',
              style: TextStyle(color: AppColors.outline),
            )
          else
            ..._lateHistory.map((history) {
              final String tanggal = history['tanggal_terlambat'] ?? '-';
              final int duration = history['durasi_menit'] ?? 0;
              final String tugas = history['tugas_hukuman'] ?? '-';
              return Column(
                children: [
                  _buildHistoryItem(
                    tanggal,
                    'Terlambat $duration menit',
                    'Tugas: $tugas',
                  ),
                  if (history != _lateHistory.last)
                    const Divider(color: AppColors.surfaceVariant),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(String date, String status, String reason) {
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
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.outline,
                  ),
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

  Widget _buildTaskProof() {
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
            'Bukti Penyelesaian Tugas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.onBackground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.tugas,
            style: const TextStyle(fontSize: 14, color: AppColors.outline),
          ),
          const SizedBox(height: 16),
          _evidencePhotos.isNotEmpty
              ? SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _evidencePhotos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final photoPath = _evidencePhotos[index];
                      final fullUrl = supabase.storage
                          .from('task_proofs')
                          .getPublicUrl(photoPath);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GestureDetector(
                          onTap: () => _showImagePreview(context, fullUrl),
                          child: Image.network(
                            fullUrl,
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
                )
              : Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.5),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 40,
                        color: AppColors.outline,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Belum ada bukti yang diunggah',
                        style: TextStyle(
                          color: AppColors.outline,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
          if (_evidencePhotos.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                if (_evidencePhotos.isNotEmpty) {
                  final firstUrl = supabase.storage
                      .from('task_proofs')
                      .getPublicUrl(_evidencePhotos.first);
                  final Uri url = Uri.parse(firstUrl);
                  try {
                    final bool success = await launchUrl(
                      url,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tidak dapat membuka tautan'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                }
              },
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: const Text('Buka Bukti Pertama di Browser'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
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
                  imageUrl,
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

  Widget _buildEvaluationForm() {
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
            'Formulir Evaluasi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.onBackground,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nilai Tugas',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onBackground,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _scoreController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Masukkan nilai (0-100)',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.surfaceContainerHigh,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.surfaceContainerHigh,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceContainerHigh)),
      ),
      child: SafeArea(
        child: FilledButton(
          onPressed: () async {
            if (_scoreController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Harap masukkan nilai evaluasi'),
                ),
              );
              return;
            }

            try {
              int score = int.tryParse(_scoreController.text) ?? 0;
              bool isLulus = score >= 75;

              if (isLulus) {
                await supabase
                    .from('terlambat')
                    .update({
                      'nilai': score,
                      'evaluator_id': supabase.auth.currentUser!.id,
                      'status_evaluasi': 'selesai',
                    })
                    .eq('id', widget.attendanceId);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Siswa LULUS. Status menjadi Tuntas.'),
                    ),
                  );
                  Navigator.pop(context);
                }
              } else {
                await supabase
                    .from('bukti_evaluasi')
                    .delete()
                    .eq('terlambat_id', widget.attendanceId);

                await supabase
                    .from('terlambat')
                    .update({'status_evaluasi': 'mengerjakan'})
                    .eq('id', widget.attendanceId);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Siswa TIDAK LULUS. Siswa harus mengerjakan ulang.',
                      ),
                    ),
                  );
                  Navigator.pop(context);
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal menyimpan evaluasi: $e')),
                );
              }
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Simpan Evaluasi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
