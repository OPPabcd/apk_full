import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../storage_helper.dart';
import 'pdf_components.dart';

Future<String> exportAbsenBaruPdf({
  required String judul,
  required String date,
  required List<Map<String, dynamic>> students,
}) async {
  await initializeDateFormatting('id_ID', null);

  String formattedDate = date;
  try {
    final parsed = DateTime.parse(date);
    formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(parsed);
  } catch (_) {}

  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => buildPdfHeader('LAPORAN ABSENSI SESI', DateTime.now()),
      footer: (context) => buildPdfFooter(context),
      build: (context) {
        return [
          // Meta info
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildMeta('Judul', judul),
                  pw.SizedBox(height: 2),
                  _buildMeta('Tanggal', formattedDate),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _buildMeta('Jumlah Siswa', '${students.length}'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // Section title
          buildSectionTitle('Daftar Absensi Siswa'),
          pw.SizedBox(height: 8),

          // Table
          _buildStudentTable(students),
          pw.SizedBox(height: 24),

          // Signature block
          pw.Align(
            alignment: pw.Alignment.bottomRight,
            child: pw.Container(
              width: 160,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Guru Pengajar,', style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 40),
                  pw.Container(height: 0.5, color: PdfColors.black),
                  pw.SizedBox(height: 3),
                  pw.Text('(..........................)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          ),
        ];
      },
    ),
  );

  // Save file
  final dirPath = await StorageHelper.getDownloadDirectoryPath();
  final sanitizedJudul = judul.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
  final sanitizedDate = date.replaceAll('-', '');
  final baseName = 'Absensi_${sanitizedJudul}_$sanitizedDate';
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
}

pw.Widget _buildMeta(String label, String value) {
  return pw.RichText(
    text: pw.TextSpan(
      style: const pw.TextStyle(fontSize: 9),
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

pw.Widget _buildStudentTable(List<Map<String, dynamic>> students) {
  final headers = ['NO', 'NIS', 'NAMA SISWA', 'KETERANGAN'];

  final List<List<pw.Widget>> rows = [];
  for (var s in students) {
    final ket = s['keterangan']?.toString() ?? '-';
    PdfColor textColor = PdfColors.black;
    PdfColor? bgColor;

    switch (ket) {
      case 'Hadir':
        textColor = PdfColors.green;
        bgColor = const PdfColor.fromInt(0xFFE8F5E9);
        break;
      case 'Sakit':
        textColor = PdfColors.blue;
        bgColor = const PdfColor.fromInt(0xFFE3F2FD);
        break;
      case 'Izin':
        textColor = PdfColors.orange;
        bgColor = const PdfColor.fromInt(0xFFFFF3E0);
        break;
      case 'Alpha':
        textColor = PdfColors.red;
        bgColor = const PdfColor.fromInt(0xFFFFEBEE);
        break;
      case 'Libur':
        textColor = PdfColors.purple;
        bgColor = const PdfColor.fromInt(0xFFF3E5F5);
        break;
    }

    rows.add([
      pw.Center(child: pw.Text('${s['no']}', style: const pw.TextStyle(fontSize: 8))),
      pw.Center(child: pw.Text(s['nis']?.toString() ?? '-', style: const pw.TextStyle(fontSize: 8))),
      pw.Text(s['nama']?.toString() ?? '-', style: const pw.TextStyle(fontSize: 8), maxLines: 1),
      pw.Container(
        color: bgColor,
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: pw.Text(
          ket,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    ]);
  }

  return buildDataTable(
    headers: headers,
    rows: rows,
    colWidths: {
      0: const pw.FixedColumnWidth(30), // NO
      1: const pw.FixedColumnWidth(60), // NIS
      2: const pw.FlexColumnWidth(3),   // NAMA SISWA
      3: const pw.FixedColumnWidth(80), // KETERANGAN
    },
  );
}
