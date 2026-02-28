import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dialog shown when a payment gateway transaction is pending.
/// Displays QR code (for QRIS), payment URL (for Transfer/E-Wallet),
/// and provides "Bayar Nanti" button to dismiss.
class PaymentPendingDialog extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final Map<String, dynamic> payment;
  final VoidCallback onDismiss;

  const PaymentPendingDialog({
    super.key,
    required this.transaction,
    required this.payment,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final method = transaction['payment_method'] ?? '';
    final provider = (payment['provider'] ?? '').toString().toUpperCase();
    final payUrl = payment['pay_url']?.toString() ?? '';
    final qrUrl = payment['qr_url']?.toString() ?? '';
    final totalAmount = (transaction['total_amount'] is num)
        ? (transaction['total_amount'] as num).toDouble()
        : double.tryParse(transaction['total_amount']?.toString() ?? '0') ?? 0;
    final txCode = transaction['transaction_code'] ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: Pending indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Menunggu Pembayaran...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Transaction code
              Text(
                txCode,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 16),

              // Method badge
              _buildMethodBadge(method, provider),
              const SizedBox(height: 16),

              // QR Code Image (for QRIS)
              if (method == 'qris' && (qrUrl.isNotEmpty || payUrl.isNotEmpty))
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    qrUrl.isNotEmpty ? qrUrl : payUrl,
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        width: 220,
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (_, __, ___) => _buildOpenPaymentButton(payUrl),
                  ),
                ),

              // Total amount
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Text('Total Bayar', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormatter.format(totalAmount),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Instruction text
              Text(
                method == 'qris'
                    ? 'Scan QR Code di atas dengan aplikasi e-wallet atau mobile banking.'
                    : method == 'transfer'
                        ? 'Buka halaman pembayaran untuk mendapatkan nomor Virtual Account.'
                        : 'Buka halaman pembayaran untuk menyelesaikan via E-Wallet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),

              // Open Payment URL button (for transfer & ewallet)
              if (method != 'qris' && payUrl.isNotEmpty)
                _buildOpenPaymentButton(payUrl),

              if (method != 'qris' && payUrl.isNotEmpty)
                const SizedBox(height: 12),

              // Dismiss button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.access_time, size: 18),
                  label: const Text('Bayar Nanti'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'Status akan otomatis berubah saat pembayaran selesai.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodBadge(String method, String provider) {
    IconData icon;
    Color color;
    String label;

    switch (method) {
      case 'qris':
        icon = Icons.qr_code_2;
        color = Colors.blue;
        label = 'QRIS — $provider';
        break;
      case 'transfer':
        icon = Icons.account_balance;
        color = Colors.green;
        label = 'Transfer — $provider';
        break;
      default:
        icon = Icons.phone_android;
        color = Colors.purple;
        label = 'E-Wallet — $provider';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildOpenPaymentButton(String url) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        icon: const Icon(Icons.open_in_browser, size: 18),
        label: const Text('Buka Halaman Pembayaran'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
