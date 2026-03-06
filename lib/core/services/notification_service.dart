import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../injection_container.dart' as di;
import '../../features/auth/domain/repositories/auth_repository.dart';

/// ──────────────────────────────────────────────────────────
/// BACKGROUND HANDLER (top-level, required by FCM)
/// ──────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM BG: notification=${message.notification?.title}, data=${message.data}');

  final notifType = message.data['notification_type'] ?? 'default';
  final channelMap = {
    'order': 'channel_order_alert',
    'shift': 'channel_chime',
    'audit': 'channel_ding',
  };
  final soundKeyMap = {
    'order': 'order_alert',
    'shift': 'chime',
    'audit': 'ding',
  };
  
  // MENGGUNAKAN V5 UNTUK FORCE CHANNEL BARU
  final channelId = channelMap[notifType] == null 
      ? 'smart_kasir_v5_high_importance_channel' 
      : 'smart_kasir_v5_${channelMap[notifType]}';
  final soundKey = soundKeyMap[notifType] ?? 'order_alert';

  final localPlugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await localPlugin.initialize(const InitializationSettings(android: androidInit));

  final androidPlugin = localPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  
  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(AndroidNotificationChannel(
      channelId,
      'Notifikasi Kasir - $notifType',
      importance: Importance.max, // LEVEL MAX
      playSound: true,
      enableVibration: true,
      showBadge: true,
      sound: RawResourceAndroidNotificationSound('notif_$soundKey'),
    ));
  }

  if (message.notification != null) {
    debugPrint('FCM BG: Notification automatically displayed by OS.');
    return;
  }

  // Menampilkan manual hanya untuk DATA payload
  final androidDetails = AndroidNotificationDetails(
    channelId,
    'Notifikasi Kasir',
    importance: Importance.max,
    priority: Priority.max, // LEVEL MAX
    playSound: true,
    enableVibration: true,
    fullScreenIntent: true, // FORCE POPUP
    sound: RawResourceAndroidNotificationSound('notif_$soundKey'),
    icon: '@mipmap/ic_launcher',
  );

  await localPlugin.show(
    Random().nextInt(2147483647),
    message.data['title'] ?? 'Notifikasi Baru',
    message.data['body'] ?? '',
    NotificationDetails(android: androidDetails),
  );
}

class NotifSound {
  final String key;
  final String label;
  final String description;
  const NotifSound({required this.key, required this.label, required this.description});
}

const List<NotifSound> availableSounds = [
  NotifSound(key: 'order_alert', label: 'Pesanan Masuk', description: 'Nada cepat seperti Gojek'),
  NotifSound(key: 'chime', label: 'Lonceng', description: 'Nada chime lembut'),
  NotifSound(key: 'ding', label: 'Ding', description: 'Nada ding pendek'),
  NotifSound(key: 'cash_register', label: 'Meser Kasir', description: 'Suara khas register'),
  NotifSound(key: 'bell', label: 'Bel Toko', description: 'Suara bel pintu toko'),
  NotifSound(key: 'silent', label: 'Diam', description: 'Tanpa suara'),
];

const String kCategoryOrder   = 'order';
const String kCategoryShift   = 'shift';
const String kCategoryAudit   = 'audit';
const String kCategoryDefault = 'default';

const Map<String, String> kDefaultSounds = {
  kCategoryOrder:   'order_alert',
  kCategoryShift:   'chime',
  kCategoryAudit:   'ding',
  kCategoryDefault: 'order_alert',
};

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  // PREFIX V5 UNTUK MEMASTIKAN CACHE OS TERHAPUS
  String _channelId(String key) => 'smart_kasir_v5_$key';

  Future<void> initialize() async {
    final settings = await _fcm.requestPermission(alert: true, badge: true, sound: true);
    debugPrint('FCM: permission=${settings.authorizationStatus}');

    // PENTING: Foreground settings
    await _fcm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(const InitializationSettings(android: androidInit));
    
    // Explicit permission Android 13+
    await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();

    await _createAllChannels();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM FG: Recieved notification in foreground');
      if (message.notification != null) {
        _showLocalNotificationFast(message);
      } else if (message.data.isNotEmpty) {
        _showDataNotificationFast(message);
      }
    });

    await _syncToken();
  }

  Future<void> _createAllChannels() async {
    final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    for (final s in availableSounds) {
      final silent = s.key == 'silent';
      await android.createNotificationChannel(AndroidNotificationChannel(
        _channelId(s.key),
        'Notifikasi - ${s.label}',
        description: s.description,
        importance: Importance.max, // SET KE MAX
        playSound: !silent,
        enableVibration: !silent,
        showBadge: true,
        sound: silent ? null : RawResourceAndroidNotificationSound('notif_${s.key}'),
      ));
    }
  }

  String _resolveCategory(RemoteMessage msg) {
    switch (msg.data['notification_type'] ?? '') {
      case 'order': return kCategoryOrder;
      case 'shift': return kCategoryShift;
      case 'audit': return kCategoryAudit;
      default:      return kCategoryDefault;
    }
  }

  // FUNGSI INSTANT TANPA ASYNC DELAY
  void _showLocalNotificationFast(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final category = _resolveCategory(message);
    final soundKey = category == kCategoryOrder ? 'notif_order_alert' : 
                     category == kCategoryShift ? 'notif_chime' : 
                     category == kCategoryAudit ? 'notif_ding' : 'notif_order_alert';

    _local.show(
      Random().nextInt(2147483647),
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'smart_kasir_v5_high_importance_channel',
          'Notifikasi Urgent',
          importance: Importance.max,
          priority: Priority.max, // PRIORITAS TERTINGGI
          fullScreenIntent: true, // MUNCULKAN POPUP
          playSound: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound(soundKey),
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  void _showDataNotificationFast(RemoteMessage message) {
    final category = _resolveCategory(message);
    final soundKey = category == kCategoryOrder ? 'notif_order_alert' : 
                     category == kCategoryShift ? 'notif_chime' : 
                     category == kCategoryAudit ? 'notif_ding' : 'notif_order_alert';

    _local.show(
      Random().nextInt(2147483647),
      message.data['title'] ?? 'Pesanan Baru',
      message.data['body'] ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'smart_kasir_v5_high_importance_channel',
          'Notifikasi Urgent',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          playSound: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound(soundKey),
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  // --- Utility Functions (Sync Token & Sound Preview) ---
  Future<void> previewSound(String soundKey) async {
    if (soundKey == 'silent') return;
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('../res/raw/notif_$soundKey.mp3'));
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (e) {
      debugPrint('Preview error: $e');
    }
  }

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