import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../main.dart';

class DataSiswaView extends StatefulWidget {
  const DataSiswaView({super.key});

  @override
  State<DataSiswaView> createState() => _DataSiswaViewState();
}

class _DataSiswaViewState extends State<DataSiswaView> {
  String _searchQuery = '';
  String _selectedFilter = 'Semua';
  bool _isLoading = true;

  List<Map<String, dynamic>> _allSiswa = [];

  @override
  void initState() {
    super.initState();
    _fetchSiswa();
  }

  Future<void> _fetchSiswa() async {
    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('role_id', 3)
          .order('nama');

      if (mounted) {
        setState(() {
          _allSiswa = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data siswa: $e'),
            backgroundColor: AppColors.error,
          ),
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
    List<Map<String, dynamic>> filteredSiswa = _allSiswa.where((siswa) {
      final namaSiswa = (siswa['nama'] ?? '').toString().toLowerCase();
      final tingkat = (siswa['tardiness_level'] ?? 'Aman').toString().toLowerCase();

      final matchesSearch = namaSiswa.contains(_searchQuery.toLowerCase());
      final matchesFilter = _selectedFilter == 'Semua' ||
          tingkat == _selectedFilter.toLowerCase();
      return matchesSearch && matchesFilter;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daftar Siswa',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'Manrope',
              color: AppColors.onBackground,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Berikut adalah daftar siswa beserta tingkat kehadiran (keterlambatan) mereka.',
            style: TextStyle(fontSize: 14, color: AppColors.outline),
          ),
          const SizedBox(height: 16),
          _buildSearchAndFilter(),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            ...filteredSiswa.map((siswa) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _buildSiswaCard(
                    context,
                    namaSiswa: siswa['nama'] ?? 'Tanpa Nama',
                    kelas: siswa['class_room'] ?? '-',
                    nisn: siswa['nisn'] ?? '-',
                    tingkat: _capitalize(siswa['tardiness_level'] ?? 'Aman'),
                  ),
                )),
            if (filteredSiswa.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'Tidak ada siswa yang sesuai.',
                    style: TextStyle(color: AppColors.outline),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Cari nama siswa...',
            prefixIcon: const Icon(Icons.search, color: AppColors.outline),
            filled: true,
            fillColor: AppColors.surface,
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
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Semua', 'Aman', 'Ringan', 'Sedang', 'Berat', 'Pemanggilan Orang Tua'].map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.primaryContainer,
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.onBackground,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.surfaceContainerHigh,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSiswaCard(
    BuildContext context, {
    required String namaSiswa,
    required String kelas,
    required String nisn,
    required String tingkat,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(Icons.person, color: AppColors.primary),
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
                const SizedBox(height: 4),
                Text(
                  'Kelas $kelas • NISN: $nisn',
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
}
