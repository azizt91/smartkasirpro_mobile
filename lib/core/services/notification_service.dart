import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../injection_container.dart' as di;
import '../../features/auth/domain/repositories/auth_repository.dart';

/// ──────────────────────────────────────────────────────────
/// BACKGROUND HANDLER  (top-level, required by FCM)
/// ──────────────────────────────────────────────────────────
/// When a notification+data message arrives and the app is in background/killed,
/// Android OS auto-displays the notification using the 'notification' payload
/// and the channel_id set by the backend. This handler is only called for
/// data processing — we do NOT show a duplicate local notification here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM BG: ${message.data}');
  // Android OS already displayed the notification via the 'notification' payload.
  // No need to show a local notification here.
}

/// ──────────────────────────────────────────────────────────
/// Sound definitions & category constants
/// ──────────────────────────────────────────────────────────

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
  NotifSound(key: 'cash_register', label: 'Mesin Kasir', description: 'Suara khas register'),
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

/// ──────────────────────────────────────────────────────────
/// NotificationService  (singleton)
/// ──────────────────────────────────────────────────────────

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  String _channelId(String key) => 'channel_$key';

  /// Must be called AFTER Firebase.initializeApp() and DI init.
  Future<void> initialize() async {
    // ── 1. Request permission ──
    final settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true,
    );
    debugPrint('FCM: permission=${settings.authorizationStatus}');

    // CRITICAL: Allow FCM to show notifications when app is in foreground
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    // ── 2. Local notification init ──
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(const InitializationSettings(android: androidInit));

    // ── 3. Create ALL sound channels ──
    await _createAllChannels();

    // ── 4. Background handler ──
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // ── 5. FOREGROUND handler ──
    // When the app is in foreground, notification+data messages arrive here.
    // Android does NOT auto-display them, so we show via flutter_local_notifications
    // using the user's chosen sound channel.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM FG: notification=${message.notification?.title}, data=${message.data}');

      if (message.notification != null) {
        _showLocalNotification(message);
      } else if (message.data.isNotEmpty) {
        _showDataNotification(message);
      }
    });

    // ── 6. Tap handlers ──
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
      debugPrint('FCM: tap from background: ${msg.data}');
    });
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      debugPrint('FCM: opened from terminated: ${initial.data}');
    }

    // ── 7. Token sync ──
    await _syncToken();
    _fcm.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM: token refreshed');
      await _sendTokenToServer(newToken);
    });
  }

  // ────────── Channel creation ──────────

  Future<void> _createAllChannels() async {
    final android = _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    for (final s in availableSounds) {
      final silent = s.key == 'silent';
      await android.createNotificationChannel(AndroidNotificationChannel(
        _channelId(s.key),
        'Notifikasi - ${s.label}',
        description: s.description,
        importance: Importance.max,
        playSound: !silent,
        enableVibration: !silent,
        showBadge: true,
        sound: silent ? null : RawResourceAndroidNotificationSound('notif_${s.key}'),
      ));
    }
    // Fallback channel (always keep for compatibility)
    await android.createNotificationChannel(const AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));
  }

  // ────────── Preference helpers ──────────

  Future<String> getSoundForCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('notif_sound_$category') ??
           kDefaultSounds[category] ??
           kDefaultSounds[kCategoryDefault]!;
  }

  Future<void> setSoundForCategory(String category, String soundKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notif_sound_$category', soundKey);
    debugPrint('NotifPref: $category -> $soundKey');
  }

  // ────────── Category routing ──────────

  String _resolveCategory(RemoteMessage msg) {
    switch (msg.data['notification_type'] ?? '') {
      case 'order': return kCategoryOrder;
      case 'shift': return kCategoryShift;
      case 'audit': return kCategoryAudit;
      default:      return kCategoryDefault;
    }
  }

  AndroidNotificationDetails _androidDetails(String soundKey) {
    final silent = soundKey == 'silent';
    return AndroidNotificationDetails(
      _channelId(soundKey),
      'Notifikasi - ${availableSounds.firstWhere((s) => s.key == soundKey, orElse: () => availableSounds.first).label}',
      importance: Importance.max,
      priority: Priority.high,
      playSound: !silent,
      enableVibration: !silent,
      sound: silent ? null : RawResourceAndroidNotificationSound('notif_$soundKey'),
      icon: '@mipmap/ic_launcher',
    );
  }

  // ────────── Show notifications (foreground) ──────────

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final category = _resolveCategory(message);
    getSoundForCategory(category).then((soundKey) {
      _local.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(android: _androidDetails(soundKey)),
      );
    });
  }

  void _showDataNotification(RemoteMessage message) {
    final data = message.data;
    final title = data['title'] ?? 'Notifikasi Baru';
    final body  = data['body']  ?? '';
    final category = _resolveCategory(message);

    getSoundForCategory(category).then((soundKey) {
      _local.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        NotificationDetails(android: _androidDetails(soundKey)),
      );
    });
  }

  // ────────── Sound preview ──────────

  Future<void> previewSound(String soundKey) async {
    final label = availableSounds
        .firstWhere((s) => s.key == soundKey, orElse: () => availableSounds.first)
        .label;
    await _local.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      '🔔 Preview: $label',
      'Ini contoh nada notifikasi',
      NotificationDetails(android: _androidDetails(soundKey)),
    );
  }

  // ────────── Token sync ──────────

  Future<void> _syncToken() async {
    try {
      final token = await _fcm.getToken();
      debugPrint('FCM Token: ${token?.substring(0, 20)}...');
      if (token != null) await _sendTokenToServer(token);
    } catch (e) {
      debugPrint('FCM: token get failed: $e');
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      final repo = di.sl<AuthRepository>();
      await repo.updateFcmToken(token);
      debugPrint('FCM: token synced to backend');
    } catch (e) {
      debugPrint('FCM: token sync failed (will retry): $e');
    }
  }

  Future<String?> getToken() async => await _fcm.getToken();
}
