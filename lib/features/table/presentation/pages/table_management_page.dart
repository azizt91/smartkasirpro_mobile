import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import '../bloc/table_bloc.dart';
import '../bloc/table_event.dart';
import '../bloc/table_state.dart';
import '../../data/models/table_model.dart';
import '../../../../injection_container.dart' as di;
import '../widgets/table_form_dialog.dart';

class TableManagementPage extends StatelessWidget {
  const TableManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => di.sl<TableBloc>()..add(LoadTables()),
      child: const TableManagementView(),
    );
  }
}

class TableManagementView extends StatefulWidget {
  const TableManagementView({super.key});

  @override
  State<TableManagementView> createState() => _TableManagementViewState();
}

class _TableManagementViewState extends State<TableManagementView> {
  void _showFormDialog(BuildContext context, {TableModel? table}) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return TableFormDialog(
          table: table,
          onSubmit: (namaMeja, status) {
            if (table == null) {
              context.read<TableBloc>().add(CreateTable(namaMeja: namaMeja));
            } else {
              context.read<TableBloc>().add(UpdateTable(id: table.id, namaMeja: namaMeja, status: status));
            }
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, TableModel table) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Meja'),
        content: Text('Apakah Anda yakin ingin menghapus meja "${table.namaMeja}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              context.read<TableBloc>().add(DeleteTable(id: table.id));
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, TableModel table) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kosongkan Meja'),
        content: Text('Apakah pelanggan di meja "${table.namaMeja}" sudah selesai dan meja sudah bersih?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              context.read<TableBloc>().add(ClearTable(id: table.id));
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Kosongkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Manajemen Meja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textDark)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: BlocConsumer<TableBloc, TableState>(
        listener: (context, state) {
          if (state is TableOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.green),
            );
          } else if (state is TableError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state is TableLoading && state is! TableLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          List<TableModel> displayList = [];
          if (state is TableLoaded) {
            displayList = state.tables;
          }

          if (displayList.isEmpty && state is! TableLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.table_restaurant_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada data meja, silakan tambahkan meja.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16).copyWith(bottom: 80),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: displayList.length,
            itemBuilder: (context, index) {
              final table = displayList[index];
              final isAvailable = table.status == 'available';

              return Container(
                decoration: BoxDecoration(
                  color: isAvailable ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isAvailable ? Colors.green.shade300 : Colors.red.shade300,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.table_restaurant,
                      size: 48,
                      color: isAvailable ? Colors.green.shade600 : Colors.red.shade600,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      table.namaMeja,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isAvailable ? Colors.green.shade900 : Colors.red.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAvailable ? 'Tersedia' : 'Terisi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isAvailable ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!isAvailable)
                          IconButton(
                            icon: const Icon(Icons.cleaning_services, color: Colors.green),
                            iconSize: 20,
                            onPressed: () => _confirmClear(context, table),
                            tooltip: 'Kosongkan Meja',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                        if (!isAvailable) const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          iconSize: 20,
                          onPressed: () => _showFormDialog(context, table: table),
                          tooltip: 'Edit Meja',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          iconSize: 20,
                          onPressed: () => _confirmDelete(context, table),
                          tooltip: 'Hapus Meja',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(context),
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
