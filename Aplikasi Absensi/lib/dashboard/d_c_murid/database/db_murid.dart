import 'package:supabase_flutter/supabase_flutter.dart';

class DbMurid {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getAllMurid() async {
    try {
      final response = await _supabase
          .from('murid')
          .select('*, class_name(*)')
          .or('status_akun.is.null,status_akun.eq.true');
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      try {
         final fallbackResponse = await _supabase
             .from('murid')
             .select('*')
             .or('status_akun.is.null,status_akun.eq.true');
         return List<Map<String, dynamic>>.from(fallbackResponse);
      } catch (e2) {
         throw Exception('Gagal memuat data murid: $e2');
      }
    }
  }

  Future<void> addMurid({
    required String nis,
    required String nama,
    required String userId,
    String? idClass,
    String? gender,
    DateTime? tanggalLahir,
    String? alamat,
    String? orangTua,
    num? noTele,
  }) async {
    try {
      await _supabase.from('murid').insert({
        'nis': nis,
        'nama': nama,
        'user_id': userId,
        'id_class': idClass,
        'gender': gender,
        'tanggal_lahir': tanggalLahir?.toIso8601String().split('T').first,
        'alamat': alamat,
        'orang_tua': orangTua,
        'no_tele': noTele,
        'status_akun': true,
      });
    } catch (e) {
      throw Exception('Gagal menambahkan murid: $e');
    }
  }

  Future<void> deleteMurid(String idTabel) async {
    try {
      await _supabase.from('murid').update({
        'status_akun': false,
        'id_class': null,
      }).eq('id_tabel', idTabel);
    } catch (e) {
      throw Exception('Gagal menghapus murid: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getKelas() async {
    try {
      final response = await _supabase.from('class_name').select('*');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal memuat data kelas: $e');
    }
  }

  Future<void> updateMurid({
    required String idTabel,
    required String nis,
    required String nama,
    String? idClass,
    String? gender,
    DateTime? tanggalLahir,
    String? alamat,
    String? orangTua,
    num? noTele,
  }) async {
    try {
      await _supabase.from('murid').update({
        'nis': nis,
        'nama': nama,
        'id_class': idClass,
        'gender': gender,
        'tanggal_lahir': tanggalLahir?.toIso8601String().split('T').first,
        'alamat': alamat,
        'orang_tua': orangTua,
        'no_tele': noTele,
      }).eq('id_tabel', idTabel);
    } catch (e) {
      throw Exception('Gagal mengupdate profil: $e');
    }
  }
}
