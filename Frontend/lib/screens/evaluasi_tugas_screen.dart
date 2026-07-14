import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import 'form_evaluasi_tugas_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  List<Map<String, dynamic>> _perluTugasList = [];
  List<Map<String, dynamic>> _menungguBuktiList = [];
  List<Map<String, dynamic>> _perluDinilaiList = [];
  RealtimeChannel? _attendanceChannel;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSiswaPerluEvaluasi();
    _setupRealtime();
  }

  void _setupRealtime() {
    _attendanceChannel = supabase
        .channel('public:attendance:guru')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'terlambat',
            callback: (payload) {
              if (mounted) _fetchSiswaPerluEvaluasi();
            })
        .subscribe();
  }

  @override
  void dispose() {
    _attendanceChannel?.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSiswaPerluEvaluasi() async {
    try {
      final response = await supabase
          .from('terlambat')
          .select('id, tugas_hukuman, status_evaluasi, tanggal_terlambat, profiles!terlambat_user_id_fkey!inner(full_name, detail_siswa(kelas, status_disiplin))')
          .order('created_at');
      
      if (mounted) {
        setState(() {
          final allData = List<Map<String, dynamic>>.from(response);
          _perluTugasList = allData.where((d) => d['status_evaluasi'] == 'menunggu').toList();
          _menungguBuktiList = allData.where((d) => d['status_evaluasi'] == 'mengerjakan').toList();
          _perluDinilaiList = allData.where((d) => d['status_evaluasi'] == 'menunggu_nilai').toList();
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

  Future<void> _assignTask(String attendanceId) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Beri Tugas', style: TextStyle(color: AppColors.onBackground)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Masukkan deskripsi tugas...',
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.surfaceContainerHigh),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.outline)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await supabase.from('terlambat').update({
          'tugas_hukuman': controller.text,
          'status_evaluasi': 'mengerjakan',
        }).eq('id', attendanceId);
        
        await _fetchSiswaPerluEvaluasi();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tugas berhasil diberikan')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan tugas: $e')),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari nama siswa...',
                prefixIcon: const Icon(Icons.search, color: AppColors.outline),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.surfaceContainerHigh),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.surfaceContainerHigh),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.outline,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Perlu Tugas'),
              Tab(text: 'Menunggu'),
              Tab(text: 'Dinilai'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildList(
                  _perluTugasList,
                  'Siswa ini tercatat terlambat dan menunggu diberikan tugas hukuman.',
                  'Beri Tugas',
                  _assignTask,
                ),
                _buildList(
                  _menungguBuktiList,
                  'Tugas telah diberikan. Menunggu siswa mengunggah bukti penyelesaian.',
                  'Menunggu',
                  null, // No action needed
                ),
                _buildList(
                  _perluDinilaiList,
                  'Siswa telah mengunggah bukti dan menunggu dievaluasi.',
                  'Nilai',
                  (id) {
                    final data = _perluDinilaiList.firstWhere((e) => e['id'].toString() == id);
                    final siswa = data['profiles'] ?? {};
                    final detailList = siswa['detail_siswa'];
                    Map<String, dynamic>? detailSiswa;
                    if (detailList is List && detailList.isNotEmpty) {
                      detailSiswa = detailList[0];
                    } else if (detailList is Map) {
                      detailSiswa = Map<String, dynamic>.from(detailList);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FormEvaluasiTugasScreen(
                          attendanceId: id,
                          namaSiswa: siswa['full_name'] ?? 'Tanpa Nama',
                          tugas: data['tugas_hukuman'] ?? 'Tugas Kedisiplinan',
                          kelas: detailSiswa?['kelas'] ?? '-',
                        ),
                      ),
                    ).then((_) => _fetchSiswaPerluEvaluasi());
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list, String description, String actionLabel, Function(String)? onAction) {
    final filteredList = list.where((data) {
      final siswa = data['profiles'] ?? {};
      final nama = (siswa['full_name'] ?? '').toString().toLowerCase();
      return nama.contains(_searchQuery);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 24),
          if (filteredList.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'Tidak ada data pada kategori ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.outline),
                ),
              ),
            )
          else
            ...filteredList.map((data) {
              final siswa = data['profiles'] ?? {};
              final detailList = siswa['detail_siswa'];
              Map<String, dynamic>? detailSiswa;
              if (detailList is List && detailList.isNotEmpty) {
                detailSiswa = detailList[0];
              } else if (detailList is Map) {
                detailSiswa = Map<String, dynamic>.from(detailList);
              }
              final attendanceId = data['id'].toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildEvaluasiCard(
                  context,
                  attendanceId: attendanceId,
                  namaSiswa: siswa['full_name'] ?? 'Tanpa Nama',
                  tugas: data['tugas_hukuman'] ?? 'Tugas belum diberikan',
                  kelas: detailSiswa?['kelas'] ?? '-',
                  tanggal: 'Tanggal: ${data['tanggal_terlambat']}',
                  tingkat: _capitalize(detailSiswa?['status_disiplin'] ?? 'Sedang'),
                  actionLabel: actionLabel,
                  onAction: onAction,
                ),
              );
            }),
        ],
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Widget _buildEvaluasiCard(BuildContext context, {
    required String attendanceId,
    required String namaSiswa,
    required String tugas,
    required String kelas,
    required String tanggal,
    required String tingkat,
    required String actionLabel,
    Function(String)? onAction,
  }) {
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
              if (onAction != null)
                FilledButton.icon(
                  onPressed: () => onAction(attendanceId),
                  icon: Icon(
                    actionLabel == 'Nilai' ? Icons.edit_document : Icons.assignment_add, 
                    size: 16
                  ),
                  label: Text(actionLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_empty, size: 14, color: AppColors.outline),
                      const SizedBox(width: 4),
                      Text(
                        actionLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.outline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
