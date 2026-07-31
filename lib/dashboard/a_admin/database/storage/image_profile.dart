import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageProfileStorage {
  final _supabase = Supabase.instance.client;
  final String _bucketName = 'image_profil';

  // Mendapatkan Signed URL untuk gambar profil
  Future<String?> getProfileImageUrl(String userId) async {
    try {
      final url = await _supabase.storage
          .from(_bucketName)
          .createSignedUrl('$userId/profile_admin', 60 * 60); // Expired dalam 1 jam
      return url;
    } catch (e) {
      // Abaikan jika gambar belum ada atau RLS menolak akses
      return null;
    }
  }

  // Mengupload gambar profil dan mengembalikan URL baru
  Future<String> uploadProfileImage(String userId, Uint8List bytes) async {
    final path = '$userId/profile_admin';
    
    await _supabase.storage
        .from(_bucketName)
        .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
        
    final newUrl = await _supabase.storage
        .from(_bucketName)
        .createSignedUrl(path, 60 * 60);
        
    return newUrl;
  }

  // Menghapus gambar profil
  Future<void> deleteProfileImage(String userId) async {
    final path = '$userId/profile_admin';
    await _supabase.storage.from(_bucketName).remove([path]);
  }
}
