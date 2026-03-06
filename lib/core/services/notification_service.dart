import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../injection_container.dart' as di;
import '../../features/auth/domain/repositories/auth_repository.dart';

/// ──────────────────────────────────────────────────────────
/// KONSTANTA ID CHANNEL (Satu Jalur Utama)
/// ──────────────────────────────────────────────────────────
const String kMainChannelId = 'smart_kasir_v7_urgent';

/// ──────────────────────────────────────────────────────────
/// BACKGROUND HANDLER (Wajib di luar class)
/// ──────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  // Ambil tipe suara: order_alert untuk pesanan, chime untuk lainnya
  final type = message.data['notification_type'] ?? 'order';
  final soundFile = (type == 'order') ? 'notif_order_alert' : 'notif_chime';

  final localPlugin = FlutterLocalNotificationsPlugin();
  await localPlugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ));

  // Tampilkan manual jika pesan hanya berisi DATA (tanpa notification payload)
  if (message.notification == null) {
    await localPlugin.show(
      Random().nextInt(2147483647),
      message.data['title'] ?? 'Pesanan Baru',
      message.data['body'] ?? 'Cek aplikasi sekarang',
      NotificationDetails(
        android: AndroidNotificationDetails(
          kMainChannelId,
          'Notifikasi Pesanan',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          fullScreenIntent: true,
          sound: RawResourceAndroidNotificationSound(soundFile),
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 1. Minta Izin Notifikasi
    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    
    // 2. Setel opsi agar notifikasi muncul saat aplikasi dibuka (Foreground)
    await _fcm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    // 3. Inisialisasi Notifikasi Lokal
    await _local.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    
    // 4. Daftarkan Channel v7 ke Sistem Android
    final androidPlugin = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        kMainChannelId,
        'Notifikasi Pesanan',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        sound: RawResourceAndroidNotificationSound('notif_order_alert'),
      ));
      await androidPlugin.requestNotificationsPermission();
    }

    // 5. Listener saat aplikasi sedang DIBUKA
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? message.data['title'] ?? 'Pesanan Baru';
      final body = message.notification?.body ?? message.data['body'] ?? '';
      _showInstant(title, body, message);
    });

    // 6. Setel Background Handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 7. Sinkronisasi Token FCM ke Database (Penting!)
    await _syncToken();
    _fcm.onTokenRefresh.listen((newToken) async {
      await _sendTokenToServer(newToken);
    });
  }

  // Fungsi memicu popup (Heads-up) instan di foreground
  void _showInstant(String title, String body, RemoteMessage message) {
    final type = message.data['notification_type'] ?? 'order';
    final soundFile = (type == 'order') ? 'notif_order_alert' : 'notif_chime';

    _local.show(
      Random().nextInt(2147483647),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          kMainChannelId,
          'Notifikasi Pesanan',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(soundFile),
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  /// ──────────────────────────────────────────────────────────
  /// LOGIKA TOKEN SYNC (Pelaporan Alamat HP ke Server)
  /// ──────────────────────────────────────────────────────────
  Future<void> _syncToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) await _sendTokenToServer(token);
    } catch (e) {
      debugPrint('FCM Token sync failed: $e');
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      final repo = di.sl<AuthRepository>();
      await repo.updateFcmToken(token);
      debugPrint('FCM: Token updated on server');
    } catch (e) {
      debugPrint('FCM: Server sync failed: $e');
    }
  }

  Future<String?> getToken() async => await _fcm.getToken();
}
