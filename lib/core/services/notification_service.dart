import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../injection_container.dart' as di;
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../main.dart'; // Import main.dart to access navigatorKey

const String kMainChannelId = 'smart_kasir_v7_urgent';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  NotificationService().showNotificationFromData(message);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 1. Izin dasar
    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    
    // 2. Setel opsi agar sistem tidak "mencuri" notifikasi (kita handle manual)
    await _fcm.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);

    // 3. Inisialisasi plugin lokal
    await _local.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('icon_notification')),
    );

    // 4. DAFTARKAN CHANNEL KE SISTEM (Wajib agar banner muncul)
    final androidPlugin = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        kMainChannelId,
        'Notifikasi Pesanan',
        description: 'Pemberitahuan Pesanan Baru Masuk',
        importance: Importance.max, // Wajib MAX untuk popup
        playSound: true,
        enableVibration: true,
        showBadge: true,
        sound: RawResourceAndroidNotificationSound('notif_order_alert'),
      ));
      await androidPlugin.requestNotificationsPermission();
    }

    // 5. Listener Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showNotificationFromData(message);
      
      // Trigger Custom In-App Banner
      final title = message.notification?.title ?? message.data['title'] ?? 'Pesanan Baru';
      final body = message.notification?.body ?? message.data['body'] ?? 'Cek aplikasi sekarang';
      final type = message.data['notification_type'] ?? 'order';
      
      _showInAppBanner(title, body, type);
    });

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _syncToken();
  }

  // Fungsi penampil popup yang dipanggil di Foreground & Background
  Future<void> showNotificationFromData(RemoteMessage message) async {
    final type = message.data['notification_type'] ?? 'order';
    final soundFile = (type == 'order') ? 'notif_order_alert' : 'notif_chime';

    final title = message.notification?.title ?? message.data['title'] ?? 'Pesanan Baru';
    final body = message.notification?.body ?? message.data['body'] ?? 'Cek aplikasi sekarang';

    await _local.show(
      Random().nextInt(2147483647),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          kMainChannelId,
          'Notifikasi Pesanan',
          channelDescription: 'Pemberitahuan Pesanan Baru Masuk',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          fullScreenIntent: true, // Memaksa popup muncul di atas aplikasi
          category: AndroidNotificationCategory.call, // Kategori Call/Alarm lebih agresif muncul di layar
          playSound: true,
          sound: RawResourceAndroidNotificationSound(soundFile),
          icon: 'icon_notification',
        ),
      ),
    );
  }

  void _showInAppBanner(String title, String body, String type) {
    if (navigatorKey.currentContext == null) return;

    final overlay = Overlay.of(navigatorKey.currentContext!);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100, end: 0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B9C5E), // Hijau Kasir
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_active, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      overlayEntry.remove();
    });
  }

  Future<void> _syncToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        final repo = di.sl<AuthRepository>();
        await repo.updateFcmToken(token);
      }
    } catch (e) {
      debugPrint('FCM Token sync failed: $e');
    }
  }

  Future<String?> getToken() async => await _fcm.getToken();
}
