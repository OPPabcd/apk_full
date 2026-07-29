import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DbGuru {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getAllGuru() async {
    try {
      // Fetch all guru, possibly with their class name if you have a relationship set up
      // Or just fetch the table and handle join locally if needed
      final response = await _supabase
          .from('guru')
          .select('*, class_name!guru_id_class_fkey(*)')
          .or('status_akun.is.null,status_akun.eq.true');
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // If there's no relationship 'class_name', fallback to normal select
      try {
         final fallbackResponse = await _supabase
             .from('guru')
             .select('*')
             .or('status_akun.is.null,status_akun.eq.true');
         return List<Map<String, dynamic>>.from(fallbackResponse);
      } catch (e2) {
         throw Exception('Gagal memuat data guru: $e2');
      }
    }
  }

  Future<List<Map<String, dynamic>>> getGuruForStudentClass() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id_admin');
      final nis = prefs.getString('murid_nis');

      if (userId == null || nis == null) return [];

      // 1. Dapatkan info murid untuk mengambil id_class murid tersebut
      final muridData = await _supabase
          .from('murid')
          .select('id_class')
          .eq('user_id', userId)
          .eq('nis', nis)
          .maybeSingle();

      if (muridData == null || muridData['id_class'] == null) return [];
      final String studentClassId = muridData['id_class'].toString();

      // 2. Dapatkan Wali Kelas untuk kelas tersebut
      final classData = await _supabase
          .from('class_name')
          .select('id_guru')
          .eq('id_tabel', studentClassId)
          .maybeSingle();
      
      final String? waliKelasGuruId = classData?['id_guru']?.toString();

      // 3. Dapatkan guru yang mengajar di kelas murid tersebut (guru.id_class == studentClassId)
      //    dan juga Wali Kelas dari kelas tersebut (guru.id_tabel == waliKelasGuruId)
      var query = _supabase
          .from('guru')
          .select('*')
          .or('status_akun.is.null,status_akun.eq.true');
      
      if (waliKelasGuruId != null && waliKelasGuruId.isNotEmpty) {
        query = query.or('id_class.eq.$studentClassId,id_tabel.eq.$waliKelasGuruId');
      } else {
        query = query.eq('id_class', studentClassId);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getGuruForLoggedGuruClass() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id_admin');
      final nik = prefs.getString('guru_nik');

      if (userId == null || nik == null) return [];

      // 1. Dapatkan info guru yang login
      final guruData = await _supabase
          .from('guru')
          .select('id_tabel, id_class')
          .eq('user_id', userId)
          .eq('nik', nik)
          .maybeSingle();

      if (guruData == null) return [];

      Set<String> validClassIds = {};
      if (guruData['id_class'] != null) {
        validClassIds.add(guruData['id_class'].toString());
      }

      // Ambil class_name yang terkait dengan guru ini
      final classDataList = await _supabase
          .from('class_name')
          .select('id_tabel, id_class')
          .eq('id_guru', guruData['id_tabel']);
          
      for (var c in classDataList) {
        validClassIds.add(c['id_tabel'].toString());
      }

      if (validClassIds.isEmpty) return [];

      // 2. Ambil semua guru yang terhubung ke kelas yang sama (melalui id_class di tabel guru)
      final gurusInClass = await _supabase
          .from('guru')
          .select('*, class_name!guru_id_class_fkey(*)')
          .inFilter('id_class', validClassIds.toList())
          .or('status_akun.is.null,status_akun.eq.true');

      return List<Map<String, dynamic>>.from(gurusInClass);
    } catch (e) {
      throw Exception('Gagal memuat data guru per kelas: $e');
    }
  }
  Future<Map<String, dynamic>> getLoggedInGuruInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id_admin');
    final nik = prefs.getString('guru_nik');

    if (userId == null || nik == null) {
      throw Exception('Sesi guru tidak valid.');
    }

    final guruData = await _supabase
        .from('guru')
        .select()
        .eq('user_id', userId)
        .eq('nik', nik)
        .maybeSingle();

    if (guruData == null) {
      throw Exception('Data guru tidak ditemukan.');
    }

    // Cek apakah wali kelas
    final classData = await _supabase
        .from('class_name')
        .select('name_class')
        .eq('id_guru', guruData['id_tabel'])
        .maybeSingle();

    guruData['is_wali_kelas'] = classData != null;
    
    if (classData != null) {
      guruData['class_name'] = classData['name_class'];
    } else if (guruData['id_class'] != null) {
      // Jika bukan wali kelas, ambil nama kelas berdasarkan id_class
      final classDataById = await _supabase
          .from('class_name')
          .select('name_class')
          .eq('id_tabel', guruData['id_class'])
          .maybeSingle();
      guruData['class_name'] = classDataById?['name_class'];
    } else {
      guruData['class_name'] = null;
    }

    return guruData;
  }

  Future<void> updateGuru({
    required String idTabel,
    required num nik,
    required String name,
    String? bidang,
    String? idClass,
    required bool wali,
  }) async {
    await _supabase.from('guru').update({
      'nik': nik,
      'name': name,
      'bidang': bidang,
      'id_class': idClass,
      'wali': wali,
    }).eq('id_tabel', idTabel);
  }

  Future<void> deleteGuru(String idTabel) async {
    try {
      await _supabase.from('guru').update({
        'status_akun': false,
        'id_class': null,
      }).eq('id_tabel', idTabel);
    } catch (e) {
      throw Exception('Gagal menghapus guru: $e');
    }
  }
}
