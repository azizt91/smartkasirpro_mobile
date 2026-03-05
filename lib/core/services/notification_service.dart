import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../injection_container.dart' as di;
import '../../features/auth/domain/repositories/auth_repository.dart';

/// ──────────────────────────────────────────────────────────
/// BACKGROUND HANDLER  (top-level, required by FCM)
/// ──────────────────────────────────────────────────────────
/// This handler runs in a SEPARATE ISOLATE when the app is in
/// background or killed. We must initialize Firebase and create
/// fresh plugin instances here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // CRITICAL: Must initialize Firebase in background isolate
  await Firebase.initializeApp();
  debugPrint('FCM BG: notification=${message.notification?.title}, data=${message.data}');

  // Create a fresh local-notification plugin for this isolate
  final localPlugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await localPlugin.initialize(const InitializationSettings(android: androidInit));

  // Determine the sound channel from the data payload
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
  final channelId = channelMap[notifType] ?? 'high_importance_channel';
  final soundKey = soundKeyMap[notifType] ?? 'order_alert';

  // Create the channel in this isolate (Android is idempotent — safe to call repeatedly)
  final androidPlugin = localPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(AndroidNotificationChannel(
      channelId,
      'Notifikasi - $notifType',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      sound: RawResourceAndroidNotificationSound('notif_$soundKey'),
    ));
    // Also create the fallback channel
    await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));
  }

  // Build notification details
  final androidDetails = AndroidNotificationDetails(
    channelId,
    'Notifikasi - $notifType',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    sound: RawResourceAndroidNotificationSound('notif_$soundKey'),
    icon: '@mipmap/ic_launcher',
  );

  // Determine title/body from notification payload or data payload
  String? title;
  String? body;
  if (message.notification != null) {
    title = message.notification!.title;
    body = message.notification!.body;
  } else {
    title = message.data['title'] ?? 'Notifikasi Baru';
    body = message.data['body'] ?? '';
  }

  // Show the local notification
  await localPlugin.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    title,
    body,
    NotificationDetails(android: androidDetails),
  );
  debugPrint('FCM BG: local notification shown for $notifType');
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
    if (soundKey == 'silent') return;
    try {
      final player = AudioPlayer();
      // Play directly from Android raw resources
      await player.play(AssetSource('../res/raw/notif_$soundKey.mp3'));
      // Auto-dispose after playback finishes
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (e) {
      debugPrint('Preview sound error: $e');
      // Fallback: try wav format
      try {
        final player = AudioPlayer();
        await player.play(AssetSource('../res/raw/notif_$soundKey.wav'));
        player.onPlayerComplete.listen((_) => player.dispose());
      } catch (e2) {
        debugPrint('Preview sound fallback error: $e2');
      }
    }
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
