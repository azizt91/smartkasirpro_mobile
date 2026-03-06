import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../injection_container.dart' as di;
import '../../features/auth/domain/repositories/auth_repository.dart';

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
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
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
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
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