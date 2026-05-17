import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class NotificationSettings {
  static Future<void> openAppNotificationSettings() async {
    if (!Platform.isAndroid) return;

    // Android settings deep link
    final uri = Uri.parse('android.settings.APP_NOTIFICATION_SETTINGS');

    // This opens the general notification settings screen.
    // On MIUI it will still show app-specific toggles.
    if (!await launchUrl(uri)) {
      // fallback: open app settings if notification screen doesn't open
      await launchUrl(Uri.parse('android.settings.APPLICATION_DETAILS_SETTINGS'));
    }
  }
}