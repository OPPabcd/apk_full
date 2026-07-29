import 'dart:io';
import 'package:flutter/material.dart' hide Border, BorderStyle;
import 'package:excel/excel.dart';
import 'package:apk/dashboard/d_guru/function/absen_excel/storage_helper.dart';
import 'package:apk/dashboard/d_guru/database/holiday_service.dart';

class AbsensiExcelDownloader {
  static Future<void> downloadExcel({
    required BuildContext context,
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
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      int year = DateTime.now().year;
      int month = DateTime.now().month;
      final parts = yearMonth.split('-');
      if (parts.length == 2) {
        year = int.parse(parts[0]);
        month = int.parse(parts[1]);
      }

      final excel = Excel.createExcel();
      final sheet = excel['Rekap Absensi'];
      excel.setDefaultSheet('Rekap Absensi');

      // Kop
      if (namaSekolah.isNotEmpty) {
        sheet.appendRow([TextCellValue(namaSekolah.toUpperCase())]);
      }
      sheet.appendRow([TextCellValue('ABSENSI SISWA')]);
      sheet.appendRow([TextCellValue('BULAN : ${monthName.toUpperCase()}')]);
      sheet.appendRow([TextCellValue('')]);
      
      sheet.appendRow([TextCellValue('Kelas'), TextCellValue(':'), TextCellValue(namaKelas)]);
      sheet.appendRow([TextCellValue('Jumlah Murid'), TextCellValue(':'), TextCellValue('${muridList.length} Siswa')]);
      sheet.appendRow([TextCellValue('')]);

      // Header Table
      List<CellValue> headerRow1 = [
        TextCellValue('NO'),
        TextCellValue('NIS'),
        TextCellValue('NAMA SISWA'),
        TextCellValue('TANGGAL'),
      ];
      for (int i = 2; i <= daysInMonth; i++) {
        headerRow1.add(TextCellValue(''));
      }
      headerRow1.add(TextCellValue('KET'));
      for (int i = 1; i < 4; i++) {
        headerRow1.add(TextCellValue(''));
      }
      sheet.appendRow(headerRow1);

      List<CellValue> headerRow2 = [
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
      ];
      for (int i = 1; i <= daysInMonth; i++) {
        headerRow2.add(IntCellValue(i));
      }
      headerRow2.addAll([
        TextCellValue('H'),
        TextCellValue('I'),
        TextCellValue('S'),
        TextCellValue('A'),
      ]);
      sheet.appendRow(headerRow2);

      // Merge cells for header
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 7), CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 8));
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 7), CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 8));
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 7), CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 8));
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 7), CellIndex.indexByColumnRow(columnIndex: 3 + daysInMonth - 1, rowIndex: 7));
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 3 + daysInMonth, rowIndex: 7), CellIndex.indexByColumnRow(columnIndex: 3 + daysInMonth + 3, rowIndex: 7));

      // Data Rows
      for (int index = 0; index < muridList.length; index++) {
        final m = muridList[index];
        final nisStr = m['nis']?.toString();
        
        List<CellValue> row = [
          IntCellValue(index + 1),
          nisStr != null ? TextCellValue(nisStr) : TextCellValue('-'),
          TextCellValue(m['nama']?.toString() ?? '-'),
        ];

        for (int d = 1; d <= daysInMonth; d++) {
          String status = '-';
          if (nisStr != null && attendanceMap.containsKey(nisStr)) {
            final studentMap = attendanceMap[nisStr]!;
            status = studentMap[d]?.toString() ?? studentMap[d.toString()]?.toString() ?? '-';
          }
          row.add(TextCellValue(status));
        }

        String hVal = nisStr != null ? countStatus(nisStr, 'H').toString() : '-';
        String iVal = nisStr != null ? countStatus(nisStr, 'I').toString() : '-';
        String sVal = nisStr != null ? countStatus(nisStr, 'S').toString() : '-';
        String aVal = nisStr != null ? countStatus(nisStr, 'A').toString() : '-';

        row.addAll([
          TextCellValue(hVal),
          TextCellValue(iVal),
          TextCellValue(sVal),
          TextCellValue(aVal),
        ]);

        sheet.appendRow(row);
      }
      
      // Signature
      int totalColumns = 3 + daysInMonth + 4;
      int signColumnIndex = 3 + daysInMonth - 2;

      final now = DateTime.now();
      final tanggal =
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final lokasiTanggal =
          wilayah.isNotEmpty ? '$wilayah, $tanggal' : tanggal;
      final nipText = 'NIP. $nipWaliKelas';

      List<CellValue> emptyRow =
          List.generate(totalColumns, (index) => TextCellValue(''));

      // Baris 1: wilayah + tanggal
      List<CellValue> signRow0 =
          List.generate(totalColumns, (index) => TextCellValue(''));
      signRow0[signColumnIndex] = TextCellValue(lokasiTanggal);

      // Baris 2: jabatan
      List<CellValue> signRow1 =
          List.generate(totalColumns, (index) => TextCellValue(''));
      signRow1[signColumnIndex] = TextCellValue('Wali Kelas,');

      // Baris nama (bold + underline) — muncul setelah ruang tanda tangan
      List<CellValue> signRow2 =
          List.generate(totalColumns, (index) => TextCellValue(''));
      signRow2[signColumnIndex] = TextCellValue(namaWaliKelas);

      // Baris NIP
      List<CellValue> signRow3 =
          List.generate(totalColumns, (index) => TextCellValue(''));
      signRow3[signColumnIndex] = TextCellValue(nipText);

      sheet.appendRow(emptyRow);    // pemisah dari tabel
      sheet.appendRow(signRow0);    // wilayah, tanggal
      sheet.appendRow(signRow1);    // Wali Kelas,
      sheet.appendRow(emptyRow);    // ruang tanda tangan
      sheet.appendRow(emptyRow);
      sheet.appendRow(emptyRow);
      sheet.appendRow(signRow2);    // nama (di atas garis — bold)
      sheet.appendRow(signRow3);    // NIP

      // =========================
      // STYLE & BORDERS
      // =========================

      final sideBorder = Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.black,
      );

      final kopStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        leftBorder: sideBorder,
        rightBorder: sideBorder,
        topBorder: sideBorder,
        bottomBorder: sideBorder,
        textWrapping: TextWrapping.WrapText,
      );

      final dataCenterStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        leftBorder: sideBorder,
        rightBorder: sideBorder,
        topBorder: sideBorder,
        bottomBorder: sideBorder,
        textWrapping: TextWrapping.WrapText,
      );

      final sundayStyle = CellStyle(
        fontColorHex: ExcelColor.red,
        backgroundColorHex: ExcelColor.red100,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        leftBorder: sideBorder,
        rightBorder: sideBorder,
        topBorder: sideBorder,
        bottomBorder: sideBorder,
        textWrapping: TextWrapping.WrapText,
      );

      final dataLeftStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        leftBorder: sideBorder,
        rightBorder: sideBorder,
        topBorder: sideBorder,
        bottomBorder: sideBorder,
        textWrapping: TextWrapping.WrapText,
      );

      // Merge Kop (Baris 1, 2, 3)
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), CellIndex.indexByColumnRow(columnIndex: totalColumns - 1, rowIndex: 0));
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1), CellIndex.indexByColumnRow(columnIndex: totalColumns - 1, rowIndex: 1));
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2), CellIndex.indexByColumnRow(columnIndex: totalColumns - 1, rowIndex: 2));

      // Apply Kop Style
      for (int i = 0; i < 3; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i)).cellStyle = kopStyle;
      }

      // Apply Header Table Style (baris 8 dan 9 -> row index 7 dan 8)
      for (int r = 7; r <= 8; r++) {
        for (int c = 0; c < totalColumns; c++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).cellStyle = headerStyle;
        }
      }

      // Override Sunday & Holiday Headers (Row index 8)
      for (int i = 1; i <= daysInMonth; i++) {
        final date = DateTime(year, month, i);
        if (date.weekday == DateTime.sunday || HolidayService.isHoliday(date)) {
          int columnIndex = 3 + i - 1;
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: 8)).cellStyle = CellStyle(
            bold: true,
            fontColorHex: ExcelColor.red,
            backgroundColorHex: ExcelColor.red100,
            horizontalAlign: HorizontalAlign.Center,
            verticalAlign: VerticalAlign.Center,
            leftBorder: sideBorder,
            rightBorder: sideBorder,
            topBorder: sideBorder,
            bottomBorder: sideBorder,
          );
        }
      }

      // Apply Data Rows Style (mulai dari row index 9)
      int startDataRow = 9;
      for (int i = 0; i < muridList.length; i++) {
        int r = startDataRow + i;
        
        // NO
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).cellStyle = dataCenterStyle;
        // NIS
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r)).cellStyle = dataCenterStyle;
        // NAMA SISWA
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r)).cellStyle = dataLeftStyle;
        
        // Attendance & Rekap (H, I, S, A)
        for (int c = 3; c < totalColumns; c++) {
          bool isSundayOrHoliday = false;
          if (c < 3 + daysInMonth) {
            int d = c - 2;
            final date = DateTime(year, month, d);
            isSundayOrHoliday = date.weekday == DateTime.sunday || HolidayService.isHoliday(date);
          }
          
          if (isSundayOrHoliday) {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).cellStyle = sundayStyle;
          } else {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).cellStyle = dataCenterStyle;
          }
        }
      }

      // Apply Signature Style
      final signNormalStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        fontSize: 11,
      );
      
      final signNameStyle = CellStyle(
        bold: true,
        underline: Underline.Single,
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        fontSize: 11,
      );

      int signStartRow = startDataRow + muridList.length;
      // +0: empty separator
      // +1: wilayah, tanggal
      // +2: Wali Kelas,
      // +3,+4,+5: empty (signature space)
      // +6: nama (bold+underline)
      // +7: NIP
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: signColumnIndex, rowIndex: signStartRow + 1)).cellStyle = signNormalStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: signColumnIndex, rowIndex: signStartRow + 2)).cellStyle = signNormalStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: signColumnIndex, rowIndex: signStartRow + 6)).cellStyle = signNameStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: signColumnIndex, rowIndex: signStartRow + 7)).cellStyle = signNormalStyle;

      // =========================
      // UKURAN KOLOM
      // =========================

      sheet.setColumnWidth(0, 6); // NO
      sheet.setColumnWidth(1, 15); // NIS
      sheet.setColumnWidth(2, 30); // NAMA SISWA

      // Tanggal (Harian)
      for (int d = 1; d <= daysInMonth; d++) {
        int columnIndex = 3 + d - 1;
        bool hasTime = false;
        for (var m in muridList) {
          final nisStr = m['nis']?.toString();
          if (nisStr != null && attendanceMap.containsKey(nisStr)) {
            final status = attendanceMap[nisStr]![d] ?? '-';
            if (status.length > 1) {
              hasTime = true;
              break;
            }
          }
        }
        sheet.setColumnWidth(columnIndex, hasTime ? 15 : 5);
      }

      // Rekap columns (H, I, S, A)
      for (int i = 3 + daysInMonth; i < totalColumns; i++) {
        sheet.setColumnWidth(i, 5);
      }

      // =========================
      // SAVE FILE
      // =========================

      final downloadDir = await StorageHelper.getDownloadDirectoryPath();
      final baseName = 'Absensi_${namaKelas.replaceAll('/', '_')}_${monthName.replaceAll(' ', '_')}';
      
      var finalPath = StorageHelper.getUniqueFilePath(downloadDir, baseName, 'xlsx');
      var finalFileName = finalPath.split('/').last;

      final fileBytes = excel.save();

      if (fileBytes != null) {
        try {
          final file = File(finalPath);
          file.createSync(recursive: true);
          file.writeAsBytesSync(fileBytes);
        } catch (e) {
          final nowTime = DateTime.now();
          final timestamp = '${nowTime.hour.toString().padLeft(2, '0')}${nowTime.minute.toString().padLeft(2, '0')}${nowTime.second.toString().padLeft(2, '0')}';
          final fallbackFileName = '${baseName}_$timestamp.xlsx';
          finalPath = '$downloadDir/$fallbackFileName';
          finalFileName = fallbackFileName;
          final file = File(finalPath);
          file.createSync(recursive: true);
          file.writeAsBytesSync(fileBytes);
        }
      }

      if (context.mounted) {
        Navigator.pop(context); // Tutup loading dialog

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Excel Berhasil Didownload',
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: $finalFileName', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                const Text('Lokasi Penyimpanan:', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey)),
                Text(finalPath, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.black87)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan Excel: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }
}
