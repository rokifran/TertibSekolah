import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/decision_tree_service.dart';
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

  // ── Existing state ────────────────────────────────────────────────────────
  bool _isLoadingHistory = true;
  List<Map<String, dynamic>> _lateHistory = [];
  List<String> _evidencePhotos = [];

  // ── Decision Tree state ───────────────────────────────────────────────────
  bool? _kelengkapan; // true = lengkap, false = tidak lengkap
  bool? _kesesuaian; // true = sesuai,   false = tidak sesuai
  String? _keputusanGuru; // 'selesai' | 'revisi'
  DecisionTreePrediction? _prediction;
  bool _isPredicting = false;
  bool _isSubmitting = false;

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
              if (path != null) _evidencePhotos.add(path);
            }
          } else if (buktiList is Map) {
            final path = buktiList['photo_path'];
            if (path != null) _evidencePhotos.add(path);
          }
          _lateHistory = [response];
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat tugas: $e')),
        );
      }
    }
  }

  // ── Decision Tree: minta prediksi ─────────────────────────────────────────

  Future<void> _getPrediction() async {
    final score = int.tryParse(_scoreController.text);
    if (score == null || score < 0 || score > 100) {
      _showError('Masukkan nilai yang valid (0-100) terlebih dahulu.');
      return;
    }
    if (_kelengkapan == null) {
      _showError('Pilih status kelengkapan bukti terlebih dahulu.');
      return;
    }
    if (_kesesuaian == null) {
      _showError('Pilih status kesesuaian tugas terlebih dahulu.');
      return;
    }

    setState(() {
      _isPredicting = true;
      _prediction = null;
    });

    try {
      final result = await DecisionTreeService.predict(
        nilai: score,
        kelengkapan: _kelengkapan!,
        kesesuaian: _kesesuaian!,
      );
      if (mounted) setState(() => _prediction = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mendapat prediksi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPredicting = false);
    }
  }

  // ── Simpan evaluasi ───────────────────────────────────────────────────────

  Future<void> _simpanEvaluasi() async {
    // Validasi input
    final score = int.tryParse(_scoreController.text);
    if (score == null || score < 0 || score > 100) {
      _showError('Nilai harus berupa angka antara 0 dan 100.');
      return;
    }
    if (_kelengkapan == null) {
      _showError('Pilih status kelengkapan bukti.');
      return;
    }
    if (_kesesuaian == null) {
      _showError('Pilih status kesesuaian tugas.');
      return;
    }
    if (_keputusanGuru == null) {
      _showError('Pilih keputusan final Anda (Selesai atau Revisi).');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await DecisionTreeService.submitEvaluation(
        terlambatId: widget.attendanceId,
        nilai: score,
        kelengkapan: _kelengkapan!,
        kesesuaian: _kesesuaian!,
        keputusanGuru: _keputusanGuru!,
        prediksiModel: _prediction?.prediksi,
        predictionConfidence: _prediction?.confidence,
        modelVersion: _prediction?.modelVersion,
      );

      if (!mounted) return;

      // Tampilkan disagreement jika ada model aktif & prediksi berbeda
      final prediksi = _prediction;
      if (prediksi != null &&
          prediksi.modelActive &&
          prediksi.prediksi != null &&
          prediksi.prediksi != _keputusanGuru) {
        _showDisagreementInfo(
          prediksiModel: prediksi.prediksi!,
          keputusanGuru: _keputusanGuru!,
        );
      } else {
        final label = _keputusanGuru == 'selesai' ? 'Selesai' : 'Revisi';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Evaluasi disimpan. Status: $label')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan evaluasi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showDisagreementInfo({
    required String prediksiModel,
    required String keputusanGuru,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Override Model Tercatat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Prediksi model', _capitalize(prediksiModel)),
            _infoRow('Keputusan guru', _capitalize(keputusanGuru)),
            const SizedBox(height: 8),
            const Text(
              'Override guru telah tercatat. Data disagreement ini penting '
              'untuk pembahasan hasil penelitian.',
              style: TextStyle(fontSize: 13, color: AppColors.outline),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text('$label : ',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(value),
          ],
        ),
      );

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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

  // ── Widgets ───────────────────────────────────────────────────────────────

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
                              child: const Icon(Icons.broken_image,
                                  color: AppColors.error),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
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

  // ── Formulir Evaluasi (baru dengan Decision Tree) ─────────────────────────

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

          // 1. Nilai tugas
          const Text(
            'Nilai Tugas (0–100)',
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
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) {
              // Reset prediksi jika input berubah
              if (_prediction != null) setState(() => _prediction = null);
            },
            decoration: InputDecoration(
              hintText: 'Masukkan nilai (0-100)',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.surfaceContainerHigh),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.surfaceContainerHigh),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Kelengkapan bukti
          const Text(
            'Kelengkapan Bukti',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onBackground,
            ),
          ),
          const SizedBox(height: 8),
          _buildToggleRow(
            selected: _kelengkapan,
            trueLabel: 'Lengkap',
            falseLabel: 'Tidak Lengkap',
            onChanged: (val) {
              setState(() {
                _kelengkapan = val;
                _prediction = null;
              });
            },
          ),
          const SizedBox(height: 20),

          // 3. Kesesuaian tugas
          const Text(
            'Kesesuaian Tugas',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onBackground,
            ),
          ),
          const SizedBox(height: 8),
          _buildToggleRow(
            selected: _kesesuaian,
            trueLabel: 'Sesuai',
            falseLabel: 'Tidak Sesuai',
            onChanged: (val) {
              setState(() {
                _kesesuaian = val;
                _prediction = null;
              });
            },
          ),
          const SizedBox(height: 24),

          // 4. Tombol Rekomendasi Decision Tree
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isPredicting ? null : _getPrediction,
              icon: _isPredicting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                _isPredicting
                    ? 'Memproses...'
                    : 'Dapatkan Rekomendasi Decision Tree',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // 5. Card hasil prediksi
          if (_prediction != null) ...[
            const SizedBox(height: 16),
            _buildPredictionCard(_prediction!),
          ],

          const SizedBox(height: 24),

          // 6. Keputusan guru
          const Text(
            'Keputusan Guru',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onBackground,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Keputusan akhir sepenuhnya berada di tangan guru.',
            style: TextStyle(fontSize: 12, color: AppColors.outline),
          ),
          const SizedBox(height: 8),
          _buildToggleRow(
            selected: _keputusanGuru == null
                ? null
                : _keputusanGuru == 'selesai',
            trueLabel: 'Selesai',
            falseLabel: 'Revisi',
            onChanged: (val) {
              setState(() => _keputusanGuru = val ? 'selesai' : 'revisi');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required bool? selected,
    required String trueLabel,
    required String falseLabel,
    required void Function(bool) onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: _ToggleChip(
            label: trueLabel,
            isSelected: selected == true,
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ToggleChip(
            label: falseLabel,
            isSelected: selected == false,
            isNegative: true,
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionCard(DecisionTreePrediction pred) {
    if (!pred.modelActive) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.outline, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Belum ada model aktif. Evaluasi disimpan sebagai data manual '
                'untuk pembentukan dataset awal penelitian.',
                style: TextStyle(fontSize: 13, color: AppColors.outline),
              ),
            ),
          ],
        ),
      );
    }

    final isSelesai = pred.prediksi == 'selesai';
    final color = isSelesai ? AppColors.primary : AppColors.error;
    final label = isSelesai ? 'Selesai' : 'Revisi';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSelesai ? Icons.check_circle_outline : Icons.loop,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Rekomendasi Decision Tree: $label',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          if (pred.confidencePersen != null) ...[
            const SizedBox(height: 6),
            Text(
              'Confidence: ${pred.confidencePersen}%',
              style: const TextStyle(fontSize: 13, color: AppColors.outline),
            ),
          ],
          if (pred.modelVersion != null) ...[
            const SizedBox(height: 2),
            Text(
              'Model: ${pred.modelVersion}',
              style: const TextStyle(fontSize: 12, color: AppColors.outline),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Rekomendasi sistem — keputusan akhir tetap oleh guru.',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceContainerHigh)),
      ),
      child: SafeArea(
        child: FilledButton(
          onPressed: _isSubmitting ? null : _simpanEvaluasi,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Simpan Evaluasi',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }
}

// ── Reusable ToggleChip ────────────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isNegative;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isNegative ? AppColors.error : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.outlineVariant,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? activeColor : AppColors.outline,
          ),
        ),
      ),
    );
  }
}
