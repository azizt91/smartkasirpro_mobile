import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../bloc/history_bloc.dart';
import 'history_detail_page.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/history/data/models/transaction_model.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<HistoryBloc>()..add(LoadHistory()),
      child: const HistoryView(),
    );
  }
}

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  String _selectedFilter = 'Semua'; // Semua, Berhasil, Menunggu, Dibatalkan

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // background-light
      appBar: AppBar(
        title: const Text('Riwayat Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textDark)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textBlack),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<HistoryBloc>().add(LoadHistory()),
          ),
        ],
      ),
      body: BlocConsumer<HistoryBloc, HistoryState>(
        listener: (context, state) {
           if (state is VoidSuccess) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaksi dibatalkan')));
           } else if (state is HistoryError) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
           }
        },
        builder: (context, state) {
          if (state is HistoryLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is HistoryLoaded) {
            // Unfiltered list for summary calculation
            final allTransactions = state.transactions;
            
            // Filter out invalid/stale pending transactions (Code 'PENDING' with 0 amount)
            final validTransactions = allTransactions.where((tx) {
              return !(tx.transactionCode == 'PENDING' && tx.totalAmount == 0);
            }).toList();

            // Filtered list for display
            final filteredTransactions = _filterTransactions(validTransactions);
            final groups = HistoryLoaded.groupTransactions(filteredTransactions);
            final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

            return RefreshIndicator(
              onRefresh: () async {
                context.read<HistoryBloc>().add(LoadHistory());
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  _buildSummaryCard(validTransactions),
                  const SizedBox(height: 24),
                  _buildFilterTabs(),
                  const SizedBox(height: 16),
                  if (filteredTransactions.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 50),
                        child: Text('Tidak ada transaksi', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ...sortedKeys.map((dateKey) {
                      final transactions = groups[dateKey]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDate(dateKey).toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '${transactions.length} Transaksi',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...transactions.map((tx) => _buildTransactionCard(context, tx)),
                        ],
                      );
                    }),
                    const SizedBox(height: 80), // Bottom padding
                ],
              ),
            );
          }
          return const Center(child: Text('Memuat...'));
        },
      ),
    );
  }

  Widget _buildSummaryCard(List<TransactionModel> transactions) {
    // Calculate today's sales
    final today = DateTime.now();
    
    double todayTotal = 0;
    int todayCount = 0;

    for (var tx in transactions) {
      // Parse UTC to Local Time before checking if it's today
      final localDate = DateTime.parse(tx.createdAt).toLocal();
      final isToday = localDate.year == today.year && localDate.month == today.month && localDate.day == today.day;
      
      // Hitung hanya transaksi yang berhasil DAN BUKAN utang
      if (isToday && tx.status != 'void' && tx.paymentMethod != 'utang') {
        todayTotal += tx.totalAmount;
        todayCount++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Penjualan Hari Ini',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(todayTotal),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textBlack,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Update',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.receipt_long, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '$todayCount Transaksi',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              const Icon(Icons.schedule, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Update: ${DateFormat('HH:mm').format(DateTime.now())}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('Semua', isSelected: _selectedFilter == 'Semua'),
          const SizedBox(width: 8),
          _buildFilterChip('Berhasil', isSelected: _selectedFilter == 'Berhasil'),
          const SizedBox(width: 8),
          _buildFilterChip('Menunggu', isSelected: _selectedFilter == 'Menunggu'), // Utang
          const SizedBox(width: 8),
          _buildFilterChip('Belum Bayar', isSelected: _selectedFilter == 'Belum Bayar'), // Unpaid (Resto)
          const SizedBox(width: 8),
          _buildFilterChip('Dibatalkan', isSelected: _selectedFilter == 'Dibatalkan'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {required bool isSelected}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  List<TransactionModel> _filterTransactions(List<TransactionModel> transactions) {
    if (_selectedFilter == 'Semua') return transactions;
    if (_selectedFilter == 'Berhasil') {
      return transactions.where((tx) => tx.status != 'void' && tx.paymentMethod != 'utang' && tx.paymentStatus == 'paid').toList();
    }
    if (_selectedFilter == 'Menunggu') {
      return transactions.where((tx) => tx.status != 'void' && tx.paymentMethod == 'utang').toList();
    }
    if (_selectedFilter == 'Belum Bayar') {
      return transactions.where((tx) => tx.status != 'void' && tx.paymentStatus == 'unpaid').toList();
    }
    if (_selectedFilter == 'Dibatalkan') {
      return transactions.where((tx) => tx.status == 'void').toList();
    }
    return transactions;
  }

  Widget _buildTransactionCard(BuildContext context, TransactionModel tx) {
    // Determine status and style based on payment method
    String status = 'Berhasil';
    Color statusColor = Colors.green;
    Color statusBgColor = Colors.green.shade50;
    IconData icon = Icons.qr_code;
    Color iconColor = Colors.blue.shade600;
    Color iconBgColor = Colors.blue.shade50;

    if (tx.status == 'void') { // Check for void status
      status = 'Dibatalkan';
      statusColor = Colors.red;
      statusBgColor = Colors.red.shade50;
      icon = Icons.block;
      iconColor = Colors.red.shade600;
      iconBgColor = Colors.red.shade50;
    } else if (tx.paymentStatus == 'unpaid') {
      status = 'Belum Bayar';
      statusColor = Colors.orange.shade700;
      statusBgColor = Colors.orange.shade100;
      icon = Icons.pause_circle_outline;
      iconColor = Colors.orange.shade600;
      iconBgColor = Colors.orange.shade50;
    } else if (tx.paymentMethod == 'utang') {
      status = 'Menunggu';
      statusColor = Colors.orange.shade700;
      statusBgColor = Colors.orange.shade100;
      icon = Icons.payments;
      iconColor = Colors.orange.shade600;
      iconBgColor = Colors.orange.shade50;
    } else if (tx.paymentMethod == 'cash') {
       icon = Icons.attach_money;
       iconColor = Colors.green.shade600;
       iconBgColor = Colors.green.shade50;
    } else {
       icon = Icons.credit_card;
       iconColor = Colors.blue.shade600;
       iconBgColor = Colors.blue.shade50;
    }

    // Attempt to extract item count and first item name from payload
    String itemsSummary = '${tx.payload['items']?.length ?? 0} Item';
    if (tx.payload['items'] != null && (tx.payload['items'] as List).isNotEmpty) {
      final firstItem = (tx.payload['items'] as List).first;
      // Depending on payload structure, it might be 'product_name' or nested.
      // Based on TransactionController index method: items.product
      // But TransactionModel might parse it differently. 
      // Safely try to get product name.
      String productName = '';
      if (firstItem['product_name'] != null) {
          productName = firstItem['product_name'];
      } else if (firstItem['product'] != null && firstItem['product']['name'] != null) {
          productName = firstItem['product']['name'];
      }
      
      if (productName.isNotEmpty) {
        itemsSummary += ' • $productName';
      }
    }
    
    // Check if synced
    if (!tx.isSynced) {
       itemsSummary = 'Belum Sinkron • $itemsSummary';
    }

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => HistoryDetailModal(transaction: tx),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tx.transactionCode,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textBlack,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('HH:mm').format(DateTime.parse(tx.createdAt).toLocal())} • ${tx.paymentMethod.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        itemsSummary,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(tx.totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textBlack,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return 'Hari Ini, ${DateFormat('d MMM').format(date)}';
      }
      if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
        return 'Kemarin, ${DateFormat('d MMM').format(date)}';
      }
      return DateFormat('d MMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
