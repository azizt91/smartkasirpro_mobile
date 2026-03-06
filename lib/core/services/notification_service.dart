import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../injection_container.dart' as di;
import '../../features/auth/domain/repositories/auth_repository.dart';

/// ──────────────────────────────────────────────────────────
/// ID CHANNEL TUNGGAL (Reset Memori Android)
/// ──────────────────────────────────────────────────────────
const String kMainChannelId = 'smart_kasir_v7_urgent';

/// ──────────────────────────────────────────────────────────
/// BACKGROUND HANDLER (Wajib di luar class)
/// ──────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM BG: Pesanan Masuk');

  // Pilih suara berdasarkan tipe (Default: order_alert)
  final type = message.data['notification_type'] ?? 'order';
  final soundFile = (type == 'order') ? 'notif_order_alert' : 'notif_chime';

  final localPlugin = FlutterLocalNotificationsPlugin();
  await localPlugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ));

  // Munculkan manual jika OS tidak otomatis memunculkan (Data-only payload)
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
    // 1. Izin Dasar Notifikasi
    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    
    // 2. Izin Agar Tetap Muncul saat Aplikasi Dibuka (Foreground)
    await _fcm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    // 3. Init Local Notification
    await _local.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    
    // 4. Daftarkan Channel Urgent ke Sistem Android
    final androidPlugin = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        kMainChannelId,
        'Notifikasi Pesanan',
        importance: Importance.max, // Level tertinggi agar popup muncul
        playSound: true,
        enableVibration: true,
        showBadge: true,
        sound: RawResourceAndroidNotificationSound('notif_order_alert'),
      ));
      await androidPlugin.requestNotificationsPermission();
    }

    // 5. Listener saat aplikasi SEDANG DIBUKA
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? message.data['title'] ?? 'Pesanan Baru';
      final body = message.notification?.body ?? message.data['body'] ?? '';
      _showInstant(title, body, message);
    });

    // 6. Listener saat aplikasi di background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 7. SINKRONISASI TOKEN KE SERVER (Sangat Penting!)
    await _syncToken();
    _fcm.onTokenRefresh.listen((newToken) async {
      await _sendTokenToServer(newToken);
    });
  }

  // Fungsi memaksa popup muncul di depan muka saat aplikasi terbuka
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
          fullScreenIntent: true, // Memaksa popup menembus layar aktif
          playSound: true,
          sound: RawResourceAndroidNotificationSound(soundFile),
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  /// ──────────────────────────────────────────────────────────
  /// LOGIKA TOKEN SYNC (Jembatan ke Database)
  /// ──────────────────────────────────────────────────────────
  Future<void> _syncToken() async {
    try {
      final token = await _fcm.getToken();
      if (kDebugMode) print('FCM Token: $token');
      if (token != null) await _sendTokenToServer(token);
    } catch (e) {
      debugPrint('FCM: Gagal mengambil token: $e');
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      final repo = di.sl<AuthRepository>();
      await repo.updateFcmToken(token);
      debugPrint('FCM: Token berhasil dilaporkan ke database');
    } catch (e) {
      debugPrint('FCM: Gagal lapor token ke server: $e');
    }
  }

  Future<String?> getToken() async => await _fcm.getToken();
}