import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MuridService {
  final supabase = Supabase.instance.client;

  String get userId {
    final id = supabase.auth.currentUser?.id;
    if (id == null) {
      throw Exception('User belum login');
    }
    return id;
  }

  // ===============================
  // 🔹 GET DATA MURID
  // ===============================
  Future<List<Map<String, dynamic>>> getMurid() async {
    try {
      final res = await supabase
          .from('murid')
          .select('''
            id_tabel,
            nis,
            nama,
            id_class,
            gender,
            tanggal_lahir,
            alamat,
            orang_tua,
            no_tele,
            created_at,
            class_name!murid_id_class_fkey (
              id_tabel,
              name_class
            )
          ''')
          .eq('user_id', userId)
          .or('status_akun.is.null,status_akun.eq.true')
          .order('nis', ascending: true);

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      if (kDebugMode) {
        print('GET MURID ERROR: $e');
      }
      throw Exception('Gagal memuat data murid: $e');
    }
  }

  // ===============================
  // 🔹 GET DATA KELAS
  // ===============================
  Future<List<Map<String, dynamic>>> getKelas() async {
    try {
      final res = await supabase
          .from('class_name')
          .select('id_tabel, name_class')
          .eq('user_id', userId)
          .order('name_class', ascending: true);

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      if (kDebugMode) {
        print('GET KELAS ERROR: $e');
      }
      return [];
    }
  }

  Future<String?> checkNisDuplicate(String nis, {String? excludeMuridId}) async {
    try {
      var query = supabase
          .from('murid')
          .select('id_tabel, status_akun')
          .eq('user_id', userId)
          .eq('nis', nis);

      if (excludeMuridId != null) {
        query = query.neq('id_tabel', excludeMuridId);
      }

      final res = await query.limit(1);
      if (res.isEmpty) return null;

      final bool statusAkun = res.first['status_akun'] == true;
      return statusAkun ? 'active' : 'deleted';
    } catch (e) {
      if (kDebugMode) {
        print('CHECK NIS DUPLICATE ERROR: $e');
      }
      throw Exception('Gagal mengecek NIS murid');
    }
  }

  Future<String?> checkNamaDuplicate(String nama, {String? excludeMuridId}) async {
    try {
      var query = supabase
          .from('murid')
          .select('id_tabel, status_akun')
          .eq('user_id', userId)
          .eq('nama', nama);

      if (excludeMuridId != null) {
        query = query.neq('id_tabel', excludeMuridId);
      }

      final res = await query.limit(1);
      if (res.isEmpty) return null;

      final bool statusAkun = res.first['status_akun'] == true;
      return statusAkun ? 'active' : 'deleted';
    } catch (e) {
      if (kDebugMode) {
        print('CHECK NAMA DUPLICATE ERROR: $e');
      }
      throw Exception('Gagal mengecek nama murid');
    }
  }

  // ===============================
  // 🔹 INSERT DATA MURID
  // ===============================
  Future<void> addMurid({
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
      final nisDup = await checkNisDuplicate(nis);
      if (nisDup == 'active') {
        throw Exception('NIS sudah terdaftar!');
      } else if (nisDup == 'deleted') {
        throw Exception('NIS sudah terdaftar di Tempat Sampah! Silakan periksa Tempat Sampah untuk memulihkannya.');
      }

      final namaDup = await checkNamaDuplicate(nama);
      if (namaDup == 'active') {
        throw Exception('Nama murid sudah terdaftar!');
      } else if (namaDup == 'deleted') {
        throw Exception('Nama murid sudah terdaftar di Tempat Sampah! Silakan periksa Tempat Sampah untuk memulihkannya.');
      }

      await supabase.from('murid').insert({
        'user_id': userId,
        'nis': nis,
        'nama': nama,
        'id_class': idClass,
        'gender': gender,
        'tanggal_lahir': tanggalLahir?.toIso8601String().split('T').first,
        'alamat': alamat,
        'orang_tua': orangTua,
        'no_tele': noTele,
        'status_akun': true,
      });
    } catch (e) {
      if (kDebugMode) {
        print('ADD MURID ERROR: $e');
      }
      rethrow;
    }
  }

  // ===============================
  // 🔹 UPDATE DATA MURID
  // pakai primary key id_tabel
  // ===============================
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
      final nisDup = await checkNisDuplicate(nis, excludeMuridId: idTabel);
      if (nisDup == 'active') {
        throw Exception('NIS sudah terdaftar!');
      } else if (nisDup == 'deleted') {
        throw Exception('NIS sudah terdaftar di Tempat Sampah! Silakan periksa Tempat Sampah untuk memulihkannya.');
      }

      final namaDup = await checkNamaDuplicate(nama, excludeMuridId: idTabel);
      if (namaDup == 'active') {
        throw Exception('Nama murid sudah terdaftar!');
      } else if (namaDup == 'deleted') {
        throw Exception('Nama murid sudah terdaftar di Tempat Sampah! Silakan periksa Tempat Sampah untuk memulihkannya.');
      }

      await supabase
          .from('murid')
          .update({
            'nis': nis,
            'nama': nama,
            'id_class': idClass,
            'gender': gender,
            'tanggal_lahir':
                tanggalLahir?.toIso8601String().split('T').first,
            'alamat': alamat,
            'orang_tua': orangTua,
            'no_tele': noTele,
          })
          .eq('id_tabel', idTabel)
          .eq('user_id', userId);
    } catch (e) {
      if (kDebugMode) {
        print('UPDATE MURID ERROR: $e');
      }
      rethrow;
    }
  }

  // ===============================
  // 🔹 DELETE DATA MURID
  // pakai primary key id_tabel
  // ===============================
  Future<void> deleteMurid(String idTabel) async {
    try {
      await supabase
          .from('murid')
          .update({
            'status_akun': false,
            'id_class': null,
          })
          .eq('id_tabel', idTabel)
          .eq('user_id', userId);
    } catch (e) {
      if (kDebugMode) {
        print('DELETE MURID ERROR: $e');
      }
      rethrow;
    }
  }

  // ===============================
  // 🔹 GET DELETED MURID
  // ===============================
  Future<List<Map<String, dynamic>>> getDeletedMurid() async {
    try {
      final res = await supabase
          .from('murid')
          .select('''
            id_tabel,
            nis,
            nama,
            id_class,
            gender,
            tanggal_lahir,
            alamat,
            orang_tua,
            no_tele,
            created_at,
            class_name!murid_id_class_fkey (
              id_tabel,
              name_class
            )
          ''')
          .eq('user_id', userId)
          .eq('status_akun', false)
          .order('nis', ascending: true);

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      if (kDebugMode) {
        print('GET DELETED MURID ERROR: $e');
      }
      throw Exception('Gagal memuat data murid yang dihapus: $e');
    }
  }

  // ===============================
  // 🔹 RESTORE DATA MURID
  // ===============================
  Future<void> restoreMurid(String idTabel) async {
    try {
      await supabase
          .from('murid')
          .update({
            'status_akun': true,
          })
          .eq('id_tabel', idTabel)
          .eq('user_id', userId);
    } catch (e) {
      if (kDebugMode) {
        print('RESTORE MURID ERROR: $e');
      }
      rethrow;
    }
  }

  // ===============================
  // 🔹 DELETE DATA MURID PERMANENTLY
  // ===============================
  Future<void> deleteMuridPermanently(String idTabel) async {
    try {
      await supabase.from('murid').delete().eq('id_tabel', idTabel).eq('user_id', userId);
    } catch (e) {
      if (kDebugMode) {
        print('DELETE MURID PERMANENTLY ERROR: $e');
      }
      rethrow;
    }
  }
}