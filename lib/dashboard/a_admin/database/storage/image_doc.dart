import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageDocStorage {
  static final supabase = Supabase.instance.client;

  static Future<String?> uploadFile(Uint8List bytes, String fileName) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return null;

      // path: userId/doc_image/fileName (di dalam bucket chat_file)
      final path = '$userId/doc_image/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await supabase.storage.from('chat_file').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );

      return supabase.storage.from('chat_file').getPublicUrl(path);
    } catch (e) {
      print('Upload Image/Doc Error: $e');
      return null;
    }
  }

  static Future<String?> uploadFileObject(File file, String fileName) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final path = '$userId/doc_image/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await supabase.storage.from('chat_file').upload(
        path,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      return supabase.storage.from('chat_file').getPublicUrl(path);
    } catch (e) {
      print('Upload File Error: $e');
      return null;
    }
  }
}
