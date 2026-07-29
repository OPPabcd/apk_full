import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DbPesanPrivate {
  static final supabase = Supabase.instance.client;

  static Future<String> getUserIdAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final ortuId = prefs.getString('user_id_admin');
    if (ortuId != null) return ortuId;

    final id = supabase.auth.currentUser?.id;
    if (id != null) return id;

    throw Exception('User belum login');
  }

  // Get Admin ID (for the current logged in user)
  Future<String?> getAdminId() async {
    try {
      final userId = await getUserIdAsync();
      final res = await supabase
          .from('user_admin')
          .select('id')
          .eq('id', userId) 
          .single();
      return res['id']?.toString();
    } catch (e) {
      if (kDebugMode) print('Get Admin ID Error: $e');
      return null;
    }
  }

  // Stream chat between Admin and Guru
  Stream<List<Map<String, dynamic>>> getChatWithGuruStream(String idAdmin, String idGuru) {
    deleteExpiredMessages();
    return supabase
        .from('chat_private')
        .stream(primaryKey: ['id_tabel'])
        .order('created_at', ascending: true)
        .map((data) => data
            .where((e) => 
                (e['pengirim_admin'] == idAdmin && e['penerima_guru'] == idGuru) ||
                (e['pengirim_guru'] == idGuru && e['penerima_admin'] == idAdmin))
            .map((e) => e as Map<String, dynamic>)
            .toList());
  }

  // Stream chat between Admin and Murid
  Stream<List<Map<String, dynamic>>> getChatWithMuridStream(String idAdmin, String idMurid) {
    deleteExpiredMessages();
    return supabase
        .from('chat_private')
        .stream(primaryKey: ['id_tabel'])
        .order('created_at', ascending: true)
        .map((data) => data
            .where((e) => 
                (e['pengirim_admin'] == idAdmin && e['penerima_murid'] == idMurid) ||
                (e['pengirim_murid'] == idMurid && e['penerima_admin'] == idAdmin))
            .map((e) => e as Map<String, dynamic>)
            .toList());
  }

  // Send Message to Guru
  Future<void> sendMessageToGuru({
    required String text,
    required String idAdmin,
    required String idGuru,
  }) async {
    try {
      await deleteExpiredMessages();
      final userId = await getUserIdAsync();
      await supabase.from('chat_private').insert({
        'text': text,
        'pengirim_admin': idAdmin,
        'penerima_guru': idGuru,
        'user_id': userId,
      });
    } catch (e) {
      if (kDebugMode) print('Send Message Error: $e');
      throw Exception('Gagal mengirim pesan: $e');
    }
  }

  // Send Message to Murid
  Future<void> sendMessageToMurid({
    required String text,
    required String idAdmin,
    required String idMurid,
  }) async {
    try {
      await deleteExpiredMessages();
      final userId = await getUserIdAsync();
      await supabase.from('chat_private').insert({
        'text': text,
        'pengirim_admin': idAdmin,
        'penerima_murid': idMurid,
        'user_id': userId,
      });
    } catch (e) {
      if (kDebugMode) print('Send Message Error: $e');
      throw Exception('Gagal mengirim pesan: $e');
    }
  }

  // Stream chat between Admin and Murid (For Murid App)
  Stream<List<Map<String, dynamic>>> getChatWithAdminStream(String idMurid, String idAdmin) {
    deleteExpiredMessages();
    return supabase
        .from('chat_private')
        .stream(primaryKey: ['id_tabel'])
        .order('created_at', ascending: true)
        .map((data) => data
            .where((e) => 
                (e['pengirim_admin'] == idAdmin && e['penerima_murid'] == idMurid) ||
                (e['pengirim_murid'] == idMurid && e['penerima_admin'] == idAdmin))
            .map((e) => e as Map<String, dynamic>)
            .toList());
  }

  // Send message general (For Murid App sending to admin)
  Future<void> sendMessage(Map<String, dynamic> data) async {
    try {
      await deleteExpiredMessages();
      await supabase.from('chat_private').insert(data);
    } catch (e) {
      if (kDebugMode) print('Send Message Error: $e');
      throw Exception('Gagal mengirim pesan: $e');
    }
  }

  // Hapus pesan privat yang lebih lama dari 24 jam
  static Future<void> deleteExpiredMessages() async {
    try {
      final cutOff = DateTime.now().subtract(const Duration(hours: 24)).toUtc().toIso8601String();
      await supabase.from('chat_private').delete().lt('created_at', cutOff);
    } catch (e) {
      if (kDebugMode) print('Clean Private Messages Error: $e');
    }
  }
}
