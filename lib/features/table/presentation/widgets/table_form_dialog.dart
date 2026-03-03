import 'package:flutter/material.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import '../../data/models/table_model.dart';

class TableFormDialog extends StatefulWidget {
  final TableModel? table;
  final Function(String namaMeja, String status) onSubmit;

  const TableFormDialog({
    super.key,
    this.table,
    required this.onSubmit,
  });

  @override
  State<TableFormDialog> createState() => _TableFormDialogState();
}

class _TableFormDialogState extends State<TableFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaController;
  late String _status;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.table?.namaMeja ?? '');
    _status = widget.table?.status ?? 'available';
  }

  @override
  void dispose() {
    _namaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.table != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Edit Meja' : 'Tambah Meja Baru',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _namaController,
                decoration: InputDecoration(
                  labelText: 'Nama Meja',
                  hintText: 'Contoh: Meja 1, VIP A',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.table_restaurant),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama meja tidak boleh kosong';
                  }
                  return null;
                },
              ),
              if (isEdit) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: InputDecoration(
                    labelText: 'Status Meja',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.info_outline),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'available', child: Text('Tersedia')),
                    DropdownMenuItem(value: 'occupied', child: Text('Terisi')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _status = value);
                    }
                  },
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          widget.onSubmit(
                            _namaController.text,
                            _status,
                          );
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Simpan',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
