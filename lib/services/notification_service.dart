// lib/services/notification_service.dart
import 'package:flutter/material.dart'; 
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();

  // Initialize notification service
  Future<void> init() async {
    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle when user taps on notification
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    // Request notification permission for Android 13+
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    await androidPlugin?.requestNotificationsPermission();
  }

  // Show success notification in notification bar
  Future<void> showSuccessNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Android notification details
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'attendance_channel', // channel id
      'Attendance Notifications', // channel name
      channelDescription: 'Notifications for attendance recording results',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      color: const Color(0xFF4CAF50), // Green color
      visibility: NotificationVisibility.public,
    );

    // iOS notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Show notification in notification bar
    await flutterLocalNotificationsPlugin.show(
      0, // notification id
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  // Show error notification in notification bar
  Future<void> showErrorNotification({
    required String title,
    required String body,
  }) async {
    // Android notification details
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'attendance_channel',
      'Attendance Notifications',
      channelDescription: 'Notifications for attendance recording results',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFFF44336), // Red color
    );

    // iOS notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      1,
      title,
      body,
      platformDetails,
    );
  }
}