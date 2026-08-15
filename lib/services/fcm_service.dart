import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  
  // Add a field to store the token document ID from server
  String? _fcmTokenDocId;

  Future<void> initialize() async {
    try {
      // Request permission for notifications
      await _requestPermission();
      
      // Initialize local notifications (except on web)
      if (!kIsWeb) {
        await _initializeLocalNotifications();
      }
      
      // Get FCM token
      await _getFCMToken();
      
      // Set up message handlers
      _setupMessageHandlers();
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing FCM service: $e');
      }
    }
  }

  Future<void> _requestPermission() async {
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        announcement: false,
      );

      if (kDebugMode) {
        print('FCM Permission granted: ${settings.authorizationStatus}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting FCM permission: $e');
      }
    }
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings();

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(initializationSettings);
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing local notifications: $e');
      }
    }
  }

  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print('FCM Token: $_fcmToken');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
    }
  }

  void _setupMessageHandlers() {
    try {
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle background messages (not for web)
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
      }
      
      // Handle when app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      
      // Handle token refresh
      _firebaseMessaging.onTokenRefresh.listen(_handleTokenRefresh);
    } catch (e) {
      if (kDebugMode) {
        print('Error setting up message handlers: $e');
      }
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('Foreground message: ${message.messageId}');
    }
    
    // Show local notification for foreground messages (except on web)
    if (!kIsWeb) {
      await _showLocalNotification(message);
    }
  }

  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    if (kDebugMode) {
      print('Message opened app: ${message.messageId}');
    }
    // Handle navigation based on message data
  }

  void _handleTokenRefresh(String token) async {
    _fcmToken = token;
    if (kDebugMode) {
      print('FCM Token refreshed: $token');
    }
    // Update token in your backend
    await updateTokenInBackend(token);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'school_channel_id',
        'School Notifications',
        channelDescription: 'Notifications for school management app',
        importance: Importance.max,
        priority: Priority.high,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? 'School Notification',
        message.notification?.body ?? 'You have a new notification',
        platformChannelSpecifics,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error showing local notification: $e');
      }
    }
  }

  // Subscribe to school topic - not available for web
  Future<void> subscribeToSchoolTopic(String schoolId) async {
    try {
      if (!kIsWeb) {
        await _firebaseMessaging.subscribeToTopic('school_$schoolId');
        if (kDebugMode) {
          print('Subscribed to topic: school_$schoolId');
        }
      } else {
        // For web, we'd need to handle topic subscription differently
        // through the backend. Log for clarity.
        if (kDebugMode) {
          print('Topic subscription for web must be handled by backend: school_$schoolId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error subscribing to topic: $e');
      }
    }
  }

  // Unsubscribe from school topic - not available for web
  Future<void> unsubscribeFromSchoolTopic(String schoolId) async {
    try {
      if (!kIsWeb) {
        await _firebaseMessaging.unsubscribeFromTopic('school_$schoolId');
        if (kDebugMode) {
          print('Unsubscribed from topic: school_$schoolId');
        }
      } else {
        // For web, we'd need to handle topic unsubscription differently
        if (kDebugMode) {
          print('Topic unsubscription for web must be handled by backend: school_$schoolId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unsubscribing from topic: $e');
      }
    }
  }

  // Store FCM token in your backend
  Future<void> updateTokenInBackend(String token) async {
    // TODO: Implement API call to store token in your backend
    // This will be called when token is received or refreshed
    if (kDebugMode) {
      print('TODO: Update token in backend: $token');
    }
  }

  // Delete FCM token from server
  Future<void> deleteFCMTokenFromServer(String userId) async {
    try {
      // First try to delete using stored token ID if available
      if (_fcmTokenDocId != null) {
        final response = await http.delete(
          Uri.parse('https://nova-backend-tlzr.onrender.com/api/fcm/token/$_fcmTokenDocId'),
        );
        
        if (response.statusCode == 200) {
          if (kDebugMode) {
            print('🔔 FCM token deleted from server successfully');
          }
          _fcmTokenDocId = null; // Reset token ID after successful deletion
          return;
        } else {
          if (kDebugMode) {
            print('⚠️ Failed to delete FCM token by ID, falling back to userId method');
          }
        }
      }
      
      // Fallback: Delete by userId if token ID is not available or deletion failed
      final userResponse = await http.delete(
        Uri.parse('https://nova-backend-tlzr.onrender.com/api/fcm/token/user/$userId'),
      );
      
      if (userResponse.statusCode == 200) {
        if (kDebugMode) {
          print('🔔 FCM token(s) deleted by userId successfully');
        }
        _fcmTokenDocId = null; // Ensure token ID is cleared
      } else if (userResponse.statusCode == 404) {
        if (kDebugMode) {
          print('ℹ️ No FCM tokens found for user: $userId');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ Failed to delete FCM token by userId: ${userResponse.statusCode} - ${userResponse.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error deleting FCM token from server: $e');
      }
    }
  }
  // Store user FCM data and token ID
  Future<void> storeFCMDataForUser({
    required String userId,
    required String schoolId,
    required String userRole,
    String? classId,
  }) async {
    try {
      if (kDebugMode) {
        print('📝 FCM storeFCMDataForUser called with classId: $classId');
      }
      
      if (_fcmToken == null) {
        await _getFCMToken();
      }

      // For non-web platforms, subscribe to school topic
      if (!kIsWeb) {
        await subscribeToSchoolTopic(schoolId);
        
        // If it's a student with a class ID, also subscribe to class topic
        if (userRole == 'student' && classId != null && classId.isNotEmpty) {
          await _firebaseMessaging.subscribeToTopic('class_$classId');
          if (kDebugMode) {
            print('📚 Subscribed to class topic: class_$classId');
          }
        }
      }

      // Prepare FCM data to send to backend
      final Map<String, dynamic> fcmData = {
        'userId': userId,
        'token': _fcmToken,  // Changed from 'fcmToken' to 'token' to match API requirement
        'schoolId': schoolId,
        'role': userRole,    // Changed from 'userRole' to 'role' to match API requirement
        'topic': 'school_$schoolId',  // Changed from 'topicSubscribed' to 'topic'
        'deviceType': kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase(),
      };
      
      // Add classId for student role if it exists and is not empty
      if (classId != null && classId.isNotEmpty) {
        fcmData['classId'] = classId;
        if (kDebugMode) {
          print('📝 Adding classId to FCM data: $classId');
        }
      }

      if (kDebugMode) {
        print('FCM Data to store: $fcmData');
      }

      // Register token with backend and get the token document ID
      try {
        final response = await http.post(
          Uri.parse('https://nova-backend-tlzr.onrender.com/api/fcm/token'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(fcmData),
        );
        
        final responseData = json.decode(response.body);
        
        if (response.statusCode == 200 && responseData['success'] == true) {
          // Store the token document ID from successful response
          _fcmTokenDocId = responseData['data']['_id'];
          if (kDebugMode) {
            print('🔔 FCM token document ID stored: $_fcmTokenDocId');
          }
        } else {
          if (kDebugMode) {
            print('⚠️ Failed to register FCM token with server: ${response.statusCode} - ${response.body}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Error registering FCM token: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error storing FCM data: $e');
      }
    }
  }

  // Clear FCM data on logout
  Future<void> clearFCMData(String schoolId, {String? classId}) async {
    try {
      if (!kIsWeb) {
        await unsubscribeFromSchoolTopic(schoolId);
        
        // If classId is provided, unsubscribe from class topic too
        if (classId != null && classId.isNotEmpty) {
          await _firebaseMessaging.unsubscribeFromTopic('class_$classId');
          print('📚 Unsubscribed from class topic: class_$classId');
        }
      }
      // Delete token from backend is now handled separately
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing FCM data: $e');
      }
    }
  }
}


// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  if (kDebugMode) {
    print('Background message: ${message.messageId}');
  }
}
