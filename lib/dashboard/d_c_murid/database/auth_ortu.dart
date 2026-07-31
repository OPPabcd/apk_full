import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/fcm_notif.dart';

class AuthOrtu {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> signInOrtu(String email, String nis) async {
    try {
      // 1. Resolve user_id (UUID) from the admin's email in user_admin
      final adminRes = await _supabase
          .from('user_admin')
          .select('id')
          .eq('email', email.trim())
          .maybeSingle();

      if (adminRes == null) {
        throw Exception('Email admin tidak ditemukan.');
      }

      final userId = adminRes['id'].toString();

      // 2. Query murid with the resolved user_id and nis
      final response = await _supabase
          .from('murid')
          .select()
          .eq('user_id', userId)
          .eq('nis', nis)
          .single();

      if (response['status_akun'] == false) {
        throw Exception('Akun murid telah dinonaktifkan.');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', 'ortu');
      await prefs.setString('murid_nis', nis);
      await prefs.setString('user_id_admin', userId);
      
      final nameValue = response['nama'] ?? '';
      await prefs.setString('murid_nama', nameValue);
      await prefs.setString('murid_id_tabel', response['id_tabel'].toString());
      return response;
    } catch (e) {
      if (e.toString().contains('dinonaktifkan')) {
        rethrow;
      }
      throw Exception('Login gagal: Periksa Email Admin dan NIS');
    }
  }
}
