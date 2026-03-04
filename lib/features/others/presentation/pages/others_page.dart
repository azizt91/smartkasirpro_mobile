import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:mobile_app/features/settings/presentation/pages/printer_settings_page.dart';
import 'package:mobile_app/features/history/presentation/pages/history_page.dart';
import 'package:mobile_app/features/others/presentation/pages/customer_page.dart';
import 'package:mobile_app/features/expense/presentation/pages/expense_page.dart';
import 'package:mobile_app/features/expense/data/repositories/expense_repository_impl.dart';
import 'package:mobile_app/features/expense/domain/repositories/expense_repository.dart';
import 'package:mobile_app/features/product/presentation/bloc/product_bloc.dart';
import 'package:mobile_app/features/product/data/repositories/sync_repository_impl.dart';
import 'package:mobile_app/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:mobile_app/core/services/shift_service.dart';
import 'package:mobile_app/features/pos/presentation/widgets/shift_dialog.dart';
import 'package:mobile_app/features/table/presentation/pages/table_management_page.dart';
import 'package:mobile_app/features/settings/presentation/pages/notification_settings_page.dart';


class OthersPage extends StatelessWidget {
  const OthersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        bool isResto = false;
        if (authState is AuthAuthenticated) {
           isResto = authState.user.settings['business_mode'] == 'resto';
        }

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            title: const Text('Lainnya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textDark)),
            backgroundColor: AppColors.surfaceLight,
            elevation: 0,
            centerTitle: false,
            iconTheme: const IconThemeData(color: Colors.black),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Transaksi Section
                _buildSectionHeader('Transaksi'),
                _buildSectionContainer([
                  if (isResto) ...[
                    _buildMenuItem(
                      context,
                      icon: Icons.table_restaurant,
                      label: 'Manajemen Meja',
                      iconColor: Colors.deepOrange,
                      bgColor: Colors.deepOrange.withOpacity(0.1),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TableManagementPage())),
                    ),
                    _buildDivider(),
                  ],
                  _buildMenuItem(
                    context,
                    icon: Icons.history,
                    label: 'Riwayat Transaksi',
                    iconColor: Colors.blue,
                    bgColor: Colors.blue.withOpacity(0.1),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryPage())),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    context,
                    icon: Icons.people_alt,
                    label: 'Pelanggan',
                    iconColor: Colors.orange,
                    bgColor: Colors.orange.withOpacity(0.1),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomerPage())),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    context,
                    icon: Icons.account_balance_wallet,
                    label: 'Pengeluaran Operasional',
                    iconColor: Colors.purple,
                    bgColor: Colors.purple.withOpacity(0.1),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ExpensePage())),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    context,
                    icon: Icons.access_time_filled,
                    label: 'Tutup Shift Kasir',
                    iconColor: Colors.teal,
                    bgColor: Colors.teal.withOpacity(0.1),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => CloseShiftDialog(
                          shiftService: GetIt.instance<ShiftService>(),
                          onShiftClosed: () {},
                        ),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 24),

                // Pengaturan Section
                _buildSectionHeader('Pengaturan'),
                _buildSectionContainer([
                  _buildMenuItem(
                    context,
                    icon: Icons.print,
                    label: 'Pengaturan Printer',
                    iconColor: Colors.grey.shade700,
                    bgColor: Colors.grey.shade200,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrinterSettingsPage())),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    context,
                    icon: Icons.notifications_active,
                    label: 'Nada Notifikasi',
                    iconColor: Colors.amber.shade700,
                    bgColor: Colors.amber.shade50,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationSettingsPage())),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    context,
                    icon: Icons.sync,
                    label: 'Sinkronisasi Data',
                    iconColor: Colors.blue.shade700,
                    bgColor: Colors.blue.shade50,
                    onTap: () => _showSyncDialog(context),
                  ),
                ]),
                const SizedBox(height: 24),

                // Akun Section
                _buildSectionHeader('Akun'),
                _buildSectionContainer([
                  _buildMenuItem(
                    context,
                    icon: Icons.logout,
                    label: 'Keluar',
                    textColor: Colors.red,
                    iconColor: Colors.red,
                    bgColor: Colors.red.withOpacity(0.1),
                    onTap: () {
                       context.read<AuthBloc>().add(AuthLogoutRequested());
                    },
                  ),
                ]),
                
                const SizedBox(height: 40),
                Center(
                   child: Text('Smart Kasir Pro v1.0.0', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }



  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSectionContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
           BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
           ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
    Color? bgColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor ?? Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor ?? Colors.grey.shade600, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textColor ?? Colors.black87,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey.shade50);
  }

  void _showSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const _SyncProgressDialog(),
    );
  }

}

/// Sync Progress Dialog — syncs all data types with step-by-step progress.
class _SyncProgressDialog extends StatefulWidget {
  const _SyncProgressDialog();

  @override
  State<_SyncProgressDialog> createState() => _SyncProgressDialogState();
}

class _SyncProgressDialogState extends State<_SyncProgressDialog> {
  final List<_SyncStep> _steps = [
    _SyncStep(label: 'Pengeluaran (pending)', icon: Icons.account_balance_wallet),
    _SyncStep(label: 'Transaksi (pending)', icon: Icons.receipt_long),
    _SyncStep(label: 'Produk & Kategori', icon: Icons.inventory_2),
  ];
  bool _isDone = false;
  int _successCount = 0;
  int _errorCount = 0;

  @override
  void initState() {
    super.initState();
    _runSync();
  }

  Future<void> _runSync() async {
    final sl = GetIt.instance;

    // Step 1: Sync pending expenses
    _setStepStatus(0, _StepStatus.loading);
    try {
      final expenseRepo = sl<ExpenseRepository>();
      await expenseRepo.syncPendingExpenses();
      _setStepStatus(0, _StepStatus.success);
      _successCount++;
    } catch (e) {
      _setStepStatus(0, _StepStatus.error, message: e.toString());
      _errorCount++;
    }

    // Step 2: Sync pending transactions
    _setStepStatus(1, _StepStatus.loading);
    try {
      final txRepo = sl<TransactionRepository>();
      final error = await txRepo.syncPendingTransactions();
      if (error != null) {
        _setStepStatus(1, _StepStatus.error, message: error);
        _errorCount++;
      } else {
        _setStepStatus(1, _StepStatus.success);
        _successCount++;
      }
    } catch (e) {
      _setStepStatus(1, _StepStatus.error, message: e.toString());
      _errorCount++;
    }

    // Step 3: Sync products & categories from server
    _setStepStatus(2, _StepStatus.loading);
    try {
      final syncRepo = sl<SyncRepository>();
      final result = await syncRepo.syncProducts();
      result.fold(
        (f) {
          _setStepStatus(2, _StepStatus.error, message: f.message);
          _errorCount++;
        },
        (_) {
          _setStepStatus(2, _StepStatus.success);
          _successCount++;
        },
      );
    } catch (e) {
      _setStepStatus(2, _StepStatus.error, message: e.toString());
      _errorCount++;
    }

    if (mounted) setState(() => _isDone = true);
  }

  void _setStepStatus(int index, _StepStatus status, {String? message}) {
    if (!mounted) return;
    setState(() {
      _steps[index].status = status;
      _steps[index].errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Icon(
              _isDone
                  ? (_errorCount == 0 ? Icons.check_circle_rounded : Icons.warning_amber_rounded)
                  : Icons.sync_rounded,
              size: 48,
              color: _isDone
                  ? (_errorCount == 0 ? const Color(0xFF1B9C5E) : Colors.orange)
                  : Colors.blue.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              _isDone ? 'Sinkronisasi Selesai' : 'Sinkronisasi Data...',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_isDone) ...[
              const SizedBox(height: 4),
              Text(
                '$_successCount berhasil, $_errorCount gagal',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 20),

            // Steps
            ...List.generate(_steps.length, (i) {
              final step = _steps[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    _buildStepIcon(step.status),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.label,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          if (step.errorMessage != null)
                            Text(
                              step.errorMessage!.length > 60
                                  ? '${step.errorMessage!.substring(0, 60)}...'
                                  : step.errorMessage!,
                              style: const TextStyle(fontSize: 11, color: Colors.red),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 20),

            // Close button
            if (_isDone)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Refresh product list
                    try {
                      // ignore: use_build_context_synchronously
                      context.read<ProductBloc>().add(LoadProducts());
                    } catch (_) {}
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B9C5E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIcon(_StepStatus status) {
    switch (status) {
      case _StepStatus.waiting:
        return Icon(Icons.circle_outlined, size: 22, color: Colors.grey.shade300);
      case _StepStatus.loading:
        return const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        );
      case _StepStatus.success:
        return const Icon(Icons.check_circle, size: 22, color: Color(0xFF1B9C5E));
      case _StepStatus.error:
        return const Icon(Icons.error, size: 22, color: Colors.red);
    }
  }
}

enum _StepStatus { waiting, loading, success, error }

class _SyncStep {
  final String label;
  final IconData icon;
  _StepStatus status;
  String? errorMessage;

  _SyncStep({
    required this.label,
    required this.icon,
    this.status = _StepStatus.waiting,
    this.errorMessage,
  });
}
