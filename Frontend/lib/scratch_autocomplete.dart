import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: Scaffold(body: SafeArea(child: ScratchAutocomplete()))));

class ScratchAutocomplete extends StatefulWidget {
  const ScratchAutocomplete({Key? key}) : super(key: key);
  @override
  State<ScratchAutocomplete> createState() => _ScratchAutocompleteState();
}

class _ScratchAutocompleteState extends State<ScratchAutocomplete> {
  final List<Map<String, dynamic>> _siswaList = [
    {'id': 1, 'nama': 'Budi Santoso'},
    {'id': 2, 'nama': 'Siti Aminah'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Autocomplete<Map<String, dynamic>>(
            displayStringForOption: (option) => option['nama'] ?? 'Tanpa Nama',
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return _siswaList;
              }
              return _siswaList.where((siswa) {
                final nama = (siswa['nama'] ?? '').toLowerCase();
                return nama.contains(textEditingValue.text.toLowerCase());
              });
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 250,
                      maxWidth: MediaQuery.of(context).size.width - 48,
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          title: Text(option['nama'] ?? 'Tanpa Nama'),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
