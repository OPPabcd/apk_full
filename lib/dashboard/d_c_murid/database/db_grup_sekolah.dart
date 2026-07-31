import 'package:apk/dashboard/d_c_murid/function/f_Pesan/doc_image.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DbGrupSekolah {
  static final supabase = Supabase.instance.client;

  static Future<String> getUserIdAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final ortuId = prefs.getString('user_id_admin');
    if (ortuId != null) return ortuId;

    final id = supabase.auth.currentUser?.id;
    if (id != null) return id;

    throw Exception('User belum login');
  }

  // Determine current user's role and corresponding table ID
  static Future<Map<String, String>?> getCurrentUserRoleAndId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role');
      
      // 1. Cek Ortu/Murid (menggunakan SharedPreferences)
      if (role == 'ortu' || role == 'murid') {
        final nis = prefs.getString('murid_nis');
        final adminId = prefs.getString('user_id_admin');
        if (nis != null && adminId != null) {
          final muridRes = await supabase
              .from('murid')
              .select('id_tabel, status_akun')
              .eq('user_id', adminId)
              .eq('nis', nis)
              .maybeSingle();
          if (muridRes != null && muridRes['status_akun'] != false) {
            return {'role': 'murid', 'id': muridRes['id_tabel'].toString()};
          }
        }
        return null;
      }
      
      // 2. Cek Guru (menggunakan SharedPreferences)
      if (role == 'guru') {
        final nik = prefs.getString('guru_nik');
        final adminId = prefs.getString('user_id_admin');
        if (nik != null && adminId != null) {
          final guruRes = await supabase
              .from('guru')
              .select('id_tabel, status_akun')
              .eq('user_id', adminId)
              .eq('nik', nik)
              .maybeSingle();
          if (guruRes != null && guruRes['status_akun'] != false) {
            return {'role': 'guru', 'id': guruRes['id_tabel'].toString()};
          }
        }
        return null;
      }

      // 3. Cek Admin (menggunakan Supabase Auth)
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final adminRes = await supabase
          .from('user_admin')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      if (adminRes != null) {
        return {'role': 'admin', 'id': adminRes['id'].toString()};
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
      final admins = await supabase.from('user_admin').select('id, name');
      for (var a in admins) {
        if (a['id'] != null && a['name'] != null) {
          namesMap[a['id'].toString()] = a['name'].toString();
        }
      }

      // Fetch Guru names
      final gurus = await supabase
          .from('guru')
          .select('id_tabel, name')
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
    deleteExpiredMessages();
    return supabase
        .from('grup_sekolah')
        .stream(primaryKey: ['id_tabel'])
        .order('created_at', ascending: true);
  }

  // Kirim Pesan
  Future<void> sendMessage({
    required String text,
    required String senderId,
    required String role,
  }) async {
    try {
      await deleteExpiredMessages();
      final userId = await getUserIdAsync();
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

  // Hapus pesan grup sekolah yang lebih lama dari 24 jam
  static Future<void> deleteExpiredMessages() async {
    try {
      final cutOff = DateTime.now().subtract(const Duration(hours: 24)).toUtc().toIso8601String();
      await supabase.from('grup_sekolah').delete().lt('created_at', cutOff);
    } catch (e) {
      if (kDebugMode) print('Clean Group School Messages Error: $e');
    }
  }
}
