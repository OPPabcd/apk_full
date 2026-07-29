import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apk/dashboard/d_c_murid/database/db_grup_kelas.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/fcm_notif.dart';
import 'package:apk/dashboard/d_c_murid/function/f_Pesan/grup_kelas.dart';

/// Notification handler for Grup Kelas chat.
/// Must call [GrupKelasNotification.init()] once after login.
/// Call [GrupKelasNotification.dispose()] on logout.
class GrupKelasNotification {
  // GlobalKey provided by the root MaterialApp (shared with NotificationFCM)
  static GlobalKey<NavigatorState>? navigatorKey;

  static OverlayEntry? _overlayEntry;
  static Timer? _autoDismissTimer;

  static String? _currentUserId;
  static String? _currentUserRole;
  static String? _currentClassId;

  // Supabase stream subscription
  static StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  static DateTime? _lastSeenAt;

  static final ValueNotifier<bool> hasUnread = ValueNotifier<bool>(false);

  static Future<void> setUnread(bool value) async {
    hasUnread.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('grup_kelas_has_unread', value);
      if (!value) {
        await prefs.setString('grup_kelas_last_read', DateTime.now().toUtc().toIso8601String());
        _lastSeenAt = DateTime.now().toUtc();
      }
      if (!value) {
        await prefs.setString('grup_kelas_last_read', DateTime.now().toUtc().toIso8601String());
        _lastSeenAt = DateTime.now().toUtc();
      }
    } catch (e) {
      debugPrint('[GrupKelasNotification] setUnread error: $e');
    }
  }

  /// Initialize the listener. Safe to call multiple times — will re-initialize.
  static Future<void> init({GlobalKey<NavigatorState>? key}) async {
    if (key != null) navigatorKey = key;

    await dispose(); // bersihkan state sebelumnya

    try {
      final info = await DbGrupKelas.getCurrentUserRoleAndId();
      if (info == null) return;

      _currentUserId = info['id'];
      _currentUserRole = info['role'];
      _currentClassId = info['id_class'];

      if (_currentClassId == null || _currentClassId!.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      hasUnread.value = prefs.getBool('grup_kelas_has_unread') ?? false;



      _subscribeRealtime();

      debugPrint('[GrupKelasNotification] initialized (role: $_currentUserRole, class: $_currentClassId)');
    } catch (e) {
      debugPrint('[GrupKelasNotification] init error: $e');
    }
  }

  // ─── Supabase Realtime ────────────────────────────────────────────────────

  static void _subscribeRealtime() {
    final supabase = Supabase.instance.client;
    _lastSeenAt = DateTime.now().toUtc();

    _streamSubscription = supabase
        .from('grup_kelas')
        .stream(primaryKey: ['id_tabel'])
        .order('created_at', ascending: false)
        .listen(
          (rows) {
            // Filter: only messages for the same class_id
            final filtered = _currentClassId != null
                ? rows.where((r) => r['id_class']?.toString() == _currentClassId).toList()
                : rows;

            // Filter: only new messages (after init / lastSeenAt)
            final newMsgs = filtered.where((row) {
              final t = DateTime.tryParse(row['created_at']?.toString() ?? '');
              return t != null && t.isAfter(_lastSeenAt!.subtract(const Duration(minutes: 5)));
            }).toList();

            if (newMsgs.isEmpty) return;

            // Update lastSeenAt
            for (final row in newMsgs) {
              final t = DateTime.tryParse(row['created_at'].toString());
              if (t != null && t.isAfter(_lastSeenAt!)) _lastSeenAt = t;
            }

            debugPrint('[GrupKelasNotification] stream → ${newMsgs.length} pesan baru');
            _handleRealtimeInsert(newMsgs.first);
          },
          onError: (e) {
            debugPrint('[GrupKelasNotification] stream error: $e');
          },
        );
  }

  static void _handleRealtimeInsert(Map<String, dynamic> row) {
    // Skip if sent by ourselves
    final pengirimMurid = row['pengirim_murid']?.toString();
    final pengirimGuru = row['pengirim_guru']?.toString();
    final pengirimAdmin = row['pengirim_admin']?.toString();
    final senderId = pengirimMurid ?? pengirimGuru ?? pengirimAdmin;

    if (senderId != null && senderId == _currentUserId) {
      return;
    }

    final text = row['text']?.toString() ?? '';
    debugPrint('[GrupKelasNotification] Realtime → pesan baru: "$text"');

    setUnread(true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOverlayCard(text: text);
    });
  }

  static Future<void> dispose() async {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _lastSeenAt = null;
    _dismissOverlay();
  }

  // ─── Overlay UI ───────────────────────────────────────────────────────────

  static void _showOverlayCard({required String text}) {
    // Disabled overlay popups as requested, keeping only red dot/badge updates
    return;
  }

  static void _dismissOverlay() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }
}
