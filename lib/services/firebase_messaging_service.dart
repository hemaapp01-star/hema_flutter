import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Firebase Cloud Messaging Service
/// Handles push notification setup, token management, and message handling
class FirebaseMessagingService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// Initialize Firebase Messaging WITHOUT requesting permissions
  /// Sets up message handlers only. Call requestPermissionAndSetupToken() later to request permissions.
  static Future<void> initializeWithoutPermission() async {
    try {
      // Setup message handlers (these work even if permission is not granted yet)
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Check if app was opened from a terminated state via notification
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage);
      }

      // Check if permission was already granted and setup token listener
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _setupTokenListener();
      }
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
      // Don't rethrow - allow app to continue even if messaging fails
    }
  }

  /// Initialize Local Notifications plugin
  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('ic_stat_hema');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Local notification tapped: ${response.payload}');
        // Handle navigation here if needed using a global navigator key or similar approach
        // Since we are in a static method, accessing context is hard.
        // For now, heads-up notifications often just open the app.
      },
    );

    // Create high importance channel for Android
    if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        
        await androidImplementation?.createNotificationChannel(
            const AndroidNotificationChannel(
                'high_importance_channel', // id
                'High Importance Notifications', // title
                description: 'This channel is used for important notifications.', // description
                importance: Importance.max,
            ),
        );
    }
  }

  /// Request notification permissions and setup FCM token
  /// Call this when user toggles availability ON
  static Future<bool> requestPermissionAndSetupToken() async {
    try {
      debugPrint('FCM: Requesting permission...');
      // Request permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('User notification permission: ${settings.authorizationStatus}');

      // Only try to get FCM token if permission is granted
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('FCM: Permission granted, setting up token listener...');
        await _setupTokenListener();
        return true;
      } else {
        debugPrint('Notification permission denied or blocked. Push notifications will not work.');
        return false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Setup FCM token and token refresh listener
  static Future<void> _setupTokenListener() async {
    try {
      debugPrint('FCM: Entering _setupTokenListener. Platform: $defaultTargetPlatform');
      
      // For iOS, we must wait for the APNs token before requesting the FCM token
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        debugPrint('FCM: iOS detected, waiting for APNs token...');
        bool gotToken = await _waitForAPNSToken();
        if (!gotToken) {
          debugPrint('FCM: Failed to get APNs token after retries. FCM token request may fail.');
        }
      }

      debugPrint('FCM: Attempting to get token...');
      String? token = await _messaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        await _saveFCMToken(token);
      } else {
        debugPrint('FCM: Token returned null');
      }

      // Listen to token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        _saveFCMToken(newToken);
      });
    } catch (e) {
      debugPrint('Error setting up token listener: $e');
    }
  }

  /// Wait for APNs token to be available (iOS only)
  /// Retries every 1 second for up to 30 seconds
  static Future<bool> _waitForAPNSToken() async {
    int retryCount = 0;
    const maxRetries = 30;

    debugPrint('FCM: Starting _waitForAPNSToken loop...');

    while (retryCount < maxRetries) {
      try {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) {
          debugPrint('FCM: APNs token successfully received: $apnsToken (after $retryCount retries)');
          return true;
        }
      } catch (e) {
        debugPrint('FCM: Exception during getAPNSToken: $e');
      }

      retryCount++;
      if (retryCount % 5 == 0 || retryCount == 1) {
        debugPrint('FCM: Still waiting for APNs token (retry $retryCount/$maxRetries)...');
      }
      await Future.delayed(const Duration(seconds: 1));
    }

    debugPrint('FCM: Timeout waiting for APNs token after $maxRetries seconds');
    return false;
  }

  /// Save FCM token to Firestore user document
  static Future<void> _saveFCMToken(String token) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('FCM token saved to Firestore');
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Handle messages received when app is in foreground
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground message received: ${message.messageId}');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');

    // Show local notification for heads-up display
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            icon: android?.smallIcon ?? 'ic_stat_hema',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
          ),
        ),
        payload: message.data.toString(), // Simplify payload for now
      );
    }
  }

  /// Handle messages when app is opened from background or terminated state
  static void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('Background message opened: ${message.messageId}');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');

    // Handle navigation based on message data
    // Example: Navigate to specific screen based on notification type
    if (message.data.containsKey('type')) {
      final type = message.data['type'];
      debugPrint('Notification type: $type');
      // Add navigation logic here based on type
      // e.g., if (type == 'blood_request') { navigate to request details }
    }
  }

  /// Subscribe to a topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }

  /// Get current FCM token
  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Delete FCM token (useful for logout)
  static Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      debugPrint('FCM token deleted');
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }
}

/// Top-level function to handle background messages
/// Must be a top-level function (not inside a class)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message handler: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');
}
