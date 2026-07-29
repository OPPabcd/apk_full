import 'package:supabase_flutter/supabase_flutter.dart';

class NamaSekolahService {
  static final supabase = Supabase.instance.client;

  static Future<String?> getNamaSekolah() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await supabase
          .from('nama_sekolah')
          .select('sekolah')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response != null) {
        return response['sekolah'] as String;
      }
      return null;
    } catch (e) {
      print("Error fetching school name: $e");
      return null;
    }
  }

  static Future<Map<String, String?>?> getSchoolDetails() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

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
      return null;
    } catch (e) {
      print("Error fetching school details: $e");
      return null;
    }
  }

  static Future<void> updateNamaSekolah(String newName, String? newWilayah) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User not logged in");

    try {
      final existing = await supabase
          .from('nama_sekolah')
          .select('id_tabel')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Update existing record
        await supabase
            .from('nama_sekolah')
            .update({
              'sekolah': newName,
              'wilayah': newWilayah,
            })
            .eq('id_tabel', existing['id_tabel'])
            .eq('user_id', userId);
      } else {
        // Insert new record
        await supabase
            .from('nama_sekolah')
            .insert({
              'user_id': userId,
              'sekolah': newName,
              'wilayah': newWilayah,
            });
      }
    } catch (e) {
      print("Error updating school name: $e");
      rethrow;
    }
  }
}
