import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apk/dashboard/d_guru/database/db_guru.dart';


/// Notification handler for Chat Private (Guru ↔ Ortu/Murid).
/// Must call [ChatPrivateNotification.init()] once after login.
/// Call [ChatPrivateNotification.dispose()] on logout.
class ChatPrivateNotification {
  // GlobalKey provided by the root MaterialApp (shared with other notification handlers)
  static GlobalKey<NavigatorState>? navigatorKey;

  static String? _currentUserId;   // ID di tabel murid/guru (bukan auth.uid)
  static String? _currentUserRole; // 'ortu', 'murid', or 'guru'

  // Supabase stream subscription
  static StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  static DateTime? _lastSeenAt;

  static final ValueNotifier<bool> hasUnread = ValueNotifier<bool>(false);
  static final ValueNotifier<Set<String>> unreadSenderIds = ValueNotifier<Set<String>>({});

  static Future<void> setSenderUnread(String senderId, bool isUnread) async {
    final current = Set<String>.from(unreadSenderIds.value);
    if (isUnread) {
      current.add(senderId);
    } else {
      current.remove(senderId);
    }
    unreadSenderIds.value = current;
    hasUnread.value = current.isNotEmpty;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('chat_private_unread_senders', current.toList());
      await prefs.setBool('chat_private_has_unread', current.isNotEmpty);
      if (!isUnread) {
        await prefs.setString('chat_private_last_read_$senderId', DateTime.now().toUtc().toIso8601String());
      }
      if (!isUnread) {
        await prefs.setString('chat_private_last_read_$senderId', DateTime.now().toUtc().toIso8601String());
      }
    } catch (e) {
      debugPrint('[ChatPrivateNotification] setSenderUnread error: $e');
    }
  }

  static Future<void> setUnread(bool value) async {
    if (!value) {
      unreadSenderIds.value = {};
      hasUnread.value = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('chat_private_unread_senders');
        await prefs.setBool('chat_private_has_unread', false);
      } catch (e) {
        debugPrint('[ChatPrivateNotification] setUnread error: $e');
      }
    } else {
      hasUnread.value = true;
    }
  }

  /// Initialize the listener. Safe to call multiple times — will re-initialize.
  static Future<void> init({GlobalKey<NavigatorState>? key}) async {
    if (key != null) navigatorKey = key;

    await dispose(); // bersihkan state sebelumnya

    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role') ?? '';

      if (role == 'ortu' || role == 'murid') {
        await _initForMurid(prefs);
      } else if (role == 'guru') {
        await _initForGuru();
      }

      if (_currentUserId != null) {
        final unreadList = prefs.getStringList('chat_private_unread_senders') ?? [];
        unreadSenderIds.value = unreadList.toSet();
        hasUnread.value = unreadSenderIds.value.isNotEmpty || (prefs.getBool('chat_private_has_unread') ?? false);


        _subscribeRealtime();
        debugPrint('[ChatPrivateNotification] initialized (role: $_currentUserRole, id: $_currentUserId, unread: ${unreadSenderIds.value})');
      }
      // Admin tidak perlu notif chat private di sini
    } catch (e) {
      debugPrint('[ChatPrivateNotification] init error: $e');
    }
  }

  // ─── Init untuk Ortu/Murid ────────────────────────────────────────────────

  static Future<void> _initForMurid(SharedPreferences prefs) async {
    final nis = prefs.getString('murid_nis');
    final adminId = prefs.getString('user_id_admin');
    if (nis == null || adminId == null) return;

    final muridRes = await Supabase.instance.client
        .from('murid')
        .select('id_tabel')
        .eq('user_id', adminId)
        .eq('nis', nis)
        .or('status_akun.is.null,status_akun.eq.true')
        .maybeSingle();

    if (muridRes == null) return;

    _currentUserId = muridRes['id_tabel'].toString();
    _currentUserRole = 'murid';
  }

  // ─── Init untuk Guru ──────────────────────────────────────────────────────

  static Future<void> _initForGuru() async {
    final guruInfo = await DbGuru().getLoggedInGuruInfo();
    _currentUserId = guruInfo['id_tabel']?.toString();
    _currentUserRole = 'guru';
  }

  // ─── Tangani Entrig event yang diteruskan dari fcm_notif.dart ──────────────

  // ─── Supabase Realtime ────────────────────────────────────────────────────

  static void _subscribeRealtime() async {
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    _lastSeenAt = DateTime.now().toUtc();

    _streamSubscription = supabase
        .from('chat_private')
        .stream(primaryKey: ['id_tabel'])
        .order('created_at', ascending: false)
        .listen(
          (rows) {
            // Filter: only messages where recipient matches our id
            final filtered = rows.where((row) {
              final recipientId = _currentUserRole == 'guru'
                  ? row['penerima_guru']?.toString()
                  : row['penerima_murid']?.toString();
              return recipientId == _currentUserId;
            }).toList();

            // Filter: only new messages (after init / lastSeenAt)
            final newMsgs = filtered.where((row) {
              final t = DateTime.tryParse(row['created_at']?.toString() ?? '');
              return t != null && t.isAfter(_lastSeenAt!);
            }).toList();

            for (final row in filtered) {
                 final senderId = row['pengirim_murid']?.toString() ?? row['pengirim_guru']?.toString() ?? row['pengirim_admin']?.toString();
                 if (senderId != null && senderId != _currentUserId) {
                     final lastReadStr = prefs.getString('chat_private_last_read_$senderId');
                     final lastRead = lastReadStr != null ? DateTime.parse(lastReadStr) : DateTime.fromMillisecondsSinceEpoch(0);
                     final t = DateTime.tryParse(row['created_at']?.toString() ?? '');
                     if (t != null && t.isAfter(lastRead) && !unreadSenderIds.value.contains(senderId)) {
                         setSenderUnread(senderId, true);
                     }
                 }
            }

            for (final row in filtered) {
                 final senderId = row['pengirim_murid']?.toString() ?? row['pengirim_guru']?.toString() ?? row['pengirim_admin']?.toString();
                 if (senderId != null && senderId != _currentUserId) {
                     final lastReadStr = prefs.getString('chat_private_last_read_$senderId');
                     final lastRead = lastReadStr != null ? DateTime.parse(lastReadStr) : DateTime.fromMillisecondsSinceEpoch(0);
                     final t = DateTime.tryParse(row['created_at']?.toString() ?? '');
                     if (t != null && t.isAfter(lastRead) && !unreadSenderIds.value.contains(senderId)) {
                         setSenderUnread(senderId, true);
                     }
                 }
            }

            if (newMsgs.isEmpty) return;

            // Update lastSeenAt
            for (final row in newMsgs) {
              final t = DateTime.tryParse(row['created_at'].toString());
              if (t != null && t.isAfter(_lastSeenAt!)) _lastSeenAt = t;
            }

            debugPrint('[ChatPrivateNotification] stream → ${newMsgs.length} pesan baru');
            _handleRealtimeInsert(newMsgs.first);
          },
          onError: (e) {
            debugPrint('[ChatPrivateNotification] stream error: $e');
          },
        );
  }

  static void _handleRealtimeInsert(Map<String, dynamic> row) {
    // Skip if sent by ourselves
    final senderMurid = row['pengirim_murid']?.toString();
    final senderGuru = row['pengirim_guru']?.toString();
    final senderAdmin = row['pengirim_admin']?.toString();
    final senderId = senderMurid ?? senderGuru ?? senderAdmin;

    if (senderId != null && senderId == _currentUserId) {
      return;
    }

    if (senderId != null) {
      setSenderUnread(senderId, true);
    }
  }

  // ─── Dispose ──────────────────────────────────────────────────────────────

  static Future<void> dispose() async {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _lastSeenAt = null;
  }
}
