import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../injection_container.dart' as di;
import '../../features/auth/domain/repositories/auth_repository.dart';

// Top-level function required for background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.data}');
}

/// Available notification sound options
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

/// Notification categories that can be independently configured
const String kCategoryOrder = 'order';
const String kCategoryShift = 'shift';
const String kCategoryAudit = 'audit';
const String kCategoryDefault = 'default';

/// Default sounds per category
const Map<String, String> kDefaultSounds = {
  kCategoryOrder: 'order_alert',
  kCategoryShift: 'chime',
  kCategoryAudit: 'ding',
  kCategoryDefault: 'order_alert',
};

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// Map of soundKey -> channelId
  String _channelId(String soundKey) => 'channel_$soundKey';

  Future<void> initialize() async {
    // 1. Request Permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('FCM: User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('FCM: User granted provisional permission');
    } else {
      debugPrint('FCM: User declined or has not accepted permission');
    }

    // Allow FCM to show notifications even when app is in foreground
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Initialize Local Notifications (for foreground)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotifications.initialize(initializationSettings);

    // 3. Create all notification channels (one per sound)
    await _createAllChannels();

    // 4. Set Background Message Handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 5. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM: Got a message whilst in the foreground!');
      debugPrint('FCM: Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('FCM: Notification title: ${message.notification!.title}');
        _showLocalNotification(message);
      } else if (message.data.isNotEmpty) {
        debugPrint('FCM: Data-only message, showing local notification');
        _showDataNotification(message);
      }
    });

    // 6. Handle notification tap when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM: Notification tapped (from background): ${message.data}');
    });

    // Check if app was opened from a terminated state via notification
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM: App opened from terminated state via notification: ${initialMessage.data}');
    }

    // 7. Get Token (to send to server)
    String? token = await _firebaseMessaging.getToken();
    debugPrint("FCM Token: $token");
    
    if (token != null) {
      try {
        final authRepository = di.sl<AuthRepository>(); 
        await authRepository.updateFcmToken(token);
        debugPrint("FCM Token sent to backend successfully");
      } catch (e) {
        debugPrint("Failed to sync FCM token: $e");
      }
    }
    
    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
       debugPrint("FCM Token Refreshed: $newToken");
       try {
          final authRepository = di.sl<AuthRepository>();
          await authRepository.updateFcmToken(newToken);
          debugPrint("Refreshed FCM Token sent to backend");
       } catch (e) {
          debugPrint("Failed to sync new FCM token: $e");
       }
    });
  }

  /// Create all notification channels (one per sound option)
  Future<void> _createAllChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin == null) return;

    for (final sound in availableSounds) {
      final isSilent = sound.key == 'silent';
      final channel = AndroidNotificationChannel(
        _channelId(sound.key),
        'Notifikasi - ${sound.label}',
        description: sound.description,
        importance: Importance.max,
        playSound: !isSilent,
        enableVibration: !isSilent,
        showBadge: true,
        sound: isSilent
            ? null
            : RawResourceAndroidNotificationSound('notif_${sound.key}'),
      );
      await androidPlugin.createNotificationChannel(channel);
    }

    // Also keep the default high_importance_channel as fallback
    const fallbackChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    await androidPlugin.createNotificationChannel(fallbackChannel);
  }

  /// Get the user's preferred sound for a notification category
  Future<String> getSoundForCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('notif_sound_$category') ?? 
           kDefaultSounds[category] ?? 
           kDefaultSounds[kCategoryDefault]!;
  }

  /// Set the user's preferred sound for a notification category
  Future<void> setSoundForCategory(String category, String soundKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notif_sound_$category', soundKey);
    debugPrint('NotifSound: Set $category -> $soundKey');
  }

  /// Determine the notification category from message data
  String _getCategoryFromMessage(RemoteMessage message) {
    final type = message.data['notification_type'] ?? '';
    switch (type) {
      case 'order':
        return kCategoryOrder;
      case 'shift':
        return kCategoryShift;
      case 'audit':
        return kCategoryAudit;
      default:
        return kCategoryDefault;
    }
  }

  /// Build AndroidNotificationDetails for the given sound key
  AndroidNotificationDetails _buildAndroidDetails(String soundKey) {
    final isSilent = soundKey == 'silent';
    return AndroidNotificationDetails(
      _channelId(soundKey),
      'Notifikasi - ${availableSounds.firstWhere((s) => s.key == soundKey, orElse: () => availableSounds.first).label}',
      importance: Importance.max,
      priority: Priority.high,
      playSound: !isSilent,
      enableVibration: !isSilent,
      sound: isSilent
          ? null
          : RawResourceAndroidNotificationSound('notif_$soundKey'),
      icon: '@mipmap/ic_launcher',
    );
  }

  void _showLocalNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;

    if (notification != null) {
      final category = _getCategoryFromMessage(message);
      getSoundForCategory(category).then((soundKey) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(android: _buildAndroidDetails(soundKey)),
        );
      });
    }
  }

  void _showDataNotification(RemoteMessage message) {
    final data = message.data;
    final title = data['title'] ?? 'Notifikasi Baru';
    final body = data['body'] ?? '';
    final category = _getCategoryFromMessage(message);

    getSoundForCategory(category).then((soundKey) {
      _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        NotificationDetails(android: _buildAndroidDetails(soundKey)),
      );
    });
  }

  /// Preview a sound by showing a test notification
  Future<void> previewSound(String soundKey) async {
    final sound = availableSounds.firstWhere(
      (s) => s.key == soundKey,
      orElse: () => availableSounds.first,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      '🔔 Preview: ${sound.label}',
      sound.description,
      NotificationDetails(android: _buildAndroidDetails(soundKey)),
    );
  }

  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }
}
