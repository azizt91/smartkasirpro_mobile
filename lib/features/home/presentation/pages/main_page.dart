import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:mobile_app/features/dashboard/presentation/bloc/dashboard_bloc.dart'; // Contains Bloc, Events, States
import 'package:mobile_app/features/pos/presentation/pages/pos_page.dart';
import 'package:mobile_app/features/others/presentation/pages/others_page.dart';
import 'package:mobile_app/features/stock/presentation/pages/stock_page.dart';
import 'package:mobile_app/features/receivable/presentation/pages/receivable_page.dart';
import 'package:mobile_app/features/kitchen/presentation/pages/kitchen_page.dart'; // NEW
import 'package:mobile_app/features/product/presentation/bloc/product_bloc.dart'; // Import
import 'package:mobile_app/features/stock/presentation/bloc/stock_bloc.dart'; // Import StockBloc
import 'package:mobile_app/core/services/notification_service.dart'; // Import NotificationService
import 'package:mobile_app/features/auth/presentation/bloc/auth_bloc.dart'; // Import AuthBloc
import 'package:mobile_app/features/auth/presentation/bloc/auth_event.dart'; // Import AuthEvent
import 'package:mobile_app/features/auth/presentation/bloc/auth_state.dart'; // Import AuthState
import 'package:mobile_app/features/notification/presentation/bloc/notification_bloc.dart'; // Import
import 'package:mobile_app/features/notification/presentation/bloc/notification_event.dart'; // Import
import 'package:firebase_messaging/firebase_messaging.dart'; // Import

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    // Trigger Sync whenever MainPage is loaded (especially for fresh install)
    context.read<ProductBloc>().add(SyncProducts());
    context.read<DashboardBloc>().add(LoadDashboardData()); // Load Dashboard immediately
    
    // Sync FCM Token
    _setupNotifications();

    // Listen for foreground messages to refresh badge
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (mounted) {
        context.read<NotificationBloc>().add(RefreshNotifications());
        // NotificationService (initialized in main.dart) already handles showing the banner.
      }
    });
  }

  void _setupNotifications() async {
    try {
      String? token = await NotificationService().getToken();
      if (token != null && mounted) {
        context.read<AuthBloc>().add(AuthUpdateFcmToken(token));
      }
    } catch (e) {
      debugPrint("Error getting FCM token: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductBloc, ProductState>(
      listener: (context, state) {
        if (state is ProductLoaded) {
          // Once products are synced/loaded, refresh Stock and Dashboard
          context.read<StockBloc>().add(LoadStockProducts());
          context.read<DashboardBloc>().add(LoadDashboardData());
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            bool isResto = false;
            if (authState is AuthAuthenticated) {
               isResto = authState.user.settings['business_mode'] == 'resto';
            }

            // Dynamically update pages based on mode
            final pages = [
              DashboardPage(onGoToStock: () => _onItemTapped(1)),
              const StockPage(),
              const PosPage(),
              isResto ? const KitchenPage() : const ReceivablePage(),
              const OthersPage(),
            ];

            return Scaffold(
              backgroundColor: AppColors.backgroundLight,
            body: IndexedStack(
              index: _currentIndex,
              children: pages,
            ),
        floatingActionButton: SizedBox(
          width: 56,
          height: 56,
          child: FloatingActionButton(
            onPressed: () => _onItemTapped(2), // Index 2 is POS
            backgroundColor: AppColors.primary,
            elevation: 4,
            shape: const CircleBorder(), 
            child: const Icon(Icons.point_of_sale, size: 28, color: Colors.white),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          color: Colors.white,
          elevation: 10,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 60, // Fixed height
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(icon: Icons.grid_view_rounded, label: 'Dashboard', index: 0),
                _buildNavItem(icon: Icons.inventory_2_outlined, label: 'Stok', index: 1),
                const SizedBox(width: 40), // Space for FAB
                _buildNavItem(icon: isResto ? Icons.restaurant : Icons.account_balance_wallet_outlined, label: isResto ? 'Dapur' : 'Piutang', index: 3),
                _buildNavItem(icon: Icons.menu, label: 'Lainnya', index: 4),
              ],
            ),
          ),
        ),
      );
    }
  ),
),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque, // Ensures the entire area is clickable
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textGrey,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textGrey,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
