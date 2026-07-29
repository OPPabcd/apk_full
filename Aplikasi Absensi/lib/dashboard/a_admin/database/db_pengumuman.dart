import 'package:supabase_flutter/supabase_flutter.dart';

/*
create table public.pengumuman (
  id_tabel uuid not null default gen_random_uuid (),
  created_at timestamp with time zone not null default now(),
  user_id uuid null,
  title text not null,
  tanggal_mulai date not null,
  tanggal_selesai date not null,
  keterangan text null,
  id_guru uuid null,
  constraint pengumuman_pkey primary key (id_tabel),
  constraint pengumuman_id_guru_fkey foreign KEY (id_guru) references guru (id_tabel),
  constraint pengumuman_user_id_fkey foreign KEY (user_id) references auth.users (id)
) TABLESPACE pg_default;
*/

class DbPengumuman {
  static final supabase = Supabase.instance.client;

  static String get userId {
    final id = supabase.auth.currentUser?.id;
    if (id == null) throw Exception('User belum login');
    return id;
  }

  // Insert pengumuman baru
  static Future<Map<String, dynamic>> insertPengumuman({
    required String title,
    required String tanggalMulai,
    required String tanggalSelesai,
    String? keterangan,
    String? idGuru,
  }) async {
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
      final res = await supabase.from('pengumuman').select().eq('id_tabel', id).eq('user_id', userId).maybeSingle();
      return res;
    } catch (e) {
      return null;
    }
  }
}
