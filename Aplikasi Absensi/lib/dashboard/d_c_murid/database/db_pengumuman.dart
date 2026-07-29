import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DbPengumuman {
  static final supabase = Supabase.instance.client;

  static Future<String> getUserIdAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final ortuId = prefs.getString('user_id_admin');
    if (ortuId != null) return ortuId;

    final id = supabase.auth.currentUser?.id;
    if (id != null) return id;

    throw Exception('User belum login');
  }

  // Insert pengumuman baru
  static Future<Map<String, dynamic>> insertPengumuman({
    required String title,
    required String tanggalMulai,
    required String tanggalSelesai,
    String? keterangan,
    String? idGuru,
  }) async {
    // Bersihkan pengumuman yang sudah kadaluarsa
    await deleteExpiredPengumuman();

    final userId = await getUserIdAsync();
    
    final data = {
      'user_id': userId,
      'title': title,
      'tanggal_mulai': tanggalMulai,
      'tanggal_selesai': tanggalSelesai,
      if (keterangan != null && keterangan.isNotEmpty) 'keterangan': keterangan,
      if (idGuru != null && idGuru.isNotEmpty) 'id_guru': idGuru,
    };
    
    final res = await supabase.from('pengumuman').insert(data).select().single();
    return res;
  }

  // Get pengumuman berdasarkan ID
  static Future<Map<String, dynamic>?> getPengumumanById(String id) async {
    try {
      final res = await supabase.from('pengumuman').select().eq('id_tabel', id).maybeSingle();
      return res;
    } catch (e) {
      return null;
    }
  }

  // Hapus otomatis pengumuman yang sudah berakhir (tanggal_selesai < hari ini)
  static Future<void> deleteExpiredPengumuman() async {
    try {
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      // 1. Dapatkan semua ID pengumuman yang sudah kadaluarsa
      final expired = await supabase
          .from('pengumuman')
          .select('id_tabel')
          .lt('tanggal_selesai', todayStr);
          
      if (expired != null && expired.isNotEmpty) {
        final List<String> expiredIds = expired
            .map<String>((e) => e['id_tabel'].toString())
            .toList();
            
        // 2. Kosongkan referensi id_pengumuman di tabel absen agar tidak melanggar foreign key constraint
        await supabase
            .from('absen')
            .update({'id_pengumuman': null})
            .inFilter('id_pengumuman', expiredIds);
            
        // 3. Hapus pengumuman tersebut dari tabel pengumuman
        await supabase
            .from('pengumuman')
            .delete()
            .inFilter('id_tabel', expiredIds);
      }
    } catch (e) {
      // Silently ignore or log error
    }
  }
}
