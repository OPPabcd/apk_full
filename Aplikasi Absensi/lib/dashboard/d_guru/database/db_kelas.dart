import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DbKelas {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getMuridForGuru() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id_admin');
      final nik = prefs.getString('guru_nik');

      if (userId == null || nik == null) {
        throw Exception('Sesi guru tidak valid.');
      }

      // 1. Dapatkan Guru dan id_class-nya jika ada
      final guruData = await _supabase
          .from('guru')
          .select('id_tabel, id_class')
          .eq('user_id', userId)
          .eq('nik', nik)
          .maybeSingle();

      if (guruData == null) {
        throw Exception('Data guru tidak ditemukan.');
      }
      
      final guruIdTabel = guruData['id_tabel'];
      final guruIdClass = guruData['id_class']; // Dari tabel guru

      // 2. Kumpulkan semua ID Kelas (UUID) yang terkait dengan guru ini
      Set<String> validClassIds = {};
      if (guruIdClass != null) {
        validClassIds.add(guruIdClass.toString());
      }
      
      // Juga cek tabel class_name dimana id_guru = guruIdTabel
      final classDataList = await _supabase
          .from('class_name')
          .select('id_tabel, id_class')
          .eq('id_guru', guruIdTabel);
          
      for (var c in classDataList) {
        validClassIds.add(c['id_tabel'].toString());
      }

      if (validClassIds.isEmpty) {
        // Guru benar-benar tidak terhubung ke kelas manapun
        return [];
      }

      // 3. Kumpulkan Murid dengan berbagai kemungkinan relasi
      Map<String, Map<String, dynamic>> allMurid = {};

      // Relasi A: Murid yang id_class-nya merujuk ke validClassIds
      final muridListA = await _supabase
          .from('murid')
          .select('id_tabel, nis, nama, gender, id_class, created_at')
          .or('status_akun.is.null,status_akun.eq.true')
          .inFilter('id_class', validClassIds.toList());
          
      for (var m in muridListA) {
        allMurid[m['id_tabel'].toString()] = m;
      }

      // Relasi B: Membaca dari id_murid di tabel class_name (seperti instruksi Anda)
      // Cari baris class_name yang id_tabel-nya ada di validClassIds DAN punya id_murid
      final classMuridRows = await _supabase
          .from('class_name')
          .select('id_murid')
          .inFilter('id_tabel', validClassIds.toList())
          .not('id_murid', 'is', null);
          
      List<String> muridIdsFromClass = classMuridRows
          .map((r) => r['id_murid'].toString())
          .where((id) => id != 'null')
          .toList();
          
      if (muridIdsFromClass.isNotEmpty) {
        final muridListB = await _supabase
            .from('murid')
            .select('id_tabel, nis, nama, gender, id_class, created_at')
            .or('status_akun.is.null,status_akun.eq.true')
            .inFilter('id_tabel', muridIdsFromClass);
            
        for (var m in muridListB) {
          allMurid[m['id_tabel'].toString()] = m;
        }
      }

      // Relasi C: Jika class_name menggunakan 'id_class' numeric untuk mengelompokkan
      // Coba cari numeric id_class dari classDataList
      List<num> numericClassIds = classDataList
          .map((c) => c['id_class'] as num?)
          .where((id) => id != null)
          .cast<num>()
          .toList();
          
      if (numericClassIds.isNotEmpty) {
        final classRowsByNumeric = await _supabase
            .from('class_name')
            .select('id_murid')
            .inFilter('id_class', numericClassIds)
            .not('id_murid', 'is', null);
            
        List<String> extraMuridIds = classRowsByNumeric
            .map((r) => r['id_murid'].toString())
            .where((id) => id != 'null')
            .toList();
            
        if (extraMuridIds.isNotEmpty) {
          final muridListC = await _supabase
              .from('murid')
              .select('id_tabel, nis, nama, gender, id_class, created_at')
              .or('status_akun.is.null,status_akun.eq.true')
              .inFilter('id_tabel', extraMuridIds);
              
          for (var m in muridListC) {
            allMurid[m['id_tabel'].toString()] = m;
          }
        }
      }

      // Return hasil akhir dan urutkan berdasarkan nama
      final finalResult = allMurid.values.toList();
      finalResult.sort((a, b) => (a['nama']?.toString() ?? '').compareTo(b['nama']?.toString() ?? ''));
      
      return finalResult;
      
    } catch (e) {
      print('DEBUG getMuridForGuru ERROR: $e');
      throw Exception('Gagal memuat murid: $e');
    }
  }
}
