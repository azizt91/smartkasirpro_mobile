import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'scanner_page.dart';
import '../../../../injection_container.dart' as di;
import '../bloc/pos_bloc.dart';
import 'package:mobile_app/features/product/data/models/product_model.dart';
import 'package:mobile_app/features/product/data/models/category_model.dart';
import '../../../../core/utils/receipt_builder.dart'; // Import
import '../widgets/payment_pending_dialog.dart'; // PG Dialog
import '../../../../core/services/printer_service.dart'; // Import
import '../../../auth/presentation/bloc/auth_state.dart';
import '../widgets/success_dialog.dart'; // Import
import '../widgets/pending_orders_sheet.dart'; // NEW: Import Pending Orders Sheet
import 'package:intl/intl.dart';
import '../widgets/payment_modal.dart'; // Add import
import '../widgets/cart_widget.dart'; // Add import
import '../widgets/variant_picker_sheet.dart'; // Variant picker
import '../widgets/shift_dialog.dart'; // Shift dialog
import '../../../../core/services/shift_service.dart'; // Shift service
import '../../../../core/theme/app_colors.dart';

class PosPage extends StatelessWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => di.sl<PosBloc>()..add(LoadPosData()),
      child: const PosView(),
    );
  }
}

class PosView extends StatefulWidget {
  const PosView({super.key});

  @override
  State<PosView> createState() => _PosViewState();
}

class _PosViewState extends State<PosView> {
  bool _shiftChecked = false;
  bool _hasActiveShift = false;

  @override
  void initState() {
    super.initState();
    _checkShift();
  }

  Future<void> _checkShift() async {
    try {
      final shiftService = di.sl<ShiftService>();
      final result = await shiftService.checkShift();
      if (mounted) {
        setState(() {
          _shiftChecked = true;
          _hasActiveShift = result['has_open_shift'] == true;
        });
        if (!_hasActiveShift) {
          _showOpenShiftDialog();
        }
      }
    } catch (e) {
      // If API fails (e.g., offline), allow POS usage
      if (mounted) {
        setState(() {
          _shiftChecked = true;
          _hasActiveShift = true;
        });
      }
    }
  }

  void _showOpenShiftDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => OpenShiftDialog(
        shiftService: di.sl<ShiftService>(),
        onShiftOpened: () {
          setState(() { _hasActiveShift = true; });
        },
      ),
    );
  }

  /// Determine if the current screen is a wide tablet in landscape
  bool _isTabletLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width >= 900;
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = _isTabletLandscape(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Point of Sale', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1A1A2E))),
        actions: [
          // Pending Orders Icon Button
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              bool isResto = false;
              if (authState is AuthAuthenticated) {
                 isResto = authState.user.settings['business_mode'] == 'resto';
              }
              if (!isResto) return const SizedBox.shrink();

              return BlocBuilder<PosBloc, PosState>(
                builder: (context, state) {
                  final pendingCount = state.pendingOrders.length;
                  return IconButton(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_none, size: 28),
                        if (pendingCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                pendingCount.toString(),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          )
                      ],
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => BlocProvider.value(
                          value: context.read<PosBloc>(),
                          child: const PendingOrdersSheet(),
                        ),
                      );
                    },
                  );
                },
              );
            }
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<PosBloc>().add(LoadPosData());
              context.read<PosBloc>().add(FetchPendingOrders()); // Refresh pending orders
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Product List (Left Side)
          Expanded(
            flex: 3,
            child: Column(
              children: [
                 _buildSearchBar(context),
                 _buildCategoryTabs(context),
                 Expanded(child: _buildProductGrid(context)),
              ],
            ),
          ),
          
          // Cart (Right Side) — Only visible on tablet landscape
          if (isTablet)
            SizedBox(
              width: 380,
              child: CartWidget(
                isTablet: true,
                onCheckout: (grandTotal) {
                  _showPaymentModal(context, grandTotal);
                },
              ),
            ),
        ],
      ),
      // Bottom cart bar only on mobile
      bottomNavigationBar: isTablet ? null : _buildBottomCartBar(context),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search product or scan...',
            hintStyle: const TextStyle(color: Colors.grey),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.grey),
                  onPressed: () => _openScanner(context),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.grey),
                  onPressed: () => _openScanner(context),
                ),
                const SizedBox(width: 12),
              ],
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (value) {
            context.read<PosBloc>().add(FilterProducts(query: value));
          },
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(BuildContext context) {
    return BlocBuilder<PosBloc, PosState>(
      buildWhen: (previous, current) => previous.categories != current.categories || previous.selectedCategoryId != current.selectedCategoryId,
      builder: (context, state) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              _buildCategoryPill(context, 0, 'Semua', state.selectedCategoryId == 0),
              ...state.categories.map((cat) => 
                _buildCategoryPill(context, cat.id, cat.name, state.selectedCategoryId == cat.id)
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryPill(BuildContext context, int id, String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: GestureDetector(
        onTap: () {
           context.read<PosBloc>().add(FilterProducts(categoryId: id));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1B9C5E) : Colors.white, // Green for selected
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isSelected ? const Color(0xFF1B9C5E) : Colors.grey.shade300),
            boxShadow: isSelected ? [
               BoxShadow(color: const Color(0xFF1B9C5E).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
            ] : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// Groups filtered products by productGroupId.
  /// Products with has_variants group show as one card.
  /// Single products (no group) show individually.
  List<_DisplayItem> _groupProducts(List<ProductModel> products, List<CartItem> cartItems) {
    final Map<int, List<ProductModel>> grouped = {};
    final List<_DisplayItem> displayItems = [];

    for (final product in products) {
      if (product.productGroupId != null && product.variantName != null && product.variantName!.isNotEmpty) {
        // This product belongs to a variant group
        grouped.putIfAbsent(product.productGroupId!, () => []).add(product);
      } else {
        // Single product without variants
        int qty = 0;
        try {
          final cartItem = cartItems.firstWhere((c) => c.product.id == product.id);
          qty = cartItem.quantity;
        } catch (_) {}
        displayItems.add(_DisplayItem(
          product: product,
          variants: [],
          totalCartQty: qty,
        ));
      }
    }

    // Process variant groups
    for (final entry in grouped.entries) {
      final variants = entry.value;
      if (variants.length <= 1) {
        // Only 1 variant in group — treat as single product
        final product = variants.first;
        int qty = 0;
        try {
          final cartItem = cartItems.firstWhere((c) => c.product.id == product.id);
          qty = cartItem.quantity;
        } catch (_) {}
        displayItems.add(_DisplayItem(
          product: product,
          variants: [],
          totalCartQty: qty,
        ));
      } else {
        // Multiple variants: show group card
        // Use group name (strip variant suffix from first product name)
        final representative = variants.first;
        // Calculate total cart qty across all variants
        int totalQty = 0;
        for (final v in variants) {
          try {
            final cartItem = cartItems.firstWhere((c) => c.product.id == v.id);
            totalQty += cartItem.quantity;
          } catch (_) {}
        }
        displayItems.add(_DisplayItem(
          product: representative,
          variants: variants,
          totalCartQty: totalQty,
        ));
      }
    }

    return displayItems;
  }

  Widget _buildProductGrid(BuildContext context) {
    final isTablet = _isTabletLandscape(context);
    final crossAxisCount = isTablet ? 3 : 2;

    return BlocBuilder<PosBloc, PosState>(
      buildWhen: (previous, current) => previous.filteredProducts != current.filteredProducts || previous.isLoading != current.isLoading || previous.cartItems != current.cartItems,
      builder: (context, state) {
        if (state.isLoading) return const Center(child: CircularProgressIndicator());
        if (state.filteredProducts.isEmpty) return const Center(child: Text('Tidak ada produk'));

        final displayItems = _groupProducts(state.filteredProducts, state.cartItems);

        return GridView.builder(
          padding: const EdgeInsets.all(16.0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.65,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: displayItems.length,
          itemBuilder: (context, index) {
            final item = displayItems[index];
            return _buildProductCard(context, item.product, item.totalCartQty, item.isGroup ? item.variants : null);
          },
        );
      },
    );
  }

  Widget _buildProductCard(BuildContext context, ProductModel product, int cartQty, [List<ProductModel>? variants]) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final isGroup = variants != null && variants.length > 1;
    
    // For groups: derive clean group name (remove variant suffix like " (Hitam - M)")
    String displayName = product.name;
    if (isGroup && product.variantName != null) {
      displayName = product.name.replaceAll(' (${product.variantName})', '');
    }
    // For groups: calculate total stock and price range
    int displayStock = product.stock;
    double minPrice = product.sellingPrice;
    double maxPrice = product.sellingPrice;
    if (isGroup) {
      displayStock = variants!.fold(0, (sum, v) => sum + v.stock);
      minPrice = variants.map((v) => v.sellingPrice).reduce((a, b) => a < b ? a : b);
      maxPrice = variants.map((v) => v.sellingPrice).reduce((a, b) => a > b ? a : b);
    }
    
    return GestureDetector(
      onTap: () {
        if (isGroup) {
          _showVariantPicker(context, displayName, product.image, variants!);
        } else {
          if (product.type == 'jasa') {
             _showEmployeePicker(context, product);
          } else {
             context.read<PosBloc>().add(AddToCart(product));
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      width: double.infinity,
                      color: Colors.grey[100],
                      child: product.image != null && product.image!.isNotEmpty
                          ? Image.network(
                              product.image!, 
                              fit: BoxFit.cover, 
                              errorBuilder: (_,__,___) => const Center(child: Icon(Icons.inventory_2, size: 50, color: Colors.grey))
                            )
                          : const Center(child: Icon(Icons.inventory_2, size: 50, color: Colors.grey)),
                    ),
                  ),
                  // Cart Badge (Top Right)
                  if (cartQty > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B9C5E),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]
                        ),
                        child: Text(
                          '$cartQty',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  // Minus Button (Bottom Right) - ONLY for single products (not variant groups)
                  if (cartQty > 0 && !isGroup)
                    Positioned(
                        bottom: 8,
                        right: 8,
                        child: GestureDetector(
                            onTap: () {
                                if (isGroup) {
                                  // For variant groups, re-open picker to let user manage variants
                                  _showVariantPicker(context, displayName, product.image, variants!);
                                } else {
                                  context.read<PosBloc>().add(UpdateCartQuanity(product, cartQty - 1));
                                }
                            },
                            child: Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.2), blurRadius: 4)],
                                    border: Border.all(color: Colors.red.shade100)
                                ),
                                child: Icon(Icons.remove, color: Colors.red.shade700, size: 20),
                            ),
                        ),
                    ),
                ],
              ),
            ),
            
            // Details Section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                               Text(
                                  displayName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                // Variant count indicator
                                if (isGroup)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '${variants!.length} varian',
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                    ),
                                  ),
                          ],
                      ),
                      // Price & Stock
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                               Flexible(
                                 child: Text(
                                    isGroup && minPrice != maxPrice
                                        ? '${currencyFormatter.format(minPrice)} ~'
                                        : currencyFormatter.format(minPrice),
                                    style: const TextStyle(color: Color(0xFF1B9C5E), fontWeight: FontWeight.bold, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                               ),
                               const SizedBox(width: 4),
                               Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                   decoration: BoxDecoration(
                                       color: const Color(0xFFE8F5E9),
                                       borderRadius: BorderRadius.circular(4),
                                   ),
                                   child: Text(
                                       'Stok: $displayStock',
                                       style: const TextStyle(fontSize: 10, color: Color(0xFF1B9C5E), fontWeight: FontWeight.bold),
                                   ),
                               )
                          ],
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

  Widget _buildBottomCartBar(BuildContext context) {
    return BlocListener<PosBloc, PosState>(
      listener: (context, state) {
        if (state.isSuccess) {
          final lastTransaction = state.lastTransaction;

          // Check if this is a Payment Gateway (pending) transaction
          if (lastTransaction != null && lastTransaction['payment'] != null) {
            // Show Payment Pending Dialog instead of Success Dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => PaymentPendingDialog(
                transaction: lastTransaction,
                payment: Map<String, dynamic>.from(lastTransaction['payment']),
                onDismiss: () {
                  Navigator.pop(context);
                  context.read<PosBloc>().add(ClearCart());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaksi pending. Status akan otomatis berubah saat pelanggan membayar.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
              ),
            );
          } else {
            // Normal cash/card/utang: show Success Dialog with Print Option
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => SuccessDialog(
                onPrint: () async {
                   if (lastTransaction != null) {
                      final receiptBuilder = ReceiptBuilder();
                      
                      // Get Settings from AuthBloc
                      final authState = context.read<AuthBloc>().state;
                      Map<String, dynamic> settings = {};
                      String userName = 'Kasir';
                      
                      if (authState is AuthAuthenticated) {
                         settings = authState.user.settings;
                         userName = authState.user.name;
                      }

                      // Enriched items
                      final items = lastTransaction['items'] as List<dynamic>;
                      
                      // Add username to transaction data for printer
                      final printData = Map<String, dynamic>.from(lastTransaction);
                      printData['user_name'] = userName;

                      try {
                          await receiptBuilder.printReceipt(printData, settings, items);
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text('Sedang mencetak...')),
                           );
                      } catch (e) {
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text('Gagal mencetak: $e')),
                           );
                      }
                   }
                   
                   Navigator.pop(context); // Close dialog
                   context.read<PosBloc>().add(ClearCart()); 
                },
                onClose: () {
                   Navigator.pop(context); // Close dialog
                   context.read<PosBloc>().add(ClearCart()); 
                },
              ),
            );
          }
        }
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
          );
        }
      },
      child: BlocBuilder<PosBloc, PosState>(
        builder: (context, state) {
          if (state.cartItems.isEmpty) return const SizedBox.shrink();
          
          final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

          return Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black.withOpacity(0.1))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${state.cartItems.length} Item', style: const TextStyle(color: Colors.grey)),
                    Text(
                      currencyFormatter.format(state.total),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    _showCartModal(context);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text('Keranjang'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPaymentModal(BuildContext context, double grandTotal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<PosBloc>(),
        child: PaymentModal(totalAmount: grandTotal),
      ),
    );
  }

  void _showCartModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<PosBloc>(),
        child: CartModal(
          onCheckout: (grandTotal) {
            _showPaymentModal(context, grandTotal);
          },
        ),
      ),
    );
  }

  void _openScanner(BuildContext context) async {
    // Check if platform is supported (Android/iOS)
    if (kIsWeb || (!defaultTargetPlatform.name.toLowerCase().contains('android') && !defaultTargetPlatform.name.toLowerCase().contains('ios'))) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Barcode scanning is only supported on Android/iOS devices.')),
       );
       return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerPage()),
    );

    if (result != null && result is String) {
      context.read<PosBloc>().add(ScanBarcode(result));
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Scanned: $result')),
      );
    }
  }

  void _showVariantPicker(BuildContext context, String groupName, String? groupImage, List<ProductModel> variants) {
    // Build cart quantities map from current state
    final cartItems = context.read<PosBloc>().state.cartItems;
    final Map<int, int> cartQuantities = {};
    for (final variant in variants) {
      try {
        final cartItem = cartItems.firstWhere((c) => c.product.id == variant.id);
        cartQuantities[variant.id] = cartItem.quantity;
      } catch (_) {
        cartQuantities[variant.id] = 0;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VariantPickerSheet(
        groupName: groupName,
        groupImage: groupImage,
        variants: variants,
        cartQuantities: cartQuantities,
        onQuantityChanged: (variant, newQty) {
          // Find current qty in cart
          final currentCartItems = context.read<PosBloc>().state.cartItems;
          final existingIndex = currentCartItems.indexWhere((c) => c.product.id == variant.id);
          
          if (existingIndex >= 0) {
            // Already in cart — update quantity
            context.read<PosBloc>().add(UpdateCartQuanity(variant, newQty));
          } else if (newQty > 0) {
            // Not in cart yet — check if jasa
            if (variant.type == 'jasa') {
               Navigator.pop(context); // Close variant picker to show employee picker
               _showEmployeePicker(context, variant);
            } else {
               context.read<PosBloc>().add(AddToCart(variant, quantity: newQty));
            }
          }
        },
      ),
    );
  }

  void _showEmployeePicker(BuildContext context, ProductModel product) {
    // Dynamic Label
    final authState = context.read<AuthBloc>().state;
    String employeeLabel = 'Pegawai';
    if (authState is AuthAuthenticated) {
       employeeLabel = authState.user.settings['employee_label'] ?? 'Pegawai';
    }

    final posState = context.read<PosBloc>().state;
    final List<Map<String, dynamic>> realEmployees = posState.employees;

    showModalBottomSheet(
      context: context,
      builder: (_) {
         return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                  Text('Pilih $employeeLabel', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (realEmployees.isEmpty)
                     const Padding(
                       padding: EdgeInsets.all(16.0),
                       child: Text('Belum ada data pegawai.', style: TextStyle(color: Colors.grey)),
                     )
                  else
                    Expanded(
                      child: ListView.builder(
                         itemCount: realEmployees.length,
                         itemBuilder: (ctx, idx) {
                            final emp = realEmployees[idx];
                            return ListTile(
                               leading: const CircleAvatar(child: Icon(Icons.person)),
                               title: Text(emp['name'] ?? 'Unknown'),
                               onTap: () {
                                  context.read<PosBloc>().add(AddToCart(product, employeeId: emp['id'], employeeName: emp['name']));
                                  Navigator.pop(context);
                               },
                            );
                         },
                      ),
                    )
               ],
            ),
         );
      }
    );
  }
}

class CartModal extends StatefulWidget {
  final void Function(double)? onCheckout;
  const CartModal({super.key, this.onCheckout});

  @override
  State<CartModal> createState() => _CartModalState();
}

class _CartModalState extends State<CartModal> {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FA), // Off-white background
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Order Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.grey),
                    )
                  ],
                ),
              ),

              // List
              Expanded(
                child: BlocBuilder<PosBloc, PosState>(
                  builder: (context, state) {
                    if (state.cartItems.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('Keranjang Kosong', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: state.cartItems.length,
                      itemBuilder: (context, index) {
                        final item = state.cartItems[index];
                        return _buildDismissibleItem(context, item);
                      },
                    );
                  },
                ),
              ),

              // Footer
              _buildFooter(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDismissibleItem(BuildContext context, dynamic item) {
    return Dismissible(
      key: Key(item.product.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.red.shade700),
            Text('REMOVE', style: TextStyle(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold))
          ],
        ),
      ),
      onDismissed: (direction) {
        context.read<PosBloc>().add(UpdateCartQuanity(item.product, 0));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.product.name} removed'), duration: const Duration(seconds: 1)),
        );
      },
      child: _buildCartItem(context, item),
    );
  }

  Widget _buildCartItem(BuildContext context, dynamic item) {
    final product = item.product;
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Image
          Container(
            height: 64, width: 64,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: product.image != null && product.image!.isNotEmpty
                ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(product.image!, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.inventory_2, color: Colors.grey)),
                )
                : const Icon(Icons.inventory_2, color: Colors.grey),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  'Item',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFormatter.format(product.sellingPrice),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),

          // Qty Control
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    context.read<PosBloc>().add(UpdateCartQuanity(product, item.quantity - 1));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Icon(Icons.remove, size: 20, color: Colors.grey[600]),
                  ),
                ),
                SizedBox(
                  width: 24,
                  child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                InkWell(
                  onTap: () {
                    context.read<PosBloc>().add(AddToCart(product));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B9C5E),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                         BoxShadow(color: const Color(0xFF1B9C5E).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                      ]
                    ),
                    child: const Icon(Icons.add, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return BlocBuilder<PosBloc, PosState>(
      builder: (context, state) {
        final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

        // Fetch settings from AuthBloc
        double taxRate = 0.11; // Default 11%
        double discountRate = 0.0;
        
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated) {
             final settings = authState.user.settings;
             // Check for tax_rate in settings (e.g., 11 or 0.11)
             if (settings['tax_rate'] != null) {
                 double val = double.tryParse(settings['tax_rate'].toString()) ?? 0;
                 if (val > 1) val = val / 100.0; // Assume if > 1 it's generic percentage (e.g. 11 -> 0.11)
                 taxRate = val;
             }
             // Check for default_discount
             if (settings['default_discount'] != null) {
                 double val = double.tryParse(settings['default_discount'].toString()) ?? 0;
                 if (val > 1) val = val / 100.0; 
                 discountRate = val;
             }
        }

        final subtotal = state.total;
        final discountAmount = subtotal * discountRate;
        final taxableAmount = subtotal - discountAmount;
        final tax = taxableAmount * taxRate;
        final grandTotal = (taxableAmount + tax).roundToDouble();

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            // No top border, just shadow for floating feel
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                  Text(currencyFormatter.format(subtotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   // Discount
                  Row(
                    children: [
                      const Icon(Icons.local_offer, size: 16, color: Color(0xFF1B9C5E)),
                      const SizedBox(width: 4),
                      Text('Discount (${(discountRate * 100).toInt()}%)', style: const TextStyle(color: Color(0xFF1B9C5E), fontSize: 15)),
                    ],
                  ),
                  Text('- ${currencyFormatter.format(discountAmount)}', style: const TextStyle(color: Color(0xFF1B9C5E), fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tax (${(taxRate * 100).toInt()}%)', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                  Text(currencyFormatter.format(tax), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)), 
              ),

              // Grand Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('GRAND TOTAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1.5)),
                  Text(
                    currencyFormatter.format(grandTotal),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF2D3436)),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Pay Button
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: state.cartItems.isEmpty ? null : () async {
                    Navigator.pop(context);
                    // Wait for the modal to close completely to avoid context issues
                    await Future.delayed(const Duration(milliseconds: 300));
                    
                    if (widget.onCheckout != null) {
                         widget.onCheckout!(grandTotal);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B9C5E),
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: const Color(0xFF1B9C5E).withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Text('BAYAR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 24),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${state.cartItems.length} Items', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}

/// Helper class for display items in the product grid.
/// Can represent a single product or a variant group.
class _DisplayItem {
  final ProductModel product; // Representative product (or single product)
  final List<ProductModel> variants; // Empty for single, populated for group
  final int totalCartQty;

  bool get isGroup => variants.length > 1;

  const _DisplayItem({
    required this.product,
    required this.variants,
    required this.totalCartQty,
  });
}
