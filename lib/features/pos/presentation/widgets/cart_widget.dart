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

        // Optimized styles for Tablet
        final labelStyle = TextStyle(color: Colors.grey[600], fontSize: isTablet ? 11 : 15);
        final valueStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: isTablet ? 11 : 15);
        final footerPadding = isTablet ? 12.0 : 16.0;

        // Tablet Detail Row Widget (Reusable)
        Widget buildTabletDetailRow(String label, double amount, {bool isDiscount = false}) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: labelStyle.copyWith(color: isDiscount ? const Color(0xFF1B9C5E) : null)),
              const SizedBox(width: 4),
              Text(
                currencyFormatter.format(amount),
                style: valueStyle.copyWith(color: isDiscount ? const Color(0xFF1B9C5E) : null),
              ),
            ],
          );
        }

        return Container(
          padding: EdgeInsets.all(footerPadding),
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
              if (isTablet)
                // Tablet Mode: Single Row / Wrap
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    buildTabletDetailRow('Sub:', subtotal),
                    if (discountRate > 0) ...[
                      Text('|', style: TextStyle(color: Colors.grey[300], fontSize: 10)),
                      buildTabletDetailRow('Disc:', discountAmount, isDiscount: true),
                    ],
                    if (taxRate > 0) ...[
                      Text('|', style: TextStyle(color: Colors.grey[300], fontSize: 10)),
                      buildTabletDetailRow('Tax:', tax),
                    ],
                  ],
                )
              else
                // Mobile Mode: Vertical Stack
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal', style: labelStyle),
                        Text(currencyFormatter.format(subtotal), style: valueStyle),
                      ],
                    ),
                    if (discountRate > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_offer, size: 16, color: Color(0xFF1B9C5E)),
                              const SizedBox(width: 4),
                              Text('Discount (${(discountRate * 100).toInt()}%)', style: labelStyle.copyWith(color: const Color(0xFF1B9C5E))),
                            ],
                          ),
                          Text('- ${currencyFormatter.format(discountAmount)}', style: valueStyle.copyWith(color: const Color(0xFF1B9C5E))),
                        ],
                      ),
                    ],
                    if (taxRate > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tax (${(taxRate * 100).toInt()}%)', style: labelStyle),
                          Text(currencyFormatter.format(tax), style: valueStyle),
                        ],
                      ),
                    ],
                  ],
                ),

              Padding(
                padding: EdgeInsets.symmetric(vertical: isTablet ? 4.0 : 20.0),
                child: Divider(height: 1, thickness: 1, color: const Color(0xFFEEEEEE)), 
              ),

              // Grand Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('GRAND TOTAL', style: TextStyle(fontSize: isTablet ? 14 : 12, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1.5)),
                  Text(
                    currencyFormatter.format(grandTotal),
                    style: TextStyle(fontSize: isTablet ? 18 : 28, fontWeight: FontWeight.w900, color: const Color(0xFF2D3436)),
                  ),
                ],
              ),

              SizedBox(height: isTablet ? 8 : 16),
              
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
                    padding: EdgeInsets.symmetric(vertical: isTablet ? 12 : 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: isTablet ? 2 : 10,
                    shadowColor: const Color(0xFF1B9C5E).withOpacity(0.4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Text('Checkout', style: TextStyle(fontSize: isTablet ? 14 : 16, fontWeight: FontWeight.bold, color: Colors.white)),
                       const SizedBox(width: 8),
                       Icon(Icons.arrow_forward_rounded, color: Colors.white, size: isTablet ? 18 : 20)
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
