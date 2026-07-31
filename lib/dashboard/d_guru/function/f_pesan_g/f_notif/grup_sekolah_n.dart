import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apk/dashboard/d_guru/database/db_grup_kelas.dart';



/// Notification handler for Grup Sekolah chat.
///
/// Menggunakan dua mekanisme:
/// 1. **Supabase Realtime** — foreground notification utama (tidak bergantung FCM/Entrig).
///    Langsung listen INSERT pada tabel `grup_sekolah` dan tampilkan overlay.
/// 2. **Entrig callback** — fallback dari [NotificationFCM] jika event datang via FCM.
///
/// Must call [GrupSekolahNotification.init()] once after login.
/// Call [GrupSekolahNotification.dispose()] on logout.
class GrupSekolahNotification {
  // GlobalKey provided by the root MaterialApp (shared with NotificationFCM)
  static GlobalKey<NavigatorState>? navigatorKey;



  static String? _currentUserId;
  static String? _currentUserRole;
  static String? _currentAdminId; // untuk filter per-sekolah (user_id di grup_sekolah)

  // Supabase stream subscription (lebih reliable dari onPostgresChanges)
  static StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  static DateTime? _lastSeenAt; // untuk filter pesan baru saja

  static final ValueNotifier<bool> hasUnread = ValueNotifier<bool>(false);

  static Future<void> setUnread(bool value) async {
    hasUnread.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('grup_sekolah_has_unread', value);
      if (!value) {
        await prefs.setString('grup_sekolah_last_read', DateTime.now().toUtc().toIso8601String());
        _lastSeenAt = DateTime.now().toUtc();
      }
      if (!value) {
        await prefs.setString('grup_sekolah_last_read', DateTime.now().toUtc().toIso8601String());
        _lastSeenAt = DateTime.now().toUtc();
      }
    } catch (e) {
      debugPrint('[GrupSekolahNotification] setUnread error: $e');
    }
  }

  /// Initialize listener. Safe to call multiple times — will re-initialize.
  static Future<void> init({GlobalKey<NavigatorState>? key}) async {
    if (key != null) navigatorKey = key;

    dispose(); // bersihkan state sebelumnya

    try {
      final info = await DbGrupKelas.getCurrentUserRoleAndId();
      if (info == null) return;

      _currentUserId = info['id'];
      _currentUserRole = info['role'];

      // Ambil admin_id dari SharedPreferences untuk filter per-sekolah
      final prefs = await SharedPreferences.getInstance();
      _currentAdminId = prefs.getString('user_id_admin');

      // Load status unread
      hasUnread.value = prefs.getBool('grup_sekolah_has_unread') ?? false;



      // 2. Supabase Realtime (mekanisme utama foreground)
      _subscribeRealtime();

      debugPrint(
        '[GrupSekolahNotification] initialized '
        '(role: $_currentUserRole, adminId: $_currentAdminId)',
      );
    } catch (e) {
      debugPrint('[GrupSekolahNotification] init error: $e');
    }
  }

  // ─── Supabase Realtime ────────────────────────────────────────────────────

  static void _subscribeRealtime() async {
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    final lastReadStr = prefs.getString('grup_sekolah_last_read');
    _lastSeenAt = lastReadStr != null ? DateTime.parse(lastReadStr) : DateTime.now().toUtc();

    _streamSubscription = supabase
        .from('grup_sekolah')
        .stream(primaryKey: ['id_tabel'])
        .order('created_at', ascending: false)
        .listen(
          (rows) {
            // Filter: hanya pesan dari sekolah yang sama (client-side)
            final filtered = _currentAdminId != null
                ? rows.where((r) => r['user_id']?.toString() == _currentAdminId).toList()
                : rows;

            // Filter: hanya pesan baru (setelah waktu init / lastSeenAt)
            final newMsgs = filtered.where((row) {
              final t = DateTime.tryParse(row['created_at']?.toString() ?? '');
              return t != null && t.isAfter(_lastSeenAt!.subtract(const Duration(minutes: 5)));
            }).toList();

            if (newMsgs.isEmpty) return;

            // Update lastSeenAt ke pesan paling baru
            for (final row in newMsgs) {
              final t = DateTime.tryParse(row['created_at'].toString());
              if (t != null && t.isAfter(_lastSeenAt!)) _lastSeenAt = t;
            }

            debugPrint('[GrupSekolahNotification] stream → ${newMsgs.length} pesan baru');
            // Tampilkan notifikasi untuk pesan pertama (terbaru)
            _handleRealtimeInsert(newMsgs.first);
          },
          onError: (e) {
            debugPrint('[GrupSekolahNotification] stream error: $e');
          },
        );

    debugPrint('[GrupSekolahNotification] stream subscribed (lastSeenAt: $_lastSeenAt)');
  }

  /// Tangani INSERT baru dari Supabase Realtime.
  static void _handleRealtimeInsert(Map<String, dynamic> row) {
    // Skip jika pesan dari user ini sendiri
    final pengirimMurid = row['pengirim_murid']?.toString();
    final pengirimGuru = row['pengirim_guru']?.toString();
    final pengirimAdmin = row['pengirim_admin']?.toString();
    final senderId = pengirimMurid ?? pengirimGuru ?? pengirimAdmin;

    if (senderId != null && senderId == _currentUserId) {
      debugPrint('[GrupSekolahNotification] Skip own message');
      return;
    }

    final text = row['text']?.toString() ?? '';
    debugPrint('[GrupSekolahNotification] Realtime → pesan baru: "$text"');

    setUnread(true);
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  /// Bersihkan listener.
  static void dispose() {
    // Cancel stream subscription
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _lastSeenAt = null;
  }
}
