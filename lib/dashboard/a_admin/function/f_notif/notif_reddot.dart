import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apk/dashboard/a_admin/database/db_grup_sekolah.dart';
import 'package:apk/dashboard/a_admin/database/db_pesan_private.dart';

class NotifRedDot {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Notifiers untuk indikator titik merah (red dot)
  static final ValueNotifier<bool> grupSekolahHasUnread = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> chatPrivateHasUnread = ValueNotifier<bool>(false);
  static final ValueNotifier<Set<String>> chatPrivateUnreadSenderIds = ValueNotifier<Set<String>>({});

  static String? _currentUserId;
  static String? _currentAdminId;

  static StreamSubscription<List<Map<String, dynamic>>>? _grupSekolahSubscription;
  static StreamSubscription<List<Map<String, dynamic>>>? _chatPrivateSubscription;

  static DateTime? _grupSekolahLastSeenAt;
  static DateTime? _chatPrivateLastSeenAt;

  /// Inisialisasi listener realtime Supabase untuk titik merah (Grup Sekolah & Chat Private)
  static Future<void> init({GlobalKey<NavigatorState>? key}) async {
    await dispose();

    // Load saved unread state
    try {
      final prefs = await SharedPreferences.getInstance();
      grupSekolahHasUnread.value = prefs.getBool('grup_sekolah_has_unread') ?? false;

      final unreadList = prefs.getStringList('chat_private_unread_senders') ?? [];
      chatPrivateUnreadSenderIds.value = unreadList.toSet();
      chatPrivateHasUnread.value = chatPrivateUnreadSenderIds.value.isNotEmpty || (prefs.getBool('chat_private_has_unread') ?? false);
    } catch (e) {
      debugPrint('[NotifRedDot] load state error: $e');
    }

    // Init Grup Sekolah Realtime
    try {
      final info = await DbGrupSekolah.getCurrentUserRoleAndId();
      if (info != null) {
        _currentUserId = info['id'];
      }
      _subscribeGrupSekolahRealtime();
    } catch (e) {
      debugPrint('[NotifRedDot] GrupSekolah init error: $e');
    }

    // Init Chat Private Realtime
    try {
      final dbPesan = DbPesanPrivate();
      _currentAdminId = await dbPesan.getAdminId();
      if (_currentAdminId != null) {
        _subscribeChatPrivateRealtime();
      }
    } catch (e) {
      debugPrint('[NotifRedDot] ChatPrivate init error: $e');
    }
  }

  // Setters state titik merah
  static Future<void> setGrupSekolahUnread(bool value) async {
    grupSekolahHasUnread.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('grup_sekolah_has_unread', value);
      if (!value) {
        await prefs.setString('grup_sekolah_last_read', DateTime.now().toUtc().toIso8601String());
        _grupSekolahLastSeenAt = DateTime.now().toUtc();
      }
      if (!value) {
        await prefs.setString('grup_sekolah_last_read', DateTime.now().toUtc().toIso8601String());
        _grupSekolahLastSeenAt = DateTime.now().toUtc();
      }
    } catch (e) {
      debugPrint('[NotifRedDot] setGrupSekolahUnread error: $e');
    }
  }

  static Future<void> setChatPrivateSenderUnread(String senderId, bool isUnread) async {
    final current = Set<String>.from(chatPrivateUnreadSenderIds.value);
    if (isUnread) {
      current.add(senderId);
    } else {
      current.remove(senderId);
    }
    chatPrivateUnreadSenderIds.value = current;
    chatPrivateHasUnread.value = current.isNotEmpty;

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
      debugPrint('[NotifRedDot] setChatPrivateSenderUnread error: $e');
    }
  }

  static Future<void> setChatPrivateUnread(bool value) async {
    if (!value) {
      chatPrivateUnreadSenderIds.value = {};
      chatPrivateHasUnread.value = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('chat_private_unread_senders');
        await prefs.setBool('chat_private_has_unread', false);
      } catch (e) {
        debugPrint('[NotifRedDot] setChatPrivateUnread error: $e');
      }
    } else {
      chatPrivateHasUnread.value = true;
    }
  }

  static void _subscribeGrupSekolahRealtime() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _subscribeGrupSekolahRealtimeInternal();
  }

  static void _subscribeGrupSekolahRealtimeInternal() async {
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final lastReadStr = prefs.getString('grup_sekolah_last_read');
    _grupSekolahLastSeenAt = lastReadStr != null ? DateTime.parse(lastReadStr) : DateTime.now().toUtc();

    _grupSekolahSubscription = supabase
        .from('grup_sekolah')
        .stream(primaryKey: ['id_tabel'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .listen(
          (rows) {
            final newMsgs = rows.where((row) {
              final t = DateTime.tryParse(row['created_at']?.toString() ?? '');
              return t != null && t.isAfter(_grupSekolahLastSeenAt!.subtract(const Duration(minutes: 5)));
            }).toList();

            for (final row in rows) {
              final pengirimGuru = row['pengirim_guru']?.toString();
              final pengirimMurid = row['pengirim_murid']?.toString();
              final senderId = pengirimGuru ?? pengirimMurid;
              
              if (senderId != null && senderId != _currentAdminId) {
                final lastReadStr = prefs.getString('chat_private_last_read_$senderId');
                final lastRead = lastReadStr != null ? DateTime.parse(lastReadStr) : DateTime.fromMillisecondsSinceEpoch(0);
                final t = DateTime.tryParse(row['created_at']?.toString() ?? '');
                
                if (t != null && t.isAfter(lastRead) && !chatPrivateUnreadSenderIds.value.contains(senderId)) {
                  setChatPrivateSenderUnread(senderId, true);
                }
              }
            }


            if (newMsgs.isEmpty) return;

            for (final row in newMsgs) {
              final t = DateTime.tryParse(row['created_at'].toString());
              if (t != null && t.isAfter(_grupSekolahLastSeenAt!)) _grupSekolahLastSeenAt = t;
            }

            final lastRow = newMsgs.first;
            final pengirimAdmin = lastRow['pengirim_admin']?.toString();
            final pengirimGuru = lastRow['pengirim_guru']?.toString();
            final pengirimMurid = lastRow['pengirim_murid']?.toString();
            final senderId = pengirimAdmin ?? pengirimGuru ?? pengirimMurid;

            if (senderId != null && senderId == _currentUserId) {
              return;
            }

            setGrupSekolahUnread(true);
          },
          onError: (e) {
            debugPrint('[NotifRedDot] GrupSekolah stream error: $e');
          },
        );
  }

  static void _subscribeChatPrivateRealtime() {
    final supabase = Supabase.instance.client;
    _chatPrivateLastSeenAt = DateTime.now().toUtc();

    _chatPrivateSubscription = supabase
        .from('chat_private')
        .stream(primaryKey: ['id_tabel'])
        .order('created_at', ascending: false)
        .listen(
          (rows) {
            final filtered = rows.where((row) {
              return row['penerima_admin']?.toString() == _currentAdminId;
            }).toList();

            final newMsgs = filtered.where((row) {
              final t = DateTime.tryParse(row['created_at']?.toString() ?? '');
              return t != null && t.isAfter(_chatPrivateLastSeenAt!);
            }).toList();

            if (newMsgs.isEmpty) return;

            for (final row in newMsgs) {
              final t = DateTime.tryParse(row['created_at'].toString());
              if (t != null && t.isAfter(_chatPrivateLastSeenAt!)) _chatPrivateLastSeenAt = t;
            }

            final lastRow = newMsgs.first;
            final senderGuru = lastRow['pengirim_guru']?.toString();
            final senderMurid = lastRow['pengirim_murid']?.toString();
            final senderId = senderGuru ?? senderMurid;

            if (senderId != null) {
              setChatPrivateSenderUnread(senderId, true);
            }
          },
          onError: (e) {
            debugPrint('[NotifRedDot] ChatPrivate stream error: $e');
          },
        );
  }

  static Future<void> dispose() async {
    _grupSekolahSubscription?.cancel();
    _grupSekolahSubscription = null;
    _chatPrivateSubscription?.cancel();
    _chatPrivateSubscription = null;
    _grupSekolahLastSeenAt = null;
    _chatPrivateLastSeenAt = null;
  }
}

/// Backward-compatibility wrappers for NotificationFCM & ChatPrivateNotification
class NotificationFCM {
  static GlobalKey<NavigatorState> get navigatorKey => NotifRedDot.navigatorKey;
  static ValueNotifier<bool> get hasUnread => NotifRedDot.grupSekolahHasUnread;
  static Future<void> setUnread(bool value) => NotifRedDot.setGrupSekolahUnread(value);
  static Future<void> init() => NotifRedDot.init();
  static Future<void> dispose() => NotifRedDot.dispose();
}

class ChatPrivateNotification {
  static ValueNotifier<bool> get hasUnread => NotifRedDot.chatPrivateHasUnread;
  static ValueNotifier<Set<String>> get unreadSenderIds => NotifRedDot.chatPrivateUnreadSenderIds;
  static Future<void> setSenderUnread(String senderId, bool isUnread) => NotifRedDot.setChatPrivateSenderUnread(senderId, isUnread);
  static Future<void> setUnread(bool value) => NotifRedDot.setChatPrivateUnread(value);
  static Future<void> init({GlobalKey<NavigatorState>? key}) => NotifRedDot.init(key: key);
  static Future<void> dispose() => NotifRedDot.dispose();
}