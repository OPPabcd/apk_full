import 'absen_pdf_builder.dart';

/// ============================================================
/// PDF Export Service — Entry Point
/// Letakkan di: lib/function/f_guru/absen_excel/pdf/pdf_export_service.dart
///
/// Ini cuma facade — semua logic ada di builder masing-masing.
/// Import file ini saja di screen kamu.
/// ============================================================

class PdfExportService {
  PdfExportService._(); // tidak bisa di-instantiate

  static Future<String> absensi({
    required String namaSekolah,
    required String monthName,
    required String yearMonth,
    required String namaKelas,
    required String namaWaliKelas,
    required String nipWaliKelas,
    required String wilayah,
    required List<Map<String, dynamic>> muridList,
    required int daysInMonth,
    required Map<String, Map<dynamic, dynamic>> attendanceMap,
    required int Function(String, String) countStatus,
  }) =>
      exportAbsensiPdf(
        namaSekolah: namaSekolah,
        monthName: monthName,
        yearMonth: yearMonth,
        namaKelas: namaKelas,
        namaWaliKelas: namaWaliKelas,
        nipWaliKelas: nipWaliKelas,
        wilayah: wilayah,
        muridList: muridList,
        daysInMonth: daysInMonth,
        attendanceMap: attendanceMap,
        countStatus: countStatus,
      );
}
