import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static const String _channelId = 'default_channel_v2';
  static const String _channelName = 'Default v2';
  static const String _channelDescription = 'General notifications';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: true,
    );

    const InitializationSettings initSettings =
    InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse r) {},
    );

    await _createAndroidChannel();

    final granted = await debugRequestAndroidPermission();
    log('✅ Notification permission granted? $granted');

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
    );

    await androidImpl.createNotificationChannel(channel);
  }

  Future<void> show(
      String? title,
      String? body,
      Map<String, dynamic>? data,
      ) async {
    await init();

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails details =
    NotificationDetails(android: androidDetails);

    final int uniqueId = (DateTime.now().millisecondsSinceEpoch +
        math.Random().nextInt(999))
        .remainder(100000000);

    log('📣 Showing local notification id=$uniqueId title=$title');

    await _notifications.show(
      id: uniqueId,
      title: title ?? '',
      body: body ?? '',
      notificationDetails: details,
      payload: data?['rideId']?.toString(),
    );
  }

  Future<bool> debugRequestAndroidPermission() async {
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return true;

    try {
      final dynamic dyn = androidImpl;
      if (dyn.requestNotificationsPermission != null) {
        final res = await dyn.requestNotificationsPermission();
        return res == true;
      }
      if (dyn.requestPermission != null) {
        final res = await dyn.requestPermission();
        return res == true;
      }
    } catch (_) {}
    return false;
  }
}