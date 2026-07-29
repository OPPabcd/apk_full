import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuruService {
  static final supabase = Supabase.instance.client;

  static String get userId {
    final id = supabase.auth.currentUser?.id;
    if (id == null) {
      throw Exception('User belum login');
    }
    return id;
  }

  // ===============================
  // 🔹 GET DATA GURU
  // ===============================
  static Future<List<Map<String, dynamic>>> getGuru() async {
    try {
      final response = await supabase
          .from('guru')
          .select('''
            id_tabel,
            nik,
            name,
            bidang,
            wali,
            id_class,
            created_at,
            class_name!guru_id_class_fkey (
              id_tabel,
              name_class
            )
          ''')
          .eq('user_id', userId)
          .or('status_akun.is.null,status_akun.eq.true')
          .order('name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('GET GURU ERROR: $e');
      }
      throw Exception('Gagal memuat data guru: $e');
    }
  }

  // ===============================
  // 🔹 GET DATA KELAS
  // ===============================
  static Future<List<Map<String, dynamic>>> getKelas() async {
    try {
      final response = await supabase
          .from('class_name')
          .select('id_tabel, name_class')
          .eq('user_id', userId)
          .order('name_class');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('GET KELAS ERROR: $e');
      }
      return [];
    }
  }

  // ===============================
  // 🔹 CHECK WALI KELAS
  // ===============================
  static Future<bool> checkWaliExists(String idClass, {String? excludeGuruId}) async {
    try {
      var query = supabase
          .from('guru')
          .select('id_tabel')
          .eq('user_id', userId)
          .eq('id_class', idClass)
          .eq('wali', true)
          .or('status_akun.is.null,status_akun.eq.true');

      if (excludeGuruId != null) {
        query = query.neq('id_tabel', excludeGuruId);
      }

      final res = await query.limit(1);
      return res.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('CHECK WALI ERROR: $e');
      }
      throw Exception('Gagal mengecek status wali kelas');
    }
  }

  static Future<String?> checkNikDuplicate(String nik, {String? excludeGuruId}) async {
    try {
      var query = supabase
          .from('guru')
          .select('id_tabel, status_akun')
          .eq('user_id', userId)
          .eq('nik', nik);

      if (excludeGuruId != null) {
        query = query.neq('id_tabel', excludeGuruId);
      }

      final res = await query.limit(1);
      if (res.isEmpty) return null;

      final bool statusAkun = res.first['status_akun'] == true;
      return statusAkun ? 'active' : 'deleted';
    } catch (e) {
      if (kDebugMode) {
        print('CHECK NIK DUPLICATE ERROR: $e');
      }
      throw Exception('Gagal mengecek NIK guru');
    }
  }

  static Future<String?> checkNameDuplicate(String name, {String? excludeGuruId}) async {
    try {
      var query = supabase
          .from('guru')
          .select('id_tabel, status_akun')
          .eq('user_id', userId)
          .eq('name', name);

      if (excludeGuruId != null) {
        query = query.neq('id_tabel', excludeGuruId);
      }

      final res = await query.limit(1);
      if (res.isEmpty) return null;

      final bool statusAkun = res.first['status_akun'] == true;
      return statusAkun ? 'active' : 'deleted';
    } catch (e) {
      if (kDebugMode) {
        print('CHECK NAME DUPLICATE ERROR: $e');
      }
      throw Exception('Gagal mengecek nama guru');
    }
  }

  // ===============================
  // 🔹 INSERT DATA GURU
  // ===============================
  static Future<void> tambahGuru({
    required String nik,
    required String name,
    String? bidang,
    String? idClass,
    required bool wali,
  }) async {
    try {
      if (wali && idClass == null) {
        throw Exception('Kelas harus dipilih jika menjadi Wali Kelas');
      }

      final nikDup = await checkNikDuplicate(nik);
      if (nikDup == 'active') {
        throw Exception('NIK sudah terdaftar!');
      } else if (nikDup == 'deleted') {
        throw Exception('NIK sudah terdaftar di Tempat Sampah! Silakan periksa Tempat Sampah untuk memulihkannya.');
      }

      final nameDup = await checkNameDuplicate(name);
      if (nameDup == 'active') {
        throw Exception('Nama guru sudah terdaftar!');
      } else if (nameDup == 'deleted') {
        throw Exception('Nama guru sudah terdaftar di Tempat Sampah! Silakan periksa Tempat Sampah untuk memulihkannya.');
      }

      if (wali && idClass != null) {
        final exists = await checkWaliExists(idClass);
        if (exists) {
          throw Exception('Kelas ini sudah memiliki wali kelas!');
        }
      }

      await supabase.from('guru').insert({
        'user_id': userId,
        'nik': nik,
        'name': name,
        'bidang': bidang,
        'id_class': idClass,
        'wali': wali,
        'status_akun': true,
      });
    } catch (e) {
      if (kDebugMode) {
        print('ADD GURU ERROR: $e');
      }
      rethrow;
    }
  }

  // ===============================
  // 🔹 UPDATE DATA GURU
  // ===============================
  static Future<void> updateGuru({
    required String idTabel,
    required String nik,
    required String name,
    String? bidang,
    String? idClass,
    required bool wali,
  }) async {
    try {
      if (wali && idClass == null) {
        throw Exception('Kelas harus dipilih jika menjadi Wali Kelas');
      }

      final nikDup = await checkNikDuplicate(nik, excludeGuruId: idTabel);
      if (nikDup == 'active') {
        throw Exception('NIK sudah terdaftar!');
      } else if (nikDup == 'deleted') {
        throw Exception('NIK sudah terdaftar di Tempat Sampah! Silakan periksa Tempat Sampah untuk memulihkannya.');
      }

      final nameDup = await checkNameDuplicate(name, excludeGuruId: idTabel);
      if (nameDup == 'active') {
        throw Exception('Nama guru sudah terdaftar!');
      } else if (nameDup == 'deleted') {
        throw Exception('Nama guru sudah terdaftar di Tempat Sampah! Silakan periksa Tempat Sampah untuk memulihkannya.');
      }

      if (wali && idClass != null) {
        final exists = await checkWaliExists(idClass, excludeGuruId: idTabel);
        if (exists) {
          throw Exception('Kelas ini sudah memiliki wali kelas!');
        }
      }

      await supabase.from('guru').update({
        'nik': nik,
        'name': name,
        'bidang': bidang,
        'id_class': idClass,
        'wali': wali,
      }).eq('id_tabel', idTabel).eq('user_id', userId);
    } catch (e) {
      if (kDebugMode) {
        print('UPDATE GURU ERROR: $e');
      }
      rethrow;
    }
  }

  // ===============================
  // 🔹 DELETE DATA GURU
  // ===============================
  static Future<void> deleteGuru(String idTabel) async {
    try {
      await supabase.from('guru').update({
        'status_akun': false,
        'id_class': null,
        'wali': false,
      }).eq('id_tabel', idTabel).eq('user_id', userId);
    } catch (e) {
      if (kDebugMode) {
        print('DELETE GURU ERROR: $e');
      }
      rethrow;
    }
  }

  // ===============================
  // 🔹 GET DELETED GURU
  // ===============================
  static Future<List<Map<String, dynamic>>> getDeletedGuru() async {
    try {
      final response = await supabase
          .from('guru')
          .select('''
            id_tabel,
            nik,
            name,
            bidang,
            wali,
            id_class,
            created_at,
            class_name!guru_id_class_fkey (
              id_tabel,
              name_class
            )
          ''')
          .eq('user_id', userId)
          .eq('status_akun', false)
          .order('name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('GET DELETED GURU ERROR: $e');
      }
      throw Exception('Gagal memuat data guru yang dihapus: $e');
    }
  }

  // ===============================
  // 🔹 RESTORE DATA GURU
  // ===============================
  static Future<void> restoreGuru(String idTabel) async {
    try {
      await supabase.from('guru').update({
        'status_akun': true,
      }).eq('id_tabel', idTabel).eq('user_id', userId);
    } catch (e) {
      if (kDebugMode) {
        print('RESTORE GURU ERROR: $e');
      }
      rethrow;
    }
  }

  // ===============================
  // 🔹 DELETE DATA GURU PERMANENTLY
  // ===============================
  static Future<void> deleteGuruPermanently(String idTabel) async {
    try {
      await supabase.from('guru').delete().eq('id_tabel', idTabel).eq('user_id', userId);
    } catch (e) {
      if (kDebugMode) {
        print('DELETE GURU PERMANENTLY ERROR: $e');
      }
      rethrow;
    }
  }
}