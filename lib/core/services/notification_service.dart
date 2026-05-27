import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:lastbite/core/router/app_router.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // 1. Request Permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) print('User granted permission');
    }

    // 2. Initialize Local Notifications (For Foreground)
    final AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          _navigateFromNotification(details.payload!);
        }
      },
    );

    // 3. Handle Foreground Messages (FCM)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) print('Got a message whilst in the foreground!');
      if (kDebugMode) print('Message data: ${message.data}');

      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    // 4. Handle Background Messages Tap (FCM)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data.containsKey('route')) {
        _navigateFromNotification(message.data['route']);
      }
    });

    // 5. Handle Terminated App Messages Tap (FCM)
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null && initialMessage.data.containsKey('route')) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateFromNotification(initialMessage.data['route']);
      });
    }
    await updateToken();
  }

  static void _navigateFromNotification(String route) {
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      context.go(route);
    } else {
      if (kDebugMode) print('Warning: Navigator Context is null, cannot redirect to $route');
    }
  }

  static Future<void> updateToken() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      String? token;
      if (kIsWeb) {
        // Handle web if needed
      } else if (Platform.isAndroid || Platform.isIOS) {
        token = await _fcm.getToken();
      }

      if (token != null) {
        if (kDebugMode) print('FCM Token: $token');
        await Supabase.instance.client
            .from('users')
            .update({'fcm_token': token})
            .eq('id', user.id);
      }
    } catch (e) {
      if (kDebugMode) print('Error updating FCM token: $e');
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'lastbite_channel',
      'LastBite Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.show(
      id: message.hashCode,
      title: message.notification?.title,
      body: message.notification?.body,
      notificationDetails: platformChannelSpecifics,
      payload: message.data['route'],
    );
  }
}
