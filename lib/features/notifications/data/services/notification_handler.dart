import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../../domain/entities/alert_type.dart';

/// Global instance for background message handler
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Initialize local notifications
Future<void> initializeLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Handle notification tap
      print('📱 Notification tapped: ${response.payload}');
    },
  );

  // Create notification channel for Android
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // name
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 Background message received: ${message.messageId}');
  print('   Title: ${message.notification?.title}');
  print('   Body: ${message.notification?.body}');
  print('   Data: ${message.data}');

  // Save notification to Firestore
  await _saveNotificationToFirestore(message);
}

/// Save notification to Firestore
Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
  try {
    final data = message.data;
    final parentId = data['parentId'] as String?;
    final childId = data['childId'] as String?;

    if (parentId == null || childId == null) {
      print('⚠️ Missing parentId or childId in notification data');
      return;
    }

    final notification = NotificationModel(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      parentId: parentId,
      childId: childId,
      alertType: AlertTypeExtension.fromString(data['alertType'] ?? 'general'),
      title: message.notification?.title ?? data['title'] ?? 'Notification',
      body: message.notification?.body ?? data['body'] ?? '',
      data: data,
      timestamp: message.sentTime ?? DateTime.now(),
      isRead: false,
      actionUrl: data['actionUrl'] as String?,
    );

    await FirebaseFirestore.instance
        .collection('parents')
        .doc(parentId)
        .collection('notifications')
        .add(notification.toMap());

    print('✅ Notification saved to Firestore');
  } catch (e) {
    print('❌ Error saving notification to Firestore: $e');
  }
}

/// Handle foreground messages
Future<void> handleForegroundMessage(RemoteMessage message) async {
  print('🔔 Foreground message received: ${message.messageId}');
  print('   Title: ${message.notification?.title}');
  print('   Body: ${message.notification?.body}');
  print('   Data: ${message.data}');

  // Show local notification
  await _showLocalNotification(message);

  // Save to Firestore
  await _saveNotificationToFirestore(message);
}

/// Show local notification
Future<void> _showLocalNotification(RemoteMessage message) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    channelDescription: 'This channel is used for important notifications.',
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
    playSound: true,
    enableVibration: true,
  );

  const DarwinNotificationDetails iOSPlatformChannelSpecifics =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
  );

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.notification?.title ?? 'Notification',
    message.notification?.body ?? '',
    platformChannelSpecifics,
    payload: message.data.toString(),
  );
}

