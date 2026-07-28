import 'package:supabase_flutter/supabase_flutter.dart';

class ClassService {

  static final supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getClasses() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await supabase
          .from('class_name')
          .select('''
            *,
            guru!guru_id_class_fkey(name, wali, status_akun),
            murid!murid_id_class_fkey(id_tabel, status_akun)
          ''')
          .eq('user_id', userId)
          .order('id_class');

      final list = List<Map<String, dynamic>>.from(response);
      for (var cls in list) {
        if (cls['guru'] != null) {
          final rawGurus = cls['guru'] as List;
          cls['guru'] = rawGurus.where((g) => g['status_akun'] != false).toList();
        }
        if (cls['murid'] != null) {
          final rawMurids = cls['murid'] as List;
          cls['murid'] = rawMurids.where((m) => m['status_akun'] != false).toList();
        }
      }
      return list;
    } catch (e) {
      print("Error fetching with relations: $e");
      
      // Fallback if the relationship queries throw error (e.g. FK not yet reflected)
      try {
        final response2 = await supabase
            .from('class_name')
            .select('*')
            .eq('user_id', userId)
            .order('id_class');
        return List<Map<String, dynamic>>.from(response2);
      } catch (eFallback) {
         print("Fallback fetching failed: $eFallback");
         return [];
      }
    }
  }

  static Future<List<Map<String, dynamic>>> getGuru() async {
    final response = await supabase
        .from('guru')
        .select('id_tabel, name')
        .or('status_akun.is.null,status_akun.eq.true')
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getMurid() async {
    final response = await supabase
        .from('murid')
        .select('id_tabel, nama')
        .or('status_akun.is.null,status_akun.eq.true')
        .order('nama');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getMuridByClass(String idTabelClass) async {
    final response = await supabase
        .from('murid')
        .select('id_tabel, nis, nama, gender')
        .eq('id_class', idTabelClass)
        .or('status_akun.is.null,status_akun.eq.true')
        .order('nama');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getGuruByClass(String idTabelClass) async {
    final response = await supabase
        .from('guru')
        .select('id_tabel, nik, name, bidang, wali')
        .eq('id_class', idTabelClass)
        .or('status_akun.is.null,status_akun.eq.true')
        .order('wali', ascending: false); // Wali kelas will be at the top
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> tambahKelas({
    required num idClass,
    required String nameClass,
    String? idGuru,
    String? idMurid,
    String? tahun,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User not logged in");

    await supabase.from('class_name').insert({
      'id_class': idClass,
      'name_class': nameClass,
      'user_id': userId,
      if (idGuru != null) 'id_guru': idGuru,
      if (idMurid != null) 'id_murid': idMurid,
      if (tahun != null) 'tahun': tahun,
    });
  }

  static Future<void> updateKelas({
    required String idTabel,
    required num idClass,
    required String nameClass,
    String? tahun,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User not logged in");

    await supabase.from('class_name').update({
      'id_class': idClass,
      'name_class': nameClass,
      'tahun': tahun, // can be null to clear
    }).eq('id_tabel', idTabel).eq('user_id', userId);
  }

  static Future<void> deleteKelas(String idTabel) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User not logged in");

    // Remove relationships first: set id_class to null for guru and murid
    await supabase.from('guru').update({'id_class': null, 'wali': false}).eq('id_class', idTabel).eq('user_id', userId);
    await supabase.from('murid').update({'id_class': null}).eq('id_class', idTabel).eq('user_id', userId);

    // Then delete the class
    await supabase.from('class_name').delete().eq('id_tabel', idTabel).eq('user_id', userId);
  }

  static Future<List<Map<String, dynamic>>> getGuruUnassigned() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];
    final response = await supabase
        .from('guru')
        .select('id_tabel, nik, name, bidang')
        .filter('id_class', 'is', null)
        .eq('user_id', userId)
        .or('status_akun.is.null,status_akun.eq.true')
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getMuridUnassigned() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];
    final response = await supabase
        .from('murid')
        .select('id_tabel, nis, nama, gender')
        .filter('id_class', 'is', null)
        .eq('user_id', userId)
        .or('status_akun.is.null,status_akun.eq.true')
        .order('nama');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> assignGuruToClass(String idGuru, String idTabelClass, {bool isWali = false}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User not logged in");
    await supabase.from('guru').update({
      'id_class': idTabelClass,
      'wali': isWali,
    }).eq('id_tabel', idGuru).eq('user_id', userId);
  }

  static Future<void> removeGuruFromClass(String idGuru) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User not logged in");
    await supabase.from('guru').update({
      'id_class': null,
      'wali': false,
    }).eq('id_tabel', idGuru).eq('user_id', userId);
  }

  static Future<void> assignMuridToClass(String idMurid, String idTabelClass) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User not logged in");
    await supabase.from('murid').update({
      'id_class': idTabelClass,
    }).eq('id_tabel', idMurid).eq('user_id', userId);
  }

  static Future<void> removeMuridFromClass(String idMurid) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User not logged in");
    await supabase.from('murid').update({
      'id_class': null,
    }).eq('id_tabel', idMurid).eq('user_id', userId);
  }
}
