import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart' as di;
import '../bloc/kitchen_bloc.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class KitchenPage extends StatelessWidget {
  const KitchenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => di.sl<KitchenBloc>()..add(LoadKitchenOrders()),
      child: const KitchenView(),
    );
  }
}

class KitchenView extends StatefulWidget {
  const KitchenView({super.key});

  @override
  State<KitchenView> createState() => _KitchenViewState();
}

class _KitchenViewState extends State<KitchenView> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        context.read<KitchenBloc>().add(LoadKitchenOrders(isAutoRefresh: true));
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // KDS looks best in tablet landscape, but we make it responsive
    final isTablet = MediaQuery.of(context).size.width >= 900;
    final crossAxisCount = isTablet ? 3 : 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Kitchen Display System', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1A1A2E))),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: () {
              context.read<KitchenBloc>().add(LoadKitchenOrders());
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: BlocConsumer<KitchenBloc, KitchenState>(
        listener: (context, state) {
          if (state.error != null) {
            // Prevent showing background errors repeatedly
            if (ModalRoute.of(context)?.isCurrent == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
              );
            }
          }
        },
        builder: (context, state) {
          if (state.isLoading && state.orders.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Tidak ada pesanan aktif', style: TextStyle(color: Colors.grey.shade600, fontSize: 18)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<KitchenBloc>().add(LoadKitchenOrders());
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isTablet ? 0.7 : 0.8, // Adjust based on height needed
              ),
              itemCount: state.orders.length,
              itemBuilder: (context, index) {
                return _buildOrderCard(context, state.orders[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order) {
    final status = order['order_status'] ?? 'pending';
    final tableName = order['table_name'] ?? '-';
    final items = order['items'] as List<dynamic>? ?? [];
    
    // Takeaway logic
    final isTakeaway = (order['is_takeaway'] == 1 || order['is_takeaway'] == true || tableName.toString().toLowerCase().contains('takeaway'));
    final displayTitle = isTakeaway ? '🛍️ TAKEAWAY' : (tableName == '-' || tableName.toString().isEmpty ? 'Tanpa Meja' : 'Meja $tableName');

    Color headerColor;
    String statusText;
    
    if (status == 'pending') {
      headerColor = isTakeaway ? Colors.purple.shade400 : Colors.orange;
      statusText = 'MENUNGGU';
    } else if (status == 'processing') {
      headerColor = Colors.blue.shade400;
      statusText = 'DIMASAK';
    } else {
      headerColor = const Color(0xFF1B9C5E);
      statusText = 'SELESAI';
    }

    // Calculate elapsed time from created_at
    String timeAgo = '';
    if (order['created_at'] != null) {
      try {
        final createdAt = DateTime.parse(order['created_at']);
        final diff = DateTime.now().difference(createdAt);
        if (diff.inMinutes < 60) {
          timeAgo = '${diff.inMinutes} mnt lalu';
        } else {
          timeAgo = '${diff.inHours} jam lalu';
        }
      } catch (e) {
        timeAgo = order['time'] ?? '';
      }
    } else {
       timeAgo = order['time'] ?? '';
    }

    return RepaintBoundary(
      child: Card(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Colored Left Border Indicator
          Container(
             width: 8,
             color: headerColor,
          ),
          
          // Main Content Area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (White)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayTitle,
                              style: TextStyle(
                                  color: isTakeaway ? Colors.purple.shade800 : const Color(0xFF1A1A2E), 
                                  fontWeight: FontWeight.bold, 
                                  fontSize: isTakeaway ? 18 : 22
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order['transaction_code'] ?? '-',
                              style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                             decoration: BoxDecoration(
                               color: headerColor.withOpacity(0.1),
                               borderRadius: BorderRadius.circular(20),
                               border: Border.all(color: headerColor.withOpacity(0.5))
                             ),
                             child: Text(statusText, style: TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 13)),
                           ),
                           const SizedBox(height: 8),
                           Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               const Icon(Icons.timer_outlined, size: 14, color: Colors.black45),
                               const SizedBox(width: 4),
                               Text(timeAgo, style: const TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.bold)),
                             ],
                           ),
                        ],
                      )
                    ],
                  ),
                ),
                
                // Divider
                const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          
          // Items List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                   padding: const EdgeInsets.only(bottom: 12),
                   child: Row(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        Container(
                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                           decoration: BoxDecoration(
                             color: Colors.grey.shade100,
                             borderRadius: BorderRadius.circular(8)
                           ),
                           child: Text('${item['qty']}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                                Text(item['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                if (item['note'] != null && item['note'].toString().trim().isNotEmpty)
                                   Container(
                                     margin: const EdgeInsets.top(6),
                                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                     decoration: BoxDecoration(
                                        color: Colors.yellow.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.yellow.shade400, width: 0.5)
                                     ),
                                     child: Row(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                          Icon(Icons.edit_note, size: 16, color: Colors.orange.shade800),
                                          const SizedBox(width: 6),
                                          Expanded(child: Text('${item['note']}', style: TextStyle(color: Colors.orange.shade900, fontSize: 13, fontWeight: FontWeight.w500))),
                                       ],
                                     ),
                                   ),
                             ],
                           )
                        ),
                     ],
                   ),
                );
              },
            ),
          ),
          
          // Action Buttons Bottom
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                 if (status == 'pending')
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.blue.shade400,
                           padding: const EdgeInsets.symmetric(vertical: 16),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                           elevation: 0,
                        ),
                        onPressed: () {
                           context.read<KitchenBloc>().add(UpdateOrderStatus(order['transaction_code'], 'processing'));
                        },
                        child: const Text('PROSES (MASAK)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                 
                 if (status == 'processing')
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                           backgroundColor: const Color(0xFF1B9C5E),
                           padding: const EdgeInsets.symmetric(vertical: 16),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                           elevation: 0,
                        ),
                        onPressed: () {
                           context.read<KitchenBloc>().add(UpdateOrderStatus(order['transaction_code'], 'completed'));
                        },
                        child: const Text('SELESAIKAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
              ],
            ),
          )
        ],
      ),
    ),
  );
}
}
