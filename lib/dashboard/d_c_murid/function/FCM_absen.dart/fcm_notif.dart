import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:apk/firebase_options.dart';
import 'package:apk/dashboard/d_c_murid/function/absen/absen_history.dart';
import 'package:apk/dashboard/a_admin/function/f_notif/notif_reddot.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM Background] Message received: id=${message.messageId}, data=${message.data}');
}

class NotificationFCM {
  // GlobalKey linked to MaterialApp navigatorKey
  static GlobalKey<NavigatorState> get navigatorKey => NotifRedDot.navigatorKey;

  static OverlayEntry? _overlayEntry;
  static final List<String> _accumulatedMessages = [];
  static Timer? _autoDismissTimer;

  /// Initialize listeners for FCM notification click events and foreground messages
  static Future<void> init() async {
    // 0. Ensure Firebase [DEFAULT] app is initialized
    try {
      bool hasDefault = false;
      for (var app in Firebase.apps) {
        if (app.name == '[DEFAULT]') {
          hasDefault = true;
          break;
        }
      }
      if (!hasDefault) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('[NotificationFCM] Firebase default app initialized');
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

    // 2. Set Background Message Handler
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Error setting background message handler: $e');
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

    // Supabase Realtime stream untuk output_alat hanya diaktifkan SETELAH login
    // via NotificationFCM.subscribeOutputAlatForCurrentUser(namaUser)
  }

  /// Fetch FCM Token and save to Supabase
  static Future<void> saveTokenToSupabase(String userId, String role) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint('[FCM] Failed to get device token');
        return;
      }
      debugPrint('[FCM] Device token fetched: $token');

      // Save token to Supabase fcm_tokens table
      await Supabase.instance.client.from('fcm_tokens').upsert(
        {
          'user_id': userId,
          'role': role,
          'token': token,
        },
        onConflict: 'user_id, token',
      );
      debugPrint('[FCM] Token saved to Supabase successfully for user $userId');
    } catch (e) {
      debugPrint('[FCM] Error saving token to Supabase: $e');
    }
  }

  static StreamSubscription<List<Map<String, dynamic>>>? _outputAlatSubscription;
  static final Set<String> _processedScanIds = {};

  /// Aktifkan stream output_alat untuk user yang sedang login.
  /// Hanya panggil setelah login berhasil dan nama user sudah diketahui.
  /// Filter dilakukan di level Supabase (.eq) sehingga hanya baris milik user ini
  /// yang dikirim ke perangkat — tidak ada kebocoran data ke user lain.
  static void subscribeOutputAlatForCurrentUser(String namaUser) {
    if (namaUser.isEmpty) {
      debugPrint('[SupabaseStream] subscribeOutputAlatForCurrentUser called with empty name, skipping.');
      return;
    }

    _outputAlatSubscription?.cancel();
    _processedScanIds.clear();
    final supabase = Supabase.instance.client;

    debugPrint('[SupabaseStream] Subscribing output_alat for user: $namaUser');

    try {
      _outputAlatSubscription = supabase
          .from('output_alat')
          .stream(primaryKey: ['id'])
          .eq('nama_user', namaUser)   // ← filter server-side: hanya baris milik user ini
          .order('created_at', ascending: false)
          .listen(
            (rows) {
              if (rows.isEmpty) return;

              // Pada muat pertama, simpan semua ID lama agar tidak memicu notifikasi lama
              if (_processedScanIds.isEmpty) {
                for (final row in rows) {
                  final id = row['id']?.toString();
                  if (id != null) _processedScanIds.add(id);
                }
                debugPrint('[SupabaseStream] First load: cached ${_processedScanIds.length} existing scans');
                return;
              }

              // Deteksi baris yang benar-benar baru di-insert
              for (final row in rows) {
                final id = row['id']?.toString();
                if (id != null && !_processedScanIds.contains(id)) {
                  _processedScanIds.add(id);

                  final rowNama = row['nama_user']?.toString() ?? '';
                  debugPrint('[SupabaseStream] New scan received for $rowNama (id: $id)');

                  final title = 'Aplikasi Absensi';
                  final body = rowNama.isNotEmpty
                      ? '$rowNama telah melakukan absensi'
                      : 'Absensi berhasil';

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _showEntrigOverlay(title: title, body: body);
                  });
                }
              }
            },
            onError: (e) {
              debugPrint('[SupabaseStream] output_alat error: $e');
            },
          );
      debugPrint('[SupabaseStream] Subscribed to output_alat for "$namaUser"');
    } catch (e) {
      debugPrint('[SupabaseStream] Error subscribing to output_alat: $e');
    }
  }

  /// Hentikan stream output_alat (panggil saat logout)
  static void unsubscribeOutputAlat() {
    _outputAlatSubscription?.cancel();
    _outputAlatSubscription = null;
    _processedScanIds.clear();
    debugPrint('[SupabaseStream] Unsubscribed from output_alat');
  }

  /// Tampilkan overlay di atas app dengan judul dan isi notifikasi Entrig
  static void _showEntrigOverlay({required String title, required String body}) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('[Overlay] navigatorKey.currentContext is null!');
      return;
    }

    _autoDismissTimer?.cancel();
    if (_overlayEntry != null) {
      try {
        if (_overlayEntry!.mounted) {
          _overlayEntry!.remove();
        }
      } catch (e) {
        debugPrint('[Overlay] Remove previous entry error: $e');
      } finally {
        _overlayEntry = null;
      }
    }

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 8,
        left: 12,
        right: 12,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_active,
                      color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _dismissOverlay,
                  child: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final overlay = Overlay.of(context, rootOverlay: true);
      overlay.insert(_overlayEntry!);
      debugPrint('[Overlay] Entrig overlay shown successfully: $body');
    } catch (e) {
      debugPrint('[Overlay] Insert error: $e');
    }

    _autoDismissTimer = Timer(const Duration(seconds: 5), _dismissOverlay);
  }

  // ─── Filter Logic ───────────────────────────────────────────────────────────

  /// Check if the notification's data payload matches the logged-in student
  static Future<bool> _shouldShowNotification(Map? data) async {
    if (data == null || data.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role');

    final idMurid = _extractIdMurid(data);
    final namaUser = _extractNamaUser(data);

    if (role == 'admin') {
      return false; // Admin tidak melihat notifikasi hardware secara individu
    }

    if (role == 'guru') {
      final loggedInName = prefs.getString('guru_nama');
      if (loggedInName != null && namaUser != null && namaUser.isNotEmpty) {
        return loggedInName.trim().toLowerCase() == namaUser.trim().toLowerCase();
      }
      return false;
    }

    // 1. Cek berdasarkan id_murid (UUID) - 100% akurat
    if (idMurid != null && idMurid.isNotEmpty) {
      final loggedInId = prefs.getString('murid_id_tabel');
      if (loggedInId != null && loggedInId.isNotEmpty) {
        final matches = loggedInId.trim().toLowerCase() == idMurid.trim().toLowerCase();
        debugPrint('[NotificationFCM] Filter by ID - Logged in: "$loggedInId", Incoming: "$idMurid". Match: $matches');
        return matches;
      }
    }

    // 2. Fallback: Cek berdasarkan nama_user (String)
    if (namaUser != null && namaUser.isNotEmpty) {
      final matches = await _shouldShowNotificationByNama(namaUser);
      debugPrint('[NotificationFCM] Filter by Name - Incoming: "$namaUser". Match: $matches');
      return matches;
    }

    return false;
  }

  /// Ekstrak id_murid secara dinamis dari map data
  static String? _extractIdMurid(Map data) {
    if (data.containsKey('id_murid')) {
      final val = data['id_murid'];
      if (val is Map) {
        return val['id_tabel']?.toString() ?? val['id']?.toString();
      }
      return val?.toString();
    }
    for (var key in data.keys) {
      final k = key.toString().toLowerCase();
      if (k == 'id_murid' || k == 'murid_id' || k == 'id_tabel') {
        final val = data[key];
        if (val is Map) {
          return val['id_tabel']?.toString() ?? val['id']?.toString();
        }
        return val?.toString();
      }
    }
    return null;
  }

  /// Filter berdasarkan nama string langsung
  static Future<bool> _shouldShowNotificationByNama(String namaUser) async {
    if (namaUser.isEmpty) return false;

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

    return false;
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
      final k = key.toString().toLowerCase();
      if (k == 'nama_user' || k == 'nama' || k == 'user_name') {
        final val = data[key];
        if (val is Map) {
          return val['name']?.toString() ?? val['nama']?.toString();
        }
        return val?.toString();
      }
    }
    return null;
  }

  static Future<void> _handleIncomingRemoteMessage(RemoteMessage message) async {
    debugPrint('[FCM] Foreground message received: notification=${message.notification?.title}/${message.notification?.body}, data=${message.data}');

    if (!await _shouldShowNotification(message.data)) {
      debugPrint('[FCM] Foreground message ignored (not for logged in user)');
      return;
    }

    final dataNamaUser = _extractNamaUser(message.data);
    final notificationBody = message.notification?.body ?? message.data['body']?.toString() ?? message.data['text']?.toString() ?? '';
    final notificationTitle = message.notification?.title ?? message.data['title']?.toString() ?? 'Aplikasi Absensi';

    final prefs = await SharedPreferences.getInstance();
    final loggedInNama = prefs.getString('murid_nama') ?? '';

    String body = 'Siswa telah melakukan absensi';

    if (dataNamaUser != null && dataNamaUser.isNotEmpty && dataNamaUser != '...') {
      body = '$dataNamaUser telah melakukan absensi';
    } else if (notificationBody.isNotEmpty) {
      body = notificationBody;
    } else if (loggedInNama.isNotEmpty) {
      body = '$loggedInNama telah melakukan absensi';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showEntrigOverlay(title: notificationTitle, body: body);
    });
  }

  static Future<void> _handleRemoteMessageOpened(RemoteMessage message) async {
    debugPrint('[FCM] Notification opened by user: data=${message.data}');

    if (!await _shouldShowNotification(message.data)) {
      debugPrint('[FCM] Opened notification ignored (not for logged in user)');
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null) return;

    final prefs = await SharedPreferences.getInstance();
    final nis = prefs.getString('murid_nis') ?? '';

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AbsenHistory(nis: nis)),
      );
    }
  }

  static void _dismissOverlay() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    if (_overlayEntry != null) {
      try {
        if (_overlayEntry!.mounted) {
          _overlayEntry!.remove();
        }
      } catch (e) {
        debugPrint('[Overlay] Dismiss error: $e');
      } finally {
        _overlayEntry = null;
      }
    }
    _accumulatedMessages.clear();
  }
}

