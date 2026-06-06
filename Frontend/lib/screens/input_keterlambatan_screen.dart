import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../main.dart';

class InputKeterlambatanScreen extends StatefulWidget {
  const InputKeterlambatanScreen({super.key});

  @override
  State<InputKeterlambatanScreen> createState() =>
      _InputKeterlambatanScreenState();
}

class _InputKeterlambatanScreenState extends State<InputKeterlambatanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _alasanController = TextEditingController();
  final _waktuController = TextEditingController();
  final _tanggalController = TextEditingController();

  // For student search
  final _siswaSearchController = TextEditingController();
  final _siswaFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  DateTime _selectedDate = DateTime.now();
  String? _selectedUserId;
  String? _selectedNama;
  List<Map<String, dynamic>> _siswaList = [];
  List<Map<String, dynamic>> _filteredSiswa = [];
  bool _isLoadingSiswa = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchSiswa();
    // Pre-fill with today's date
    final now = DateTime.now();
    _tanggalController.text =
        "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    _siswaFocusNode.addListener(() {
      if (!_siswaFocusNode.hasFocus) {
        _removeOverlay();
        // If user typed something but didn't select, revert to last selected
        if (_selectedNama != null &&
            _siswaSearchController.text != _selectedNama) {
          _siswaSearchController.text = _selectedNama!;
        } else if (_selectedNama == null) {
          _siswaSearchController.clear();
        }
      }
    });
  }

  Future<void> _fetchSiswa() async {
    try {
      final response = await supabase
          .from('users')
          .select('id, nama, class_room')
          .eq('role_id', 3)
          .order('nama');

      if (mounted) {
        setState(() {
          _siswaList = List<Map<String, dynamic>>.from(response);
          _filteredSiswa = _siswaList;
          _isLoadingSiswa = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSiswa = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat daftar siswa: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _filterSiswa(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSiswa = _siswaList;
      } else {
        _filteredSiswa = _siswaList.where((siswa) {
          final nama = (siswa['nama'] ?? '').toLowerCase();
          return nama.contains(query.toLowerCase());
        }).toList();
      }
    });
    // Update overlay after filtering
    _overlayEntry?.markNeedsBuild();
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) {
        return Positioned(
          width: size.width - 48,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 56),
            child: StatefulBuilder(
              builder: (context, setOverlayState) {
                // Listen to filtered list
                final list = _filteredSiswa;
                return Material(
                  elevation: 12,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.surface,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: list.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    color: AppColors.outline,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Siswa tidak ditemukan',
                                    style: TextStyle(color: AppColors.outline),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              shrinkWrap: true,
                              itemCount: list.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1, indent: 56),
                              itemBuilder: (context, index) {
                                final siswa = list[index];
                                final nama = siswa['nama'] ?? 'Tanpa Nama';
                                final kelas = siswa['class_room'] ?? '-';
                                final initial = nama.isNotEmpty
                                    ? nama[0].toUpperCase()
                                    : '?';
                                return InkWell(
                                  onTap: () {
                                    _siswaSearchController.text = nama;
                                    setState(() {
                                      _selectedUserId = siswa['id'].toString();
                                      _selectedNama = nama;
                                    });
                                    _removeOverlay();
                                    _siswaFocusNode.unfocus();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor:
                                              AppColors.primaryContainer,
                                          child: Text(
                                            initial,
                                            style: const TextStyle(
                                              color:
                                                  AppColors.onPrimaryContainer,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                nama,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.onBackground,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                'Kelas $kelas',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.outline,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 12,
                                          color: AppColors.outlineVariant,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _siswaSearchController.dispose();
    _siswaFocusNode.dispose();
    _alasanController.dispose();
    _waktuController.dispose();
    _tanggalController.dispose();
    _removeOverlay();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.onBackground,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _tanggalController.text =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  Future<void> _submitForm() async {
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan cari dan pilih siswa dari daftar saran'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        final reporterId = supabase.auth.currentUser?.id;
        final duration = int.parse(_waktuController.text);

        String level = 'Ringan';
        if (duration > 15 && duration <= 30) {
          level = 'Sedang';
        } else if (duration > 30) {
          level = 'Berat';
        }

        final now = DateTime.now();
        final waktuStr =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';
        final dateStr =
            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

        await supabase.from('attendance').insert({
          'user_id': _selectedUserId,
          'reporter_id': reporterId,
          'tanggal': dateStr,
          'waktu': waktuStr,
          'duration_minutes': duration,
          'level': level,
          'task_status': 'pending_task',
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Data keterlambatan berhasil disimpan'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
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
        iconTheme: const IconThemeData(color: AppColors.onBackground),
        title: const Text(
          'Input Keterlambatan',
          style: TextStyle(
            color: AppColors.onBackground,
            fontWeight: FontWeight.bold,
            fontFamily: 'Manrope',
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          _removeOverlay();
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Catat Data Siswa',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Manrope',
                    color: AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pastikan data yang dimasukkan sesuai dengan kondisi sebenarnya.',
                  style: TextStyle(fontSize: 14, color: AppColors.outline),
                ),
                const SizedBox(height: 32),

                // Nama Siswa - Custom Search Field with Overlay Suggestions
                _buildLabel('Nama Lengkap Siswa'),
                CompositedTransformTarget(
                  link: _layerLink,
                  child: TextFormField(
                    controller: _siswaSearchController,
                    focusNode: _siswaFocusNode,
                    readOnly: _isLoadingSiswa,
                    onTap: () {
                      if (!_isLoadingSiswa) {
                        _filterSiswa(_siswaSearchController.text);
                        _showOverlay();
                      }
                    },
                    onChanged: (value) {
                      // Clear selection if user edits text manually
                      if (_selectedNama != null && value != _selectedNama) {
                        setState(() {
                          _selectedUserId = null;
                          _selectedNama = null;
                        });
                      }
                      _filterSiswa(value);
                      if (_overlayEntry == null) {
                        _showOverlay();
                      } else {
                        _overlayEntry?.markNeedsBuild();
                      }
                    },
                    decoration:
                        _inputDecoration(
                          _isLoadingSiswa
                              ? 'Memuat data siswa...'
                              : 'Cari nama siswa...',
                          Icons.search,
                        ).copyWith(
                          suffixIcon: _isLoadingSiswa
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : _selectedUserId != null
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                )
                              : const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.outline,
                                ),
                        ),
                    validator: (value) {
                      if (_selectedUserId == null) {
                        return 'Silakan pilih siswa dari daftar saran';
                      }
                      return null;
                    },
                  ),
                ),

                // Show selected student info
                if (_selectedNama != null && _selectedUserId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_pin,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Terpilih: $_selectedNama',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Tanggal Keterlambatan
                _buildLabel('Tanggal Keterlambatan'),
                TextFormField(
                  controller: _tanggalController,
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  decoration: _inputDecoration(
                    'Pilih Tanggal',
                    Icons.calendar_today_outlined,
                  ),
                  validator: (_) => null,
                ),
                const SizedBox(height: 20),

                // Lama Keterlambatan
                _buildLabel('Lama Keterlambatan (Menit)'),
                TextFormField(
                  controller: _waktuController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(
                    'Contoh: 15',
                    Icons.timer_outlined,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lama keterlambatan tidak boleh kosong';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Masukkan angka yang valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Alasan
                _buildLabel('Alasan Keterlambatan (Opsional)'),
                TextFormField(
                  controller: _alasanController,
                  maxLines: 3,
                  decoration: _inputDecoration(
                    'Masukkan alasan keterlambatan...',
                    Icons.notes,
                  ).copyWith(alignLabelWithHint: true),
                  validator: (_) => null,
                ),
                const SizedBox(height: 40),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
                            'Simpan Data',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Manrope',
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.onBackground,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.outlineVariant),
      prefixIcon: Icon(icon, color: AppColors.outline),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.surfaceVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.surfaceVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
