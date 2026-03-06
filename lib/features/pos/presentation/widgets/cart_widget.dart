import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_state.dart';

class CartWidget extends StatelessWidget {
  final bool isTablet;
  final VoidCallback? onClose;
  final Function(double)? onCheckout;
  final ScrollController? scrollController;

  const CartWidget({
    super.key, 
    this.isTablet = false,
    this.onClose,
    this.onCheckout,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: isTablet ? null : const BorderRadius.vertical(top: Radius.circular(32)),
        // specific border/shadow for tablet if needed
        border: isTablet ? const Border(left: BorderSide(color: Colors.black12)) : null,
      ),
      child: Column(
        children: [
          // Drag Handle (Mobile Only)
          if (!isTablet)
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
                const Text('Order Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (!isTablet && onClose != null)
                   IconButton(
                     onPressed: onClose,
                     icon: const Icon(Icons.close, color: Colors.grey),
                   ),
                if (isTablet)
                   // Tablet: Maybe a "Clear All" button?
                   TextButton(
                     onPressed: () {
                        context.read<PosBloc>().add(ClearCart());
                     },
                     child: const Text('Clear', style: TextStyle(color: Colors.red)),
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
                  controller: scrollController, // Use provided controller for DraggableScrollableSheet
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
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
            height: 56, width: 56,
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
          const SizedBox(width: 12),

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
             if (settings['tax_rate'] != null) {
                 double val = double.tryParse(settings['tax_rate'].toString()) ?? 0;
                 if (val > 1) val = val / 100.0;
                 taxRate = val;
             }
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
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
              if (discountRate > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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

              const SizedBox(height: 16),
              
              // Pay Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.cartItems.isEmpty ? null : () {
                     if (onCheckout != null) {
                        onCheckout!(grandTotal); // Trigger checkout
                     }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B9C5E),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 10,
                    shadowColor: const Color(0xFF1B9C5E).withOpacity(0.4),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Text('Checkout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                       SizedBox(width: 8),
                       Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20)
                    ],
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
