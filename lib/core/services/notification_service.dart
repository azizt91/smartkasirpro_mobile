import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Wajib ada untuk build
import '../../injection_container.dart' as di;
import '../../features/auth/domain/repositories/auth_repository.dart';

/// ──────────────────────────────────────────────────────────
/// KONSTANTA & CLASS (Dibutuhkan agar notification_settings_page tidak error)
/// ──────────────────────────────────────────────────────────
const String kMainChannelId = 'smart_kasir_v7_urgent';

class NotifSound {
  final String key;
  final String label;
  final String description;
  const NotifSound({required this.key, required this.label, required this.description});
}

const String kCategoryOrder   = 'order';
const String kCategoryShift   = 'shift';
const String kCategoryAudit   = 'audit';
const String kCategoryDefault = 'default';

const List<NotifSound> availableSounds = [
  NotifSound(key: 'order_alert', label: 'Pesanan Masuk', description: 'Nada cepat seperti Gojek'),
  NotifSound(key: 'chime', label: 'Lonceng', description: 'Nada chime lembut'),
  NotifSound(key: 'silent', label: 'Diam', description: 'Tanpa suara'),
];

/// ──────────────────────────────────────────────────────────
/// BACKGROUND HANDLER
/// ──────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  final type = message.data['notification_type'] ?? 'order';
  final soundFile = (type == 'order') ? 'notif_order_alert' : 'notif_chime';

  final localPlugin = FlutterLocalNotificationsPlugin();
  await localPlugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ));

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
    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    await _fcm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    await _local.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    
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

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? message.data['title'] ?? 'Pesanan Baru';
      final body = message.notification?.body ?? message.data['body'] ?? '';
      _showInstant(title, body, message);
    });

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _syncToken();
  }

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
  /// FUNGSI FORMALITAS (Wajib ada agar Build APK tidak Error)
  /// ──────────────────────────────────────────────────────────
  Future<String> getSoundForCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('notif_sound_$category') ?? 'order_alert';
  }

  Future<void> setSoundForCategory(String category, String soundKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notif_sound_$category', soundKey);
  }

  /// ──────────────────────────────────────────────────────────
  /// LOGIKA TOKEN SYNC
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
    } catch (e) {
      debugPrint('FCM Server sync failed: $e');
    }
  }

  Future<String?> getToken() async => await _fcm.getToken();
}