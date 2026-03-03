import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:mobile_app/features/pos/data/models/customer_model.dart'; // Import
import '../bloc/pos_bloc.dart';
import 'package:dio/dio.dart';
import 'package:mobile_app/injection_container.dart' as di;

class PaymentModal extends StatefulWidget {
  final double totalAmount;

  const PaymentModal({super.key, required this.totalAmount});

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  String _selectedPaymentMethod = 'cash';
  final TextEditingController _amountPaidController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  double _change = 0;
  late final double _totalRounded; // Integer-rounded total to avoid float drift

  DateTime _selectedDate = DateTime.now();
  CustomerModel? _selectedCustomer; // Null means "Umum"

  // Channels logic
  String? _selectedChannel;
  List<Map<String, dynamic>> _channels = [];
  bool _isLoadingChannels = false;
  String? _channelError;
  
  // Points logic
  bool _usePoints = false;
  int _pointsToRedeem = 0;
  int _pointExchangeRate = 100; // Will be updated from settings.
  bool _loyaltyPointsEnabled = true;

  @override
  void initState() {
    super.initState();
    _totalRounded = widget.totalAmount.roundToDouble(); // Round once at entry
    _amountPaidController.addListener(_calculateChange);
    // Autofocus amount field if cash is selected
    if (_selectedPaymentMethod == 'cash') {
       WidgetsBinding.instance.addPostFrameCallback((_) {
         _amountFocusNode.requestFocus();
       });
    }

    // Init Exchange Rate & Master Switch
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
        final s = authState.user.settings;
        if (s['point_exchange_rate'] != null) {
            _pointExchangeRate = int.tryParse(s['point_exchange_rate'].toString()) ?? 100;
        }
        if (s['enable_loyalty_points'] != null) {
            final enablePoints = s['enable_loyalty_points'];
            _loyaltyPointsEnabled = enablePoints == true || enablePoints == 'true' || enablePoints == 1 || enablePoints == '1';
        }
    }
  }

  Future<void> _fetchChannels(String method) async {
      if (!['ewallet', 'transfer', 'qris'].contains(method)) {
         setState(() {
             _channels = [];
             _selectedChannel = null;
         });
         return;
      }

      setState(() {
          _isLoadingChannels = true;
          _channelError = null;
          _channels = [];
          _selectedChannel = null;
      });

      try {
          final dio = di.sl<Dio>();
          final response = await dio.get('/pos/payment-channels?method=$method');
          if (response.statusCode == 200 && response.data['success'] == true) {
              setState(() {
                  _channels = List<Map<String, dynamic>>.from(response.data['data']);
              });
          } else {
              setState(() => _channelError = response.data['message'] ?? 'Gagal memuat provider');
          }
      } catch (e) {
          setState(() => _channelError = 'Gagal memuat provider: \$e');
      } finally {
          setState(() => _isLoadingChannels = false);
      }
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showCustomerPicker() {
    final posBloc = context.read<PosBloc>(); // Capture bloc from current context
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value( // Provide it to the modal
        value: posBloc,
        child: _CustomerSearchModal(
          onSelect: (customer) {
            setState(() => _selectedCustomer = customer);
          },
        ),
      ),
    );
  }

  // Existing methods...
  @override
  void dispose() {
    _amountPaidController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }
  
  void _calculateChange() {
      // Remove non-digits
      String cleanText = _amountPaidController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final paid = double.tryParse(cleanText) ?? 0;
      setState(() {
          _change = paid - _finalTotal;
      });
  }

  void _addAmount(double amount) {
     String cleanText = _amountPaidController.text.replaceAll(RegExp(r'[^0-9]'), '');
     double current = double.tryParse(cleanText) ?? 0;
     // If current is 0, replace properly
     _amountPaidController.text = (current + amount).toInt().toString();
     _calculateChange();
  }

  void _setExactAmount() {
     _amountPaidController.text = _finalTotal.toInt().toString();
     _calculateChange();
  }

  // Points mathematical property
  double get _finalTotal {
     double discount = _usePoints ? (_pointsToRedeem * _pointExchangeRate).toDouble() : 0.0;
     return _totalRounded - discount;
  }


  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('CHECKOUT', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 14)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
           IconButton(
             icon: const Icon(Icons.more_vert, color: Colors.grey),
             onPressed: () {},
           )
        ],
      ),
      body: Column(
        children: [
           Expanded(
             child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  children: [
                      // Total Bill
                      const SizedBox(height: 16),
                      const Text('Total Tagihan', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B9C5E).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF1B9C5E).withOpacity(0.2), blurRadius: 20, spreadRadius: 0)
                            ]
                          ),
                          child: Text(
                            currencyFormatter.format(_finalTotal.toInt()),
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF2D3436), letterSpacing: -0.5),
                          ),
                        ),
                      ),
                      
                      // Points Info Text if Used
                      if (_usePoints && _pointsToRedeem > 0)
                         Padding(
                           padding: const EdgeInsets.only(top: 8.0),
                           child: Text(
                             'Diskon Poin: -${currencyFormatter.format(_pointsToRedeem * _pointExchangeRate)}',
                             style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                           ),
                         ),

                      const SizedBox(height: 32),

                      // Payment Methods Grid
                      const Align(alignment: Alignment.centerLeft, child: Text('METODE PEMBAYARAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1))),
                      const SizedBox(height: 12),
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          bool isResto = false;
                          if (state is AuthAuthenticated) {
                            isResto = state.user.settings['business_mode'] == 'resto';
                          }
                          
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.9,
                            children: [
                               _buildMethodCard('cash', 'Tunai', Icons.payments_outlined),
                               _buildMethodCard('qris', 'QRIS', Icons.qr_code_scanner),
                               _buildMethodCard('transfer', 'Transfer', Icons.account_balance_outlined),
                               _buildMethodCard('ewallet', 'E-Wallet', Icons.account_balance_wallet_outlined),
                               if (!isResto) 
                                 _buildMethodCard('utang', 'Utang', Icons.history),
                            ],
                          );
                        }
                      ),

                      // Payment Channels Grid (Dynamic)
                      if (['ewallet', 'transfer', 'qris'].contains(_selectedPaymentMethod)) ...[
                          const SizedBox(height: 20),
                          const Align(alignment: Alignment.centerLeft, child: Text('PILIH PROVIDER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1))),
                          const SizedBox(height: 12),
                          if (_isLoadingChannels)
                              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                          else if (_channelError != null)
                              Center(child: Text(_channelError!, style: const TextStyle(color: Colors.red, fontSize: 13)))
                          else if (_channels.isEmpty)
                              const Center(child: Text('Provider tidak tersedia', style: TextStyle(color: Colors.grey, fontSize: 13)))
                          else
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _channels.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                   crossAxisCount: 2,
                                   crossAxisSpacing: 10,
                                   mainAxisSpacing: 10,
                                   childAspectRatio: 3,
                                ),
                                itemBuilder: (context, index) {
                                   final ch = _channels[index];
                                   final isSelected = _selectedChannel == ch['code'];
                                   return InkWell(
                                      onTap: () => setState(() => _selectedChannel = ch['code']),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                         alignment: Alignment.center,
                                         padding: const EdgeInsets.symmetric(horizontal: 4),
                                         decoration: BoxDecoration(
                                            color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
                                            border: Border.all(color: isSelected ? const Color(0xFF1B9C5E) : Colors.grey.shade300, width: isSelected ? 2 : 1),
                                            borderRadius: BorderRadius.circular(8),
                                         ),
                                         child: Text(ch['name'] ?? '', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? const Color(0xFF1B9C5E) : Colors.black87)),
                                      ),
                                   );
                                }
                              ),
                      ],

                      const SizedBox(height: 24),

                      // -- NEW: Customer & Date Section --
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            // Customer Selector
                            InkWell(
                              onTap: _showCustomerPicker,
                              child: Row(
                                children: [
                                  const Icon(Icons.person_outline, color: Colors.grey),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Pelanggan', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        Text(
                                          _selectedCustomer?.name ?? 'Umum',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        if (_selectedCustomer?.phone != null)
                                          Text(_selectedCustomer!.phone!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Colors.grey),
                                ],
                              ),
                            ),
                            const Divider(height: 24),
                            // Date Picker
                            InkWell(
                              onTap: _pickDate,
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined, color: Colors.grey),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Tanggal Transaksi', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        Text(
                                          DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.edit_calendar, color: Colors.grey),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Loyalty Points Section
                      if (_loyaltyPointsEnabled && _selectedCustomer != null && _selectedCustomer!.points > 0)
                         Container(
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(
                             color: Colors.orange.shade50,
                             borderRadius: BorderRadius.circular(16),
                             border: Border.all(color: Colors.orange.shade200),
                           ),
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     const Text('Gunakan Poin Membership', style: TextStyle(fontWeight: FontWeight.bold)),
                                     Text('Anda Punya ${_selectedCustomer!.points} Poin = ${currencyFormatter.format(_selectedCustomer!.points * _pointExchangeRate)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                   ],
                                 ),
                               ),
                               Switch(
                                 value: _usePoints,
                                 activeColor: Colors.orange,
                                 onChanged: (val) {
                                     setState(() {
                                        _usePoints = val;
                                        if (val) {
                                            // calc max points usable
                                            final maxPointsNeeded = (_totalRounded / _pointExchangeRate).ceil();
                                            _pointsToRedeem = _selectedCustomer!.points < maxPointsNeeded 
                                               ? _selectedCustomer!.points 
                                               : maxPointsNeeded;
                                        } else {
                                            _pointsToRedeem = 0;
                                        }
                                        _calculateChange();
                                     });
                                 }
                               ),
                             ],
                           ),
                         ),

                      const SizedBox(height: 24),


                      // Payment Input Section (Visible for ALL methods)
                       Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.grey.shade100),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))]
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               const Text('Uang Diterima / Nominal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                               const SizedBox(height: 12),
                               
                               // Input Field
                               Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.transparent),
                                  ),
                                  child: Row(
                                     children: [
                                       const Text('Rp', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
                                       const SizedBox(width: 12),
                                       Expanded(
                                         child: TextField(
                                            controller: _amountPaidController,
                                            focusNode: _amountFocusNode,
                                            keyboardType: TextInputType.number,
                                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              hintText: '0',
                                              hintStyle: TextStyle(color: Colors.black12),
                                            ),
                                         ),
                                       ),
                                       if (_amountPaidController.text.isNotEmpty)
                                         IconButton(
                                           icon: const Icon(Icons.close, color: Colors.grey),
                                           onPressed: () { _amountPaidController.clear(); _calculateChange(); },
                                         )
                                     ],
                                  ),
                               ),
                               const SizedBox(height: 16),
                               
                               // Quick Amounts
                               Row(
                                 children: [
                                    Expanded(child: _buildActionBtn('Uang Pas', _setExactAmount, false)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _buildQuickAmountBtn('50k', 50000)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _buildQuickAmountBtn('100k', 100000)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _buildQuickAmountBtn('200k', 200000)),
                                 ],
                               ),

                               const SizedBox(height: 20),
                               const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)), // Dashed line visual
                               const SizedBox(height: 16),

                               // Change
                               Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                     const Text('Kembalian', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
                                     Text(
                                        currencyFormatter.format(_change < 0 ? 0 : _change), 
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B9C5E))
                                     ),
                                  ],
                               )
                            ],
                          ),
                       ),
                  ],
                ),
             ),
           ),

           // Footer
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
            ),
            child: Column(
              children: [
                 SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                          
                          double paid = double.tryParse(_amountPaidController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                          
                          // Auto-fill if 0 for non-cash (already existing logic, slightly refined)
                          if (paid == 0 && _selectedPaymentMethod != 'cash') {
                              paid = widget.totalAmount; 
                          }

                          // Validation: Prevent Underpayment for Non-Utang
                          if (_selectedPaymentMethod != 'utang' && paid < _finalTotal) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Nominal pembayaran kurang!'),
                                  backgroundColor: Colors.red,
                                )
                              );
                              return;
                          }

                          // Validation: Prevent Overpayment for Utang (Optional, but logical)
                          if (_selectedPaymentMethod == 'utang' && paid > _finalTotal) {
                             ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Nominal DP tidak boleh melebihi total tagihan!'),
                                  backgroundColor: Colors.red,
                                )
                              );
                              return;
                          }

                          // Validation: Prevent Checkout if Digital Channel not selected
                          if (['ewallet', 'transfer', 'qris'].contains(_selectedPaymentMethod) && _selectedChannel == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Pilih provider pembayaran (E-Wallet/Bank)!'), backgroundColor: Colors.red)
                              );
                              return;
                          }

                          context.read<PosBloc>().add(SubmitTransaction(
                               paymentMethod: _selectedPaymentMethod,
                               paymentChannel: _selectedChannel,
                               amountPaid: paid,
                               customerName: _selectedCustomer?.name, // Pass selected customer name
                               customerId: _selectedCustomer?.id, // Pass selected customer ID
                               transactionDate: _selectedDate, // Pass selected date
                               pointsRedeemed: _usePoints ? _pointsToRedeem : 0, // NEW
                               pointExchangeRate: _pointExchangeRate,
                          ));
                          Navigator.pop(context); // Close Payment Modal
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B9C5E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: const Color(0xFF1B9C5E).withOpacity(0.4),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           Text('Konfirmasi Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                           SizedBox(width: 8),
                           Icon(Icons.arrow_forward, color: Colors.white, size: 20)
                        ],
                      ),
                    ),
                 ),
                 const SizedBox(height: 12),
                 SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.red.shade50))
                      ),
                      child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                 )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMethodCard(String id, String label, IconData icon) {
     final isSelected = _selectedPaymentMethod == id;
     return GestureDetector(
       onTap: () {
           if (_selectedPaymentMethod != id) {
               setState(() => _selectedPaymentMethod = id);
               _fetchChannels(id);
           }
       },
       child: Container(
          decoration: BoxDecoration(
             color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
             borderRadius: BorderRadius.circular(16),
             border: Border.all(color: isSelected ? const Color(0xFF1B9C5E) : Colors.grey.shade200, width: isSelected ? 2 : 1),
             boxShadow: isSelected 
                ? [BoxShadow(color: const Color(0xFF1B9C5E).withOpacity(0.2), blurRadius: 8)] 
                : []
          ),
          child: Stack(
            children: [
               Center(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                      Icon(icon, color: isSelected ? const Color(0xFF1B9C5E) : Colors.grey.shade500, size: 28),
                      const SizedBox(height: 4),
                      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF1B9C5E) : Colors.grey.shade600))
                   ],
                 ),
               ),
               if (isSelected)
                 Positioned(
                   top: 6, right: 6,
                   child: Container(
                     padding: const EdgeInsets.all(2),
                     decoration: const BoxDecoration(color: Color(0xFF1B9C5E), shape: BoxShape.circle),
                     child: const Icon(Icons.check, size: 10, color: Colors.white),
                   ),
                 )
            ],
          ),
       ),
     );
  }

  Widget _buildQuickAmountBtn(String label, double amount) {
     double current = double.tryParse(_amountPaidController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
     bool isPrimary = current == amount;
     
     return InkWell(
       onTap: () {
          // If already selected, maybe toggle off? Or just set. 
          // Let's set it. But if we want to "add" like before?
          // The previous logic was _addAmount. 
          // If the user wants "Quick Amount" usually it means "Pay exactly this".
          // But the previous code was `_addAmount`.
          // "Uang Pas" sets exact. 
          // Let's make these buttons SET the amount, not add (unless it was intended to be "add bills").
          // Usually 50k button means "I pay with 50k sheet".
          
          _amountPaidController.text = amount.toInt().toString();
          _calculateChange();
       },
       borderRadius: BorderRadius.circular(12),
       child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
             color: isPrimary ? const Color(0xFFE8F5E9) : Colors.white,
             borderRadius: BorderRadius.circular(12),
             border: Border.all(color: isPrimary ? const Color(0xFF1B9C5E) : Colors.grey.shade300),
          ),
          alignment: Alignment.center,
          child: Text(
            label, 
            style: TextStyle(
               fontWeight: FontWeight.bold, 
               fontSize: 12,
               color: isPrimary ? const Color(0xFF1B9C5E) : Colors.grey.shade700
            ) 
          ),
       ),
     );
  }

  Widget _buildActionBtn(String label, VoidCallback onTap, bool isPrimary) {
     return InkWell(
       onTap: onTap,
       borderRadius: BorderRadius.circular(12),
       child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
             color: isPrimary ? const Color(0xFFE8F5E9) : Colors.white,
             borderRadius: BorderRadius.circular(12),
             border: Border.all(color: isPrimary ? const Color(0xFF1B9C5E) : Colors.grey.shade300),
          ),
          alignment: Alignment.center,
          child: Text(
            label, 
            style: TextStyle(
               fontWeight: FontWeight.bold, 
               fontSize: 12,
               color: isPrimary ? const Color(0xFF1B9C5E) : Colors.grey.shade700
            ) 
          ),
       ),
     );
  }
}

class _CustomerSearchModal extends StatefulWidget {
  final Function(CustomerModel?) onSelect;
  const _CustomerSearchModal({required this.onSelect});

  @override
  State<_CustomerSearchModal> createState() => _CustomerSearchModalState();
}

class _CustomerSearchModalState extends State<_CustomerSearchModal> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosBloc, PosState>(
      builder: (context, state) {
        final customers = result_customers(state.customers, _query);

        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Text('Pilih Pelanggan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari Nama / No. HP...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  ),
                  onChanged: (val) => setState(() => _query = val),
                ),
              ),
              const SizedBox(height: 10),
              // List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: customers.length + 2, // +1 for "Tambah Baru", +1 for "Umum"
                  itemBuilder: (context, index) {
                    if (index == 0) {
                       return Card(
                        key: const ValueKey('add_customer'),
                        elevation: 0,
                        color: Colors.blue.shade50,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.shade100)),
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.person_add, color: Colors.white)),
                          title: const Text('Tambah Pelanggan Baru', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          onTap: () {
                             _showAddCustomerDialog(context);
                          },
                        ),
                      );
                    }
                    if (index == 1) {
                      return Card(
                        key: const ValueKey('umum'),
                        elevation: 0,
                        color: Colors.grey.shade100,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.people, color: Colors.white)),
                          title: const Text('Umum', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Tanpa data pelanggan'),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () {
                            widget.onSelect(null);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    }
                    final customer = customers[index - 2];
                    return Card(
                      key: ValueKey('customer_${customer.id}'),
                      elevation: 2,
                      shadowColor: Colors.black12,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE8F5E9),
                          child: Text(customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?', style: const TextStyle(color: Color(0xFF1B9C5E), fontWeight: FontWeight.bold)),
                        ),
                        title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: customer.phone != null 
                             ? Row(children: [const Icon(Icons.phone, size: 12, color: Colors.grey), const SizedBox(width: 4), Text(customer.phone!, style: const TextStyle(fontSize: 12))])
                             : null,
                        trailing: const Icon(Icons.check_circle_outline, color: Color(0xFF1B9C5E)),
                        onTap: () {
                          widget.onSelect(customer);
                          Navigator.pop(context);
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

  void _showAddCustomerDialog(BuildContext _) {
    // Note: We ignore the passed context and use the State's context to avoid detached context issues.
    // However, showDialog needs a valid context. We can use `context` which refers to `_CustomerSearchModalState`'s context.

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context, 
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tambah Pelanggan Baru'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nama Lengkap', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'No. HP (Opsional)', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                // Use the BLoC provider available in the `context` (modal sheet context)
                context.read<PosBloc>().add(AddCustomer(
                  name: nameController.text,
                  phone: phoneController.text.isEmpty ? null : phoneController.text,
                ));
                
                Navigator.pop(dialogContext); // Close dialog
                
                // Wait for BLoC update
                Future.delayed(const Duration(milliseconds: 500), () {
                   if (!mounted) return;
                   
                   final state = context.read<PosBloc>().state;
                   if (state.customers.isNotEmpty) {
                      widget.onSelect(state.customers.first);
                      Navigator.pop(context); // Close the bottom sheet (using State context)
                   }
                });
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
  
  List<CustomerModel> result_customers(List<CustomerModel> all, String query) {
     if (query.isEmpty) return all;
     return all.where((c) => 
                c.name.toLowerCase().contains(query.toLowerCase()) || 
                (c.phone != null && c.phone!.contains(query))
              ).toList();
  }
}
