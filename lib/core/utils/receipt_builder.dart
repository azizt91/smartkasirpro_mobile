import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:mobile_app/core/services/printer_service.dart';
import 'package:mobile_app/injection_container.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;

class ReceiptBuilder {
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  final PrinterService printerService = sl<PrinterService>();

  // Since we are using blue_thermal_printer, it has its own methods for text, but writing raw bytes gives more control.
  // However, the library is simpler with its methods. Let's use its methods mixed with bytes if needed.
  // Actually, constructing a list of bytes manually is often better for consistency across libraries, 
  // but blue_thermal_printer takes methods like printCustom.
  
  // Let's use the high level methods provided by the library for simplicity and speed.
  // Method expected by HistoryDetailPage
  Future<List<int>> buildReceipt(
      Map<String, dynamic> transaction, 
      Map<String, dynamic> settings,
      List<dynamic> items
  ) async {
    // This method was expected to return bytes for another printer package, 
    // but we are using BlueThermalPrinter which prints directly.
    // For now, we reuse printReceipt logic or just print directly.
    // To satisfy the compilation, we return empty bytes, but we should call printReceipt inside.
    
    await printReceipt(transaction, settings, items);
    return [];
  }

  Future<void> printReceipt(
      Map<String, dynamic> transaction, 
      Map<String, dynamic> settings,
      List<dynamic> items
  ) async {
    // Ensure printer is connected (will auto-reconnect if needed)
    bool isConnected = await printerService.ensureConnected();
    if (!isConnected) {
      throw Exception("Printer belum terhubung. Silakan pastikan Bluetooth HP aktif dan printer menyala.");
    }

    try {
      // Styling
      // 0: Left, 1: Center, 2: Right
      // 0: Normal, 1: Bold, 2: Medium, 3: Large
      
      // --- LOGO ---
      final storeLogo = settings['store_logo'];
      if (storeLogo != null && storeLogo.toString().isNotEmpty) {
        try {
          final dio = sl<Dio>();
          final userBaseUrl = dio.options.baseUrl.replaceAll('/api', '');
          String path = storeLogo.toString();
          if (!path.startsWith('/')) path = '/$path';
          if (!path.contains('/storage')) path = '/storage$path';
          final url = '$userBaseUrl$path';

          final response = await dio.get(
            url,
            options: Options(
              responseType: ResponseType.bytes, 
              receiveTimeout: const Duration(seconds: 10)
            ),
          );
          
          if (response.statusCode == 200) {
            final Uint8List bytes = Uint8List.fromList(response.data);
            img.Image? originalImage = img.decodeImage(bytes);
            
            if (originalImage != null) {
              // Handle transparency: fill transparent pixels with white
              img.Image processedImage = img.Image(width: originalImage.width, height: originalImage.height);
              img.fill(processedImage, color: img.ColorRgb8(255, 255, 255)); 
              img.compositeImage(processedImage, originalImage);

              // Resize: max 384px width for 58mm printer
              if (processedImage.width > 384) {
                processedImage = img.copyResize(processedImage, width: 384);
              }

              // Encode to JPG format to remove alpha channel safely for printer
              final Uint8List printableBytes = img.encodeJpg(processedImage, quality: 100);

              await bluetooth.printCustom("", 1, 1); // center alignment trick
              await bluetooth.printImageBytes(printableBytes);
              await bluetooth.printNewLine();
            }
          }
        } catch (e) {
          print('Failed to print logo: $e');
        }
      }

      // Header
      await bluetooth.printCustom(settings['store_name'] ?? 'Minimarket POS', 3, 1);
      await bluetooth.printCustom(settings['store_address'] ?? '-', 0, 1);
      await bluetooth.printCustom(settings['store_phone'] ?? '-', 0, 1);
      await bluetooth.printNewLine();

      // Info — use printCustom with left alignment for clean formatting
      final dateFormat = DateFormat('dd-MM-yyyy HH:mm');
      final String date = transaction['created_at'] != null 
          ? dateFormat.format(DateTime.parse(transaction['created_at']).toLocal()) 
          : dateFormat.format(DateTime.now());
          
      await bluetooth.printCustom("Tgl       : $date", 0, 0);
      await bluetooth.printCustom("No        : ${transaction['transaction_code'] ?? '-'}", 0, 0);
      await bluetooth.printCustom("Kasir     : ${transaction['user_name'] ?? 'Admin'}", 0, 0);
      await bluetooth.printCustom("Pelanggan : ${transaction['customer_name'] ?? 'Umum'}", 0, 0);
      await bluetooth.printCustom("--------------------------------", 1, 1);

      // Body
      final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

      for (var item in items) {
         final name = item['product_name'] ?? (item['product']?['name'] ?? 'Unknown Product');
         await bluetooth.printCustom(name, 0, 0); // Changed to Size 0 for consistency
         
         // 🔥 NEW: Jasa Employee Info
         if (item['employee_name'] != null) {
            final String employeeLabel = settings['employee_label'] ?? 'Pegawai';
            await bluetooth.printCustom("  ($employeeLabel: ${item['employee_name']})", 0, 0);
         }

         // Qty x Price ... Subtotal
         final qty = item['quantity'];
         final double priceVal = _parseDouble(item['price']);
         final price = currencyFormatter.format(priceVal);
         final double subtotalVal = _parseDouble(item['subtotal']);
         final subtotal = currencyFormatter.format(subtotalVal > 0 ? subtotalVal : (priceVal * (qty is num ? qty : double.tryParse(qty.toString()) ?? 1)));
         
         await bluetooth.printLeftRight("$qty x $price", subtotal, 0);
      }
      
      await bluetooth.printCustom("--------------------------------", 0, 1);
      
      // Totals
      final double totalAmount = _parseDouble(transaction['total_amount']);
      final double pointDiscount = transaction['points_discount_amount'] != null ? _parseDouble(transaction['points_discount_amount']) : 0;
      final double totalAkhir = totalAmount - pointDiscount;

      if (pointDiscount > 0) {
          await bluetooth.printLeftRight("Total Awal :", currencyFormatter.format(totalAmount), 0);
          await bluetooth.printLeftRight("Potongan Poin :", "-${currencyFormatter.format(pointDiscount)}", 0);
          await bluetooth.printLeftRight("Total Akhir :", currencyFormatter.format(totalAkhir), 0);
      } else {
          await bluetooth.printLeftRight("Total :", currencyFormatter.format(totalAmount), 0);
      }
      
      final paymentMethod = transaction['payment_method'] ?? 'cash';
      await bluetooth.printLeftRight("Bayar (${paymentMethod.toUpperCase()}) :", currencyFormatter.format(_parseDouble(transaction['amount_paid'])), 0);

      if (paymentMethod == 'utang') {
         await bluetooth.printCustom("** BELUM LUNAS - PIUTANG **", 1, 1);
      } else {
         await bluetooth.printLeftRight("Kembali :", currencyFormatter.format(_parseDouble(transaction['change_amount'])), 0);
      }

      await bluetooth.printNewLine();

      // 🔥 NEW: Points Information
      bool loyaltyEnabled = true;
      if (settings['enable_loyalty_points'] != null) {
          final sVal = settings['enable_loyalty_points'];
          loyaltyEnabled = sVal == true || sVal == 'true' || sVal == 1 || sVal == '1';
      }

      if (loyaltyEnabled && transaction['points_earned'] != null && _parseDouble(transaction['points_earned']) > 0) {
         await bluetooth.printLeftRight("Poin Didapat :", "${_parseDouble(transaction['points_earned']).toInt()}", 0);
         await bluetooth.printNewLine();
      }
      // Footer — use store_description from settings
      final storeDescription = settings['store_description'] ?? '';
      if (storeDescription.toString().isNotEmpty) {
        // Split long description into lines of ~32 chars for thermal printer
        final desc = storeDescription.toString();
        final words = desc.split(' ');
        String line = '';
        for (final word in words) {
          if ((line + ' ' + word).trim().length > 32) {
            await bluetooth.printCustom(line.trim(), 0, 1);
            line = word;
          } else {
            line = line.isEmpty ? word : '$line $word';
          }
        }
        if (line.isNotEmpty) {
          await bluetooth.printCustom(line.trim(), 0, 1);
        }
      } else {
        await bluetooth.printCustom("Terima Kasih", 1, 1);
        await bluetooth.printCustom("Barang yang sudah dibeli", 0, 1);
        await bluetooth.printCustom("tidak dapat ditukar/dikembalikan", 0, 1);
      }
      await bluetooth.printNewLine();
      await bluetooth.printNewLine();
    } catch (e) {
      if (e is PlatformException && e.code == 'write_error') {
         throw Exception("Gagal mengirim data ke printer. Pastikan printer menyala dan terhubung.");
      }
      rethrow;
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }
}
