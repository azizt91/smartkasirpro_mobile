import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/pos_bloc.dart';

class PendingOrdersSheet extends StatefulWidget {
  const PendingOrdersSheet({super.key});

  @override
  State<PendingOrdersSheet> createState() => _PendingOrdersSheetState();
}

class _PendingOrdersSheetState extends State<PendingOrdersSheet> {
  @override
  void initState() {
    super.initState();
    // Fetch latest pending orders when opened
    context.read<PosBloc>().add(FetchPendingOrders());
  }

  void _bukaProsesPesanan(Map<String, dynamic> order) {
    context.read<PosBloc>().add(BukaProsesPesanan(order));
    Navigator.pop(context); // Close the sheet
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pesanan ${order['transaction_code']} dimasukkan ke keranjang'),
        backgroundColor: const Color(0xFF1B9C5E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.notifications_active, color: Colors.amber, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Antrean Pesanan Masuk',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Pesanan dari pelanggan via QR Code',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // List
              Expanded(
                child: BlocBuilder<PosBloc, PosState>(
                  builder: (context, state) {
                    if (state.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state.error != null && state.pendingOrders.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Text(state.error!, style: const TextStyle(color: Colors.red)),
                            TextButton(
                              onPressed: () => context.read<PosBloc>().add(FetchPendingOrders()),
                              child: const Text('Coba Lagi'),
                            )
                          ],
                        ),
                      );
                    }

                    if (state.pendingOrders.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text(
                              'Belum ada pesanan masuk',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        context.read<PosBloc>().add(FetchPendingOrders());
                      },
                      child: ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.all(16),
                        itemCount: state.pendingOrders.length,
                        itemBuilder: (context, index) {
                          final order = state.pendingOrders[index];
                          return _buildOrderCard(order);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    
    // Safety checks for API response
    final totalAmount = double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0;
    final tableName = order['table_name'] ?? '-';
    final customerName = order['customer_name'] ?? 'Pelanggan';
    final transactionCode = order['transaction_code'] ?? 'Unknown';
    final paymentStatus = order['payment_status'] ?? 'unpaid';
    final items = order['items'] as List<dynamic>? ?? [];
    DateTime? createdAt;
    if (order['created_at'] != null) {
      createdAt = DateTime.tryParse(order['created_at'].toString());
    }
    
    // Payment Status UI
    Color paymentStatusColor = paymentStatus == 'paid' ? const Color(0xFF1B9C5E) : Colors.orange;
    String paymentStatusText = paymentStatus == 'paid' ? 'SUDAH BAYAR' : 'BELUM LUNAS';

    // Kitchen Status UI
    final kitchenStatus = order['order_status'] ?? 'pending';
    Color kitchenStatusColor;
    String kitchenStatusText;
    
    if (kitchenStatus == 'pending') {
      kitchenStatusColor = Colors.orange.shade700;
      kitchenStatusText = 'DAPUR: MENUNGGU';
    } else if (kitchenStatus == 'processing') {
      kitchenStatusColor = Colors.blue.shade700;
      kitchenStatusText = 'DAPUR: DIMASAK';
    } else {
      kitchenStatusColor = const Color(0xFF1B9C5E);
      kitchenStatusText = 'DAPUR: SELESAI';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.table_restaurant, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          'Meja $tableName',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$transactionCode • $customerName',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    if (createdAt != null)
                      Text(
                        DateFormat('HH:mm').format(createdAt),
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: paymentStatusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        paymentStatusText,
                        style: TextStyle(color: paymentStatusColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: kitchenStatusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        kitchenStatusText,
                        style: TextStyle(color: kitchenStatusColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Items Preview
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...items.take(3).map((item) {
                   return Padding(
                     padding: const EdgeInsets.only(bottom: 8.0),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Expanded(
                           child: Text(
                              '${item['qty']}x ${item['name']}',
                              style: const TextStyle(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                           ),
                         ),
                         Text(
                           currencyFormatter.format((item['price'] * item['qty'])),
                           style: TextStyle(color: Colors.grey.shade700),
                         ),
                       ],
                     ),
                   );
                }).toList(),
                if (items.length > 3)
                   Text(
                     '+ ${items.length - 3} item lainnya', 
                     style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic, fontSize: 12)
                   ),
                
                const Divider(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text(
                      currencyFormatter.format(totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Action Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ElevatedButton(
              onPressed: () => _bukaProsesPesanan(order),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B9C5E),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_checkout, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Buka & Proses Pesanan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
