import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DbGrupSekolah {
  static final supabase = Supabase.instance.client;

  static String get userId {
    final id = supabase.auth.currentUser?.id;
    if (id == null) {
      throw Exception('User belum login');
    }
    return id;
  }

  // Determine current user's role and corresponding table ID
  static Future<Map<String, String>?> getCurrentUserRoleAndId() async {
    try {
      // 1. Cek Admin
      final adminRes = await supabase
          .from('user_admin')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      if (adminRes != null) {
        return {'role': 'admin', 'id': adminRes['id'].toString()};
      }

      // 2. Cek Guru
      final guruRes = await supabase
          .from('guru')
          .select('id_tabel')
          .eq('user_id', userId)
          .or('status_akun.is.null,status_akun.eq.true')
          .maybeSingle();
      if (guruRes != null) {
        return {'role': 'guru', 'id': guruRes['id_tabel'].toString()};
      }

      // 3. Cek Murid
      final muridRes = await supabase
          .from('murid')
          .select('id_tabel')
          .eq('user_id', userId)
          .or('status_akun.is.null,status_akun.eq.true')
          .maybeSingle();
      if (muridRes != null) {
        return {'role': 'murid', 'id': muridRes['id_tabel'].toString()};
      }
    } catch (e) {
      if (kDebugMode) print('Check Role Error: $e');
    }
    return null;
  }

  // Ambil semua nama (Admin, Guru, Murid) untuk ditampilkan di chat
  static Future<Map<String, String>> fetchAllNames() async {
    final Map<String, String> namesMap = {};
    try {
      // Fetch Admin names
      final admins = await supabase
          .from('user_admin')
          .select('id, name')
          .eq('id', userId); // user_admin table uses id as user_id

      for (var a in admins) {
        if (a['id'] != null && a['name'] != null) {
          namesMap[a['id'].toString()] = a['name'].toString();
        }
      }

      // Fetch Guru names
      final gurus = await supabase
          .from('guru')
          .select('id_tabel, name')
          .eq('user_id', userId)
          .or('status_akun.is.null,status_akun.eq.true');

      for (var g in gurus) {
        if (g['id_tabel'] != null && g['name'] != null) {
          namesMap[g['id_tabel'].toString()] = g['name'].toString();
        }
      }

      // Fetch Murid names
      final murids = await supabase
          .from('murid')
          .select('id_tabel, nama')
          .eq('user_id', userId)
          .or('status_akun.is.null,status_akun.eq.true');

      for (var m in murids) {
        if (m['id_tabel'] != null && m['nama'] != null) {
          namesMap[m['id_tabel'].toString()] = m['nama'].toString();
        }
      }
    } catch (e) {
      if (kDebugMode) print('Fetch Names Error: $e');
    }
    return namesMap;
  }

  // Stream chat global
  Stream<List<Map<String, dynamic>>> getGrupSekolahStream() {
    return supabase
        .from('grup_sekolah')
        .stream(primaryKey: ['id_tabel'])
        .eq('user_id', userId)
        .order('created_at', ascending: true);
  }

  // Kirim Pesan
  Future<void> sendMessage({
    required String text,
    required String senderId,
    required String role,
  }) async {
    try {
      final Map<String, dynamic> insertData = {
        'text': text,
        'user_id': userId,
      };

      if (role == 'admin') {
        insertData['pengirim_admin'] = senderId;
      } else if (role == 'guru') {
        insertData['pengirim_guru'] = senderId;
      } else if (role == 'murid') {
        insertData['pengirim_murid'] = senderId;
      }

      await supabase.from('grup_sekolah').insert(insertData);
    } catch (e) {
      if (kDebugMode) print('Send Message Error: $e');
      throw Exception('Gagal mengirim pesan: $e');
    }
  }
}
