import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'client_channel_v1';
  static const String _channelName = 'DosaDriver Client';
  static const String _channelDescription = 'Ride notifications';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    await _createAndroidChannel();

    _initialized = true;
  }

  Future<void> _createAndroidChannel() async {
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await androidImpl.createNotificationChannel(channel);
  }

  int _notifId = 0;

  void _onNotificationTap(NotificationResponse response) {
    // Navigation handled by the app's route listener using payload
  }

  Future<void> show(String? title, String? body, Map<String, dynamic>? data) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
    );

    final NotificationDetails details =
        NotificationDetails(android: androidDetails);

    final payload = data?['rideId']?.toString() ?? data?['ride_id']?.toString() ?? '';
    await _notifications.show(_notifId++, title, body, details, payload: payload);
  }

  Future<String?> getToken() async {
    return await FirebaseMessaging.instance.getToken();
  }
}
