import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'backend_api.dart';

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
  final BackendApi _api = BackendApi();

  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    await _createAndroidChannel();

    await _syncPushToken();
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _registerToken(token);
    });

    _initialized = true;
  }

  Future<void> _syncPushToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      await _registerToken(token);
    } catch (e) {
      debugPrint('FCM token sync failed: $e');
    }
  }

  Future<void> _registerToken(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await _api.registerPushToken(token);
    } catch (e) {
      debugPrint('Push register failed: $e');
    }
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
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    final payload = data?['rideId']?.toString() ?? data?['ride_id']?.toString() ?? '';
    await _notifications.show(
      id: _notifId++,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  Future<String?> getToken() async {
    return FirebaseMessaging.instance.getToken();
  }
}
