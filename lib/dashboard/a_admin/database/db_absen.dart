import 'package:supabase_flutter/supabase_flutter.dart';

class AbsenService {
  static final supabase = Supabase.instance.client;

  /// Naik tingkat kelas:
  /// 1. Pindahkan murid-murid ke kelas tujuan (targetClassId)
  /// 2. Hapus seluruh data absen murid-murid tersebut
  /// 3. Hapus seluruh chat private murid-murid tersebut
  static Future<void> promoteClass({
    required String sourceClassId,
    required String targetClassId,
    required List<String> studentIds,
  }) async {
    if (studentIds.isEmpty) return;

    // 1. Pindahkan murid ke kelas tujuan
    print("promoteClass Step 1: Updating murid.id_class to targetClassId...");
    await supabase
        .from('murid')
        .update({'id_class': targetClassId})
        .inFilter('id_tabel', studentIds);
    print("promoteClass Step 1 completed.");

    // 2. Hapus data absen murid-murid tersebut
    print("promoteClass Step 2: Deleting murid records from 'absen'...");
    await supabase
        .from('absen')
        .delete()
        .inFilter('id_murid', studentIds);
    print("promoteClass Step 2 completed.");

    // 3. Hapus data chat private murid-murid tersebut (baik sebagai pengirim maupun penerima)
    print("promoteClass Step 3a: Deleting chat_private where pengirim_murid in studentIds...");
    await supabase
        .from('chat_private')
        .delete()
        .inFilter('pengirim_murid', studentIds);
    print("promoteClass Step 3a completed.");

    print("promoteClass Step 3b: Deleting chat_private where penerima_murid in studentIds...");
    await supabase
        .from('chat_private')
        .delete()
        .inFilter('penerima_murid', studentIds);
    print("promoteClass Step 3b completed.");
  }
}
