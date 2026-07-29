import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NamaSekolahService {
  static final supabase = Supabase.instance.client;

  /// Mengambil nama sekolah saja (backward-compat).
  static Future<String?> getNamaSekolah() async {
    final info = await getSekolahInfo();
    return info['sekolah'];
  }

  /// Mengambil informasi sekolah lengkap: nama sekolah dan wilayah.
  /// Mengembalikan Map dengan key 'sekolah' dan 'wilayah'.
  static Future<Map<String, String?>> getSekolahInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id_admin');
    if (userId == null) return {'sekolah': null, 'wilayah': null};

    try {
      final response = await supabase
          .from('nama_sekolah')
          .select('sekolah, wilayah')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return {
          'sekolah': response['sekolah'] as String?,
          'wilayah': response['wilayah'] as String?,
        };
      }
      return {'sekolah': null, 'wilayah': null};
    } catch (e) {
      print("Error fetching school info: $e");
      return {'sekolah': null, 'wilayah': null};
    }
  }
}
