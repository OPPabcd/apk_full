import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationFCM {
  // GlobalKey to perform navigation from anywhere in the app without BuildContext
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Initialize listeners for FCM notification click events and foreground messages
  static Future<void> init() async {
    // 0. Ensure Firebase is initialized
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
        debugPrint('[NotificationFCM] Firebase initialized');
      } else {
        debugPrint('[NotificationFCM] Firebase default app already exists');
      }
    } catch (e) {
      debugPrint('[NotificationFCM] Error initializing Firebase: $e');
    }

    // 1. Request push notification permissions
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }

    // 3. Listen for standard FCM Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleIncomingRemoteMessage(message);
    });

    // 4. Handle notification when the app is in the background and opened by tapping it
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleRemoteMessageOpened(message);
    });

    // 5. Handle notification when the app was terminated and opened by tapping it
    try {
      final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleRemoteMessageOpened(initialMessage);
      }
    } catch (e) {
      debugPrint('Error getting initial message: $e');
    }
  }



  /// Check if the notification's nama_user matches the logged-in student's name
  static Future<bool> _shouldShowNotification(Map? data) async {
    if (data == null) return true; // Show by default if no data payload to filter

    final namaUser = _extractNamaUser(data);
    if (namaUser == null || namaUser.isEmpty) {
      return true; // Show by default if data doesn't contain user filter key
    }

    final prefs = await SharedPreferences.getInstance();
    String? loggedInStudentName = prefs.getString('murid_nama');

    // If cache not found, fetch it from Supabase and cache it
    if (loggedInStudentName == null || loggedInStudentName.isEmpty) {
      final nis = prefs.getString('murid_nis');
      final userId = prefs.getString('user_id_admin');
      if (nis != null && userId != null) {
        try {
          final response = await Supabase.instance.client
              .from('murid')
              .select('nama')
              .eq('user_id', userId)
              .eq('nis', nis)
              .maybeSingle();

          if (response != null) {
            loggedInStudentName = response['nama']?.toString();
            if (loggedInStudentName != null) {
              await prefs.setString('murid_nama', loggedInStudentName);
            }
          }
        } catch (e) {
          debugPrint('Error fetching student name for notification filter: $e');
        }
      }
    }

    if (loggedInStudentName != null && loggedInStudentName.isNotEmpty) {
      final matches = loggedInStudentName.trim().toLowerCase() == namaUser.trim().toLowerCase();
      debugPrint('Notification filter - Logged in: "$loggedInStudentName", Incoming: "$namaUser". Match: $matches');
      return matches;
    }

    return true;
  }

  /// Extract nama_user field dynamically from map (handles nested objects from foreign keys)
  static String? _extractNamaUser(Map data) {
    if (data.containsKey('nama_user')) {
      final val = data['nama_user'];
      if (val is Map) {
        return val['name']?.toString() ?? val['nama']?.toString();
      }
      return val?.toString();
    }
    
    // Case insensitive fallback
    for (var key in data.keys) {
      if (key.toString().toLowerCase() == 'nama_user') {
        final val = data[key];
        if (val is Map) {
          return val['name']?.toString() ?? val['nama']?.toString();
        }
        return val?.toString();
      }
    }
    return null;
  }

  /// Handle incoming standard FCM foreground messages
  static Future<void> _handleIncomingRemoteMessage(RemoteMessage message) async {
    final shouldShow = await _shouldShowNotification(message.data);
    if (!shouldShow) return;

    final title = message.notification?.title ?? message.data['title']?.toString() ?? 'Absensi Digital';
    final body = message.notification?.body ?? message.data['body']?.toString() ?? 'Melakukan Check-in';

    debugPrint('[NotificationFCM] Incoming foreground FCM message: Title: $title, Body: $body');
  }

  /// Handle when standard FCM notification is clicked
  static void _handleRemoteMessageOpened(RemoteMessage message) {
    // No-op in Guru application
  }
}
