import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class DocPengumuman {
  static final supabase = Supabase.instance.client;

  static Future<String?> uploadDoc(Uint8List bytes, String title, String ext) async {
    try {
      // Membersihkan nama file dari karakter tidak valid
      final cleanTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$cleanTitle.$ext';
      
      await supabase.storage.from('pengumuman').uploadBinary(fileName, bytes);
      return supabase.storage.from('pengumuman').getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }
}
