import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../../../injection_container.dart' as di;
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

import 'package:mobile_app/features/notification/presentation/pages/notification_page.dart';
import 'package:mobile_app/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:mobile_app/features/notification/presentation/bloc/notification_state.dart';
import 'package:mobile_app/features/notification/presentation/bloc/notification_event.dart'; // Import Event

class DashboardPage extends StatelessWidget {
  final VoidCallback onGoToStock;
  
  const DashboardPage({super.key, required this.onGoToStock});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            if (state is DashboardLoading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            } else if (state is DashboardError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${state.message}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: () {
                        context.read<DashboardBloc>().add(LoadDashboardData());
                      },
                      child: const Text('Retry', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            } else if (state is DashboardLoaded) {
              return _buildDashboardContent(context, state.data);
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Tidak ada data dashboard.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<DashboardBloc>().add(LoadDashboardData()),
                     child: const Text("Muat Ulang"),
                  )
                ],
              ),
            );
          },
        ),
      );
  }

  Widget _buildDashboardContent(BuildContext context, dynamic data) {
    final stats = data.stats;
    final lowStockProducts = (data.lowStockItems ?? [])
        .where((p) => p['type'] != 'jasa')
        .toList();
    // Note: The API response for 'dashboard' typically has 'stats', 'sales_chart', 'top_products'.
    // Adjusting based on available data.
    
    // Safety checks for nulls
    final todaySales = stats['today_sales_total'] ?? 0;
    final transactionCount = stats['today_transaction_count'] ?? 0;
    final lowStockCount = stats['low_stock_products'] ?? 0;
    
    // Parsing currency
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // Growth Calc
    final yesterdaySales = (stats['yesterday_sales_total'] ?? 0).toDouble();
    final currentSales = (stats['today_sales_total'] ?? 0).toDouble();
    String growth = '0%';
    IconData growthIcon = Icons.remove;
    Color growthColor = AppColors.textGrey;

    if (yesterdaySales > 0) {
      final pct = ((currentSales - yesterdaySales) / yesterdaySales) * 100;
      growth = '${pct > 0 ? "+" : ""}${pct.toStringAsFixed(1)}%';
      growthIcon = pct >= 0 ? Icons.trending_up : Icons.trending_down;
      growthColor = pct >= 0 ? AppColors.success : AppColors.error;
    } else if (currentSales > 0) {
      growth = '+100%';
      growthIcon = Icons.trending_up;
      growthColor = AppColors.success;
    }

    // Chart Data Prep
    final salesChart = (data.salesChart as List<dynamic>?) ?? [];
    double maxSale = 1.0; // Avoid division by zero
    for (var s in salesChart) {
      final total = (s['total'] as num).toDouble();
      if (total > maxSale) maxSale = total;
    }

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          context.read<DashboardBloc>().add(LoadDashboardData()); 
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100), // Space for FAB/BottomNav
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header ---
              _buildHeader(context),

              const SizedBox(height: 24),

              // --- Horizontal Summary Cards ---
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildMainCard(
                      'Penjualan Hari Ini',
                      currencyFormat.format(todaySales),
                      growth,
                      Icons.calendar_today,
                      growthIcon: growthIcon,
                      growthColor: growthColor,
                    ),
                    const SizedBox(width: 16),
                    _buildSmallCard(
                      'Transaksi',
                      transactionCount.toString(),
                      Icons.receipt_long,
                      Colors.green,
                    ),
                    const SizedBox(width: 16),
                    _buildSmallCard(
                      'Perlu Restock',
                      '$lowStockCount Item',
                      Icons.inventory_2,
                      Colors.red,
                    ),
                    // const SizedBox(width: 16),
                    // _buildSmallCard('Piutang', 'Rp 350rb', Icons.account_balance_wallet, Colors.blue),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- Chart Section (Placeholder) ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildChartSection(context, salesChart, maxSale),
              ),

              const SizedBox(height: 24),

              // --- Stock Warning Sections ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildStockWarningSection(lowStockProducts), // You might need to adjust based on actual data structure
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Title + Date
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, d MMM yyyy', 'id_ID').format(DateTime.now()),
                style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
              ),
            ],
          ),
          // Right: Bell + Avatar grouped together
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bell Icon with Red Dot
              BlocBuilder<NotificationBloc, NotificationState>(
                builder: (context, notifState) {
                  int unreadCount = 0;
                  if (notifState is NotificationLoaded) {
                    unreadCount = notifState.unreadCount;
                  }
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none, color: AppColors.textDark),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const NotificationPage()),
                          ).then((_) {
                            context.read<NotificationBloc>().add(RefreshNotifications());
                          });
                        },
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 4),
              // Avatar
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  String initial = '?';
                  if (state is AuthAuthenticated) {
                    initial = state.user.name.isNotEmpty ? state.user.name[0].toUpperCase() : '?';
                  }
                  return CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      initial,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard(
    String title, 
    String value, 
    String growth, 
    IconData icon, 
    {IconData growthIcon = Icons.trending_up, Color growthColor = AppColors.success}
  ) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: AppColors.textGrey),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textGrey)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: growthColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(growthIcon, size: 10, color: growthColor),
                    const SizedBox(width: 4),
                    Text(growth, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: growthColor)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          const Text('Total penjualan berhasil', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
        ],
      ),
    );
  }

  Widget _buildSmallCard(String title, String value, IconData icon, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textGrey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(BuildContext context, List<dynamic> salesChart, double maxSale) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               const Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text('Statistik Penjualan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                   Text('7 Hari Terakhir', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                 ],
               ),
               TextButton(
                 onPressed: () {
                   // Navigate to History Page
                   Navigator.pushNamed(context, '/history');
                 }, 
                 child: const Text('Lihat Detail', style: TextStyle(color: AppColors.primary, fontSize: 12))
               ),
            ],
          ),
          const SizedBox(height: 20),
          // Dynamic Chart
          salesChart.isEmpty 
          ? const SizedBox(height: 100, child: Center(child: Text('Belum ada data', style: TextStyle(color: Colors.grey))))
          : Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: salesChart.map<Widget>((s) {
              final total = (s['total'] as num).toDouble();
              final dayNameRaw = s['day_name'].toString();
              final dayName = dayNameRaw.length > 3 ? dayNameRaw.substring(0, 3) : dayNameRaw;
              final heightPct = total / maxSale;
              // Simple check for "today" by comparing dates
              final isToday = s['date'] == DateFormat('yyyy-MM-dd').format(DateTime.now());
              final valueLabel = _formatCompactCurrency(total);
              
              return _buildBar(dayName, heightPct, isToday, valueLabel);
            }).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildBar(String label, double heightPct, bool isActive, String valueLabel) {
    // Show green if active (today) OR if it has data
    final hasData = heightPct > 0;
    final isGreen = isActive || hasData;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          valueLabel,
          style: TextStyle(
            fontSize: 10, 
            fontWeight: isGreen ? FontWeight.bold : FontWeight.normal,
            color: isGreen ? AppColors.primary : AppColors.textGrey,
          )
        ),
        const SizedBox(height: 4),
        Container(
          width: 30, // Fixed width bars
          height: 120 * heightPct, // Max height 120
          decoration: BoxDecoration(
            color: isGreen ? AppColors.primary : Colors.grey.shade200,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            boxShadow: isGreen ? [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ] : [],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(
          fontSize: 10, 
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive ? AppColors.primary : AppColors.textGrey,
        )),
      ],
    );
  }

  Widget _buildStockWarningSection(List<dynamic> products) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Peringatan Stok', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton(
              onPressed: onGoToStock, 
              child: const Text('Lihat Semua', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold))
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (products.isEmpty)
           const Padding(
             padding: EdgeInsets.all(16.0),
             child: Text('Stok aman.', style: TextStyle(color: AppColors.textGrey)),
           ),
        ...products.map((p) => _buildStockItem(p)).toList(),
      ],
    );
  }

  Widget _buildStockItem(dynamic product) {
    final name = product['name'] ?? 'Unknown';
    final stock = product['stock'] ?? 0;
    final minStock = product['minimum_stock'] ?? 0;
    final image = product['image_url']; // Use the accessor from backend
    final bool isCritical = stock <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
        ],
        border: Border(left: BorderSide(color: isCritical ? AppColors.error : AppColors.warning, width: 3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: image != null && image.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 20, color: Colors.grey),
                    ),
                  )
                : const Icon(Icons.image_not_supported, size: 20, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                Text.rich(
                  TextSpan(
                    text: 'Stok: ',
                    style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                    children: [
                      TextSpan(text: '$stock pcs', style: TextStyle(color: isCritical ? AppColors.error : AppColors.warning, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
             decoration: BoxDecoration(
               color: isCritical ? AppColors.error.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
               borderRadius: BorderRadius.circular(20),
             ),
             child: Text(
               isCritical ? 'HABIS' : 'MENIPIS',
               style: TextStyle(
                 fontSize: 10, 
                 fontWeight: FontWeight.bold,
                 color: isCritical ? AppColors.error : AppColors.warning,
               ),
             ),
           )
        ],
      ),
    );
  }

  String _formatCompactCurrency(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}M';
    } else if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}jt';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}rb';
    }
    return value.toStringAsFixed(0);
  }
}
