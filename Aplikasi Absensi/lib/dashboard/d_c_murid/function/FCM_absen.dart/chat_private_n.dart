import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apk/dashboard/d_c_murid/database/db_guru.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/fcm_notif.dart';
import 'package:apk/dashboard/d_c_murid/function/f_Pesan/chat_private.dart';

/// Notification handler for Chat Private (Guru ↔ Ortu/Murid).
/// Must call [ChatPrivateNotification.init()] once after login.
/// Call [ChatPrivateNotification.dispose()] on logout.
class ChatPrivateNotification {
  // GlobalKey provided by the root MaterialApp (shared with other notification handlers)
  static GlobalKey<NavigatorState>? navigatorKey;

  static OverlayEntry? _overlayEntry;
  static Timer? _autoDismissTimer;

  static String? _currentUserId;   // ID di tabel murid/guru (bukan auth.uid)
  static String? _currentUserRole; // 'ortu', 'murid', or 'guru'

  // Info pengirim terakhir agar navigasi buka chat yang benar
  static String? _lastSenderId;
  static String? _lastSenderName;
  static String? _lastSenderType; // 'guru', 'murid', or 'admin'

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

    final text = row['text']?.toString() ?? '';

    if (senderId != null) {
      setSenderUnread(senderId, true);
    }

    if (senderMurid != null) {
      _fetchMuridNameAndNotify(
        senderId: senderMurid,
        senderType: 'murid',
        text: text,
      );
    } else if (senderGuru != null) {
      _fetchGuruNameAndNotify(
        senderId: senderGuru,
        senderType: 'guru',
        text: text,
      );
    } else if (senderAdmin != null) {
      _fetchAdminNameAndNotify(
        senderId: senderAdmin,
        senderType: 'admin',
        text: text,
      );
    }
  }



  // ─── Helper: Fetch nama lalu tampilkan overlay ────────────────────────────

  static Future<void> _fetchGuruNameAndNotify({
    required String senderId,
    required String senderType,
    required String text,
  }) async {
    try {
      final res = await Supabase.instance.client
          .from('guru')
          .select('name')
          .eq('id_tabel', senderId)
          .maybeSingle();
      _lastSenderId = senderId;
      _lastSenderType = senderType;
      _lastSenderName = res?['name']?.toString() ?? 'Guru';
      _showOverlayCard(senderName: _lastSenderName!, text: text);
    } catch (_) {
      _lastSenderId = senderId;
      _lastSenderType = senderType;
      _lastSenderName = 'Guru';
      _showOverlayCard(senderName: 'Guru', text: text);
    }
  }

  static Future<void> _fetchMuridNameAndNotify({
    required String senderId,
    required String senderType,
    required String text,
  }) async {
    try {
      final res = await Supabase.instance.client
          .from('murid')
          .select('nama')
          .eq('id_tabel', senderId)
          .maybeSingle();
      _lastSenderId = senderId;
      _lastSenderType = senderType;
      _lastSenderName = res?['nama']?.toString() ?? 'Murid';
      _showOverlayCard(senderName: _lastSenderName!, text: text);
    } catch (_) {
      _lastSenderId = senderId;
      _lastSenderType = senderType;
      _lastSenderName = 'Murid';
      _showOverlayCard(senderName: 'Murid', text: text);
    }
  }

  static Future<void> _fetchAdminNameAndNotify({
    required String senderId,
    required String senderType,
    required String text,
  }) async {
    try {
      final res = await Supabase.instance.client
          .from('user_admin')
          .select('name')
          .eq('id', senderId)
          .maybeSingle();
      _lastSenderId = senderId;
      _lastSenderType = senderType;
      _lastSenderName = res?['name']?.toString() ?? 'Admin';
      _showOverlayCard(senderName: _lastSenderName!, text: text);
    } catch (_) {
      _lastSenderId = senderId;
      _lastSenderType = senderType;
      _lastSenderName = 'Admin';
      _showOverlayCard(senderName: 'Admin', text: text);
    }
  }

  // ─── Dispose ──────────────────────────────────────────────────────────────

  static Future<void> dispose() async {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _lastSeenAt = null;
    _dismissOverlay();
  }

  // ─── Overlay UI ───────────────────────────────────────────────────────────

  static void _showOverlayCard({
    required String senderName,
    required String text,
  }) {
    // Disabled overlay popups as requested, keeping only red dot/badge updates
    return;
  }

  static void _navigateToChatPrivate() {
    final senderId = _lastSenderId;
    final senderName = _lastSenderName ?? '';
    final senderType = _lastSenderType ?? '';
    if (senderId == null) return;

    // Murid/Ortu membuka ChatPrivate menuju guru pengirim
    navigatorKey?.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ChatPrivate(
          receiverId: senderId,
          receiverType: senderType,
          receiverName: senderName,
        ),
      ),
    );
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
