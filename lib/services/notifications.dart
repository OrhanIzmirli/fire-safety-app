// lib/services/notifications.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

Future<void> initLocalNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await notifications.initialize(initSettings);

  // Android 8+ kanal
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'fire_alerts', // kanal id
    'Yangın Uyarıları', // görünen ad
    description: 'Yeni yangınlar için uyarı kanalı',
    importance: Importance.max,
  );

  final androidImpl =
      notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidImpl?.createNotificationChannel(channel);

  // Android 13+ için bildirim izni
  if (Platform.isAndroid) {
    await androidImpl?.requestNotificationsPermission();
  }
}
