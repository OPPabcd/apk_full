import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DbPesanPrivate {
  static final supabase = Supabase.instance.client;

  static String get userId {
    final id = supabase.auth.currentUser?.id;
    if (id == null) {
      throw Exception('User belum login');
    }
    return id;
  }

  // Get Admin ID (for the current logged in user)
  Future<String?> getAdminId() async {
    try {
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
    return supabase
        .from('chat_private')
        .stream(primaryKey: ['id_tabel'])
        .eq('user_id', userId)
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
    return supabase
        .from('chat_private')
        .stream(primaryKey: ['id_tabel'])
        .eq('user_id', userId)
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
}
