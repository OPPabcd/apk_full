import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class DbIzin {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> uploadIzinFile(String authId, String nis, Uint8List fileBytes, String originalFileName) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$originalFileName';
      final filePath = '$authId/$nis/$fileName';

      await _supabase.storage.from('doc_izin').uploadBinary(filePath, fileBytes);
      return _supabase.storage.from('doc_izin').getPublicUrl(filePath);
      
    } catch (e) {
      throw Exception('Gagal mengunggah surat izin: $e');
    }
  }

  Future<Map<String, dynamic>> submitIzin(Map<String, dynamic> data) async {
    try {
      final res = await _supabase.from('leave_request').insert(data).select().single();
      return res;
    } catch (e) {
      throw Exception('Gagal mengajukan izin: $e');
    }
  }
}
