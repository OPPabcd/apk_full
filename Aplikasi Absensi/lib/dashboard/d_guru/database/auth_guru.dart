import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apk/dashboard/d_guru/function/f_pesan_g/f_notif/fcm_notif.dart';

class AuthGuru {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> signInGuru(String email, String nik) async {
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

      // 2. Query guru with the resolved user_id and nik
      final response = await _supabase
          .from('guru')
          .select()
          .eq('user_id', userId)
          .eq('nik', nik)
          .single();

      if (response['status_akun'] == false) {
        throw Exception('Akun guru telah dinonaktifkan.');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', 'guru');
      await prefs.setString('guru_nik', nik);
      await prefs.setString('user_id_admin', userId);
      await prefs.setString('guru_nama', response['name']?.toString() ?? '');
      await prefs.setString('guru_id_tabel', response['id_tabel'].toString());
      return response;
    } catch (e) {
      if (e.toString().contains('dinonaktifkan')) {
        rethrow;
      }
      throw Exception('Login gagal: Periksa Email Admin dan NIK');
    }
  }
}
