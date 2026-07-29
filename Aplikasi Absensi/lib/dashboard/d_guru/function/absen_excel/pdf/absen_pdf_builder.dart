import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/date_symbol_data_local.dart';
import '../storage_helper.dart';
import 'pdf_components.dart';
import 'package:apk/dashboard/d_guru/database/holiday_service.dart';

pw.Widget _buildMetaText(String label, String value) {
  return pw.RichText(
    text: pw.TextSpan(
      style: const pw.TextStyle(fontSize: 8),
      children: [
        pw.TextSpan(
          text: '$label: ',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: kPdfPrimary),
        ),
        pw.TextSpan(text: value),
      ],
    ),
  );
}

pw.Widget _buildAttendanceTable({
  required int year,
  required int month,
  required List<Map<String, dynamic>> muridList,
  required int daysInMonth,
  required Map<String, Map<dynamic, dynamic>> attendanceMap,
  required int Function(String, String) countStatus,
}) {
  // Headers
  List<String> headers = ['NO', 'NIS', 'NAMA SISWA'];
  for (int i = 1; i <= daysInMonth; i++) {
    headers.add('$i');
  }
  headers.addAll(['H', 'I', 'S', 'A']);

  // Rows
  List<List<pw.Widget>> rows = [];
  for (int index = 0; index < muridList.length; index++) {
    final m = muridList[index];
    final nisStr = m['nis']?.toString();
    
    List<pw.Widget> rowCells = [
      pw.Center(child: pw.Text('${index + 1}', style: const pw.TextStyle(fontSize: 6.5))),
      pw.Center(child: pw.Text(nisStr ?? '-', style: const pw.TextStyle(fontSize: 6.5))),
      pw.Text(m['nama']?.toString() ?? '-', style: const pw.TextStyle(fontSize: 6.5), maxLines: 1),
    ];

    for (int d = 1; d <= daysInMonth; d++) {
      String status = '-';
      if (nisStr != null && attendanceMap.containsKey(nisStr)) {
        final studentMap = attendanceMap[nisStr]!;
        status = studentMap[d]?.toString() ?? studentMap[d.toString()]?.toString() ?? '-';
      }
      
      final date = DateTime(year, month, d);
      final isSundayOrHoliday = date.weekday == DateTime.sunday || HolidayService.isHoliday(date);
      
      PdfColor? cellColor;
      PdfColor textColor = PdfColors.black;
      if (isSundayOrHoliday) {
        cellColor = PdfColor.fromInt(0xFFFFEBEE); // light red
        textColor = PdfColors.red;
      } else {
        switch (status) {
          case 'H': cellColor = PdfColor.fromInt(0xFFE8F5E9); break; // light green
          case 'S': cellColor = PdfColor.fromInt(0xFFE3F2FD); break; // light blue
          case 'I': cellColor = PdfColor.fromInt(0xFFFFF3E0); break; // light orange
          case 'A': cellColor = PdfColor.fromInt(0xFFFFEBEE); break; // light red
        }
      }

      rowCells.add(
        pw.Container(
          color: cellColor,
          alignment: pw.Alignment.center,
          child: pw.Text(
            status,
            style: pw.TextStyle(
              fontSize: 6.5, 
              color: textColor,
              fontWeight: status != '-' ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      );
    }

    String hVal = nisStr != null ? countStatus(nisStr, 'H').toString() : '-';
    String iVal = nisStr != null ? countStatus(nisStr, 'I').toString() : '-';
    String sVal = nisStr != null ? countStatus(nisStr, 'S').toString() : '-';
    String aVal = nisStr != null ? countStatus(nisStr, 'A').toString() : '-';

    rowCells.addAll([
      pw.Container(
        color: PdfColor.fromInt(0xFFE8F5E9),
        alignment: pw.Alignment.center,
        child: pw.Text(hVal, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
      ),
      pw.Container(
        color: PdfColor.fromInt(0xFFFFF3E0),
        alignment: pw.Alignment.center,
        child: pw.Text(iVal, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.orange)),
      ),
      pw.Container(
        color: PdfColor.fromInt(0xFFE3F2FD),
        alignment: pw.Alignment.center,
        child: pw.Text(sVal, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
      ),
      pw.Container(
        color: PdfColor.fromInt(0xFFFFEBEE),
        alignment: pw.Alignment.center,
        child: pw.Text(aVal, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
      ),
    ]);

    rows.add(rowCells);
  }

  // Column Widths
  Map<int, pw.TableColumnWidth> colWidths = {
    0: const pw.FixedColumnWidth(16),  // NO
    1: const pw.FixedColumnWidth(40),  // NIS
    2: const pw.FixedColumnWidth(95),  // NAMA SISWA
  };
  for (int i = 3; i < 3 + daysInMonth; i++) {
    colWidths[i] = const pw.FixedColumnWidth(14); // Days 1-31
  }
  for (int i = 3 + daysInMonth; i < 3 + daysInMonth + 4; i++) {
    colWidths[i] = const pw.FixedColumnWidth(15); // H, I, S, A
  }

  return buildDataTable(
    headers: headers,
    rows: rows,
    colWidths: colWidths,
  );
}

Future<String> exportAbsensiPdf({
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
}) async {
  try {
    // Initialize Indonesian locale formatting
    await initializeDateFormatting('id_ID', null);
    
    // Parse year & month
    int year = DateTime.now().year;
    int month = DateTime.now().month;
    final parts = yearMonth.split('-');
    if (parts.length == 2) {
      year = int.parse(parts[0]);
      month = int.parse(parts[1]);
    }

    // Generate date & location text
    final now = DateTime.now();
    final tanggal = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
    final lokasiTanggal = wilayah.isNotEmpty ? '$wilayah, $tanggal' : tanggal;

    final pdf = pw.Document();

    // Determine the month text header dynamically
    final displayMonth = monthName.toUpperCase().contains(year.toString())
        ? monthName.toUpperCase()
        : '${monthName.toUpperCase()} $year';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        header: (context) => buildPdfHeader('LAPORAN BULANAN ABSENSI SISWA', DateTime.now()),
        footer: (context) => buildPdfFooter(context),
        build: (context) {
          return [
            // Subtitle / School details
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildMetaText('Sekolah', namaSekolah.toUpperCase()),
                    pw.SizedBox(height: 2),
                    _buildMetaText('Kelas', namaKelas),
                    pw.SizedBox(height: 2),
                    _buildMetaText('Bulan', displayMonth),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _buildMetaText('Wali Kelas', namaWaliKelas),
                    pw.SizedBox(height: 2),
                    _buildMetaText('Jumlah Murid', '${muridList.length} Siswa'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // Table Header Title
            buildSectionTitle('Tabel Absensi Harian & Rekapitulasi'),
            pw.SizedBox(height: 6),

            // Table
            _buildAttendanceTable(
              year: year,
              month: month,
              muridList: muridList,
              daysInMonth: daysInMonth,
              attendanceMap: attendanceMap,
              countStatus: countStatus,
            ),
            pw.SizedBox(height: 16),

            // Signature Block
            pw.Align(
              alignment: pw.Alignment.bottomRight,
              child: pw.Container(
                width: 160,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(lokasiTanggal, style: const pw.TextStyle(fontSize: 8)),
                    pw.SizedBox(height: 2),
                    pw.Text('Wali Kelas,', style: const pw.TextStyle(fontSize: 8)),
                    pw.SizedBox(height: 40),
                    pw.Text(namaWaliKelas, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Container(height: 0.5, color: PdfColors.black),
                    pw.SizedBox(height: 2),
                    pw.Text('NIP. $nipWaliKelas', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
            ),
          ];
        },
      ),
    );

  final dirPath = await StorageHelper.getDownloadDirectoryPath();
  final baseName = 'Absensi_${namaKelas.replaceAll('/', '_')}_${monthName.replaceAll(' ', '_')}';
  var finalPath = StorageHelper.getUniqueFilePath(dirPath, baseName, 'pdf');
  var file = File(finalPath);
  
  final bytes = await pdf.save();
  try {
    await file.writeAsBytes(bytes, flush: true);
  } catch (e) {
    final nowTime = DateTime.now();
    final timestamp = '${nowTime.hour.toString().padLeft(2, '0')}${nowTime.minute.toString().padLeft(2, '0')}${nowTime.second.toString().padLeft(2, '0')}';
    final fallbackFileName = '${baseName}_$timestamp.pdf';
    finalPath = '$dirPath/$fallbackFileName';
    file = File(finalPath);
    await file.writeAsBytes(bytes, flush: true);
  }

  return finalPath;
  } catch (e, stack) {
    debugPrint('=== PDF EXPORT RUNTIME ERROR ===');
    debugPrint(e.toString());
    debugPrint(stack.toString());
    rethrow;
  }
}
