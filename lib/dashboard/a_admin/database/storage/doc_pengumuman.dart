import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class DocPengumuman {
  static final supabase = Supabase.instance.client;

  static Future<String?> uploadDoc(Uint8List bytes, String title, String ext) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = '$userId/$title/$fileName';

      // Asumsikan bucket bernama 'pengumuman'
      await supabase.storage.from('pengumuman').uploadBinary(
        path, 
        bytes, 
        fileOptions: const FileOptions(upsert: true)
      );
      
      return supabase.storage.from('pengumuman').getPublicUrl(path);
    } catch (e) {
      print('Upload Doc Pengumuman Error: $e');
      return null;
    }
  }
}
