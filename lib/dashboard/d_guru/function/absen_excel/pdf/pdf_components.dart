import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

// ─── Warna tema ───────────────────────────────────────────────
const kPdfPrimary = PdfColor.fromInt(0xFF1565C0);
const kPdfAccent = PdfColor.fromInt(0xFF42A5F5);
const kPdfRowEven = PdfColor.fromInt(0xFFF5F9FF);
const kPdfBorder = PdfColor.fromInt(0xFFBBDEFB);

// ─── Format tanggal ───────────────────────────────────────────
final pdfDateFormat = DateFormat('dd MMMM yyyy', 'id_ID');
final pdfTimeFormat = DateFormat('HH:mm:ss');
final pdfFullFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

// ================================================================
// HEADER — muncul di setiap halaman
// ================================================================
pw.Widget buildPdfHeader(String title, DateTime date) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 16),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: kPdfBorder, width: 1.5),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: kPdfPrimary,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Sistem Informasi Akademik & Absensi',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              pdfDateFormat.format(date),
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: kPdfPrimary,
              ),
            ),
            pw.Text(
              pdfTimeFormat.format(date),
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    ),
  );
}

// ================================================================
// FOOTER — muncul di setiap halaman
// ================================================================
pw.Widget buildPdfFooter(pw.Context context) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 12),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: kPdfBorder, width: 1)),
    ),
    child: pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Digenerate otomatis oleh Aplikasi Akademik',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
          pw.Text(
            'Halaman ${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    ),
  );
}

// ================================================================
// SECTION TITLE — judul bagian dengan background biru
// ================================================================
pw.Widget buildSectionTitle(String title) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
    decoration: const pw.BoxDecoration(
      color: kPdfPrimary,
      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
    ),
  );
}

// ================================================================
// SUMMARY CARD — grid kartu nilai terkini
// ================================================================
pw.Widget buildSummaryCard({
  required String title,
  required String subtitle,
  required List<SummaryItem> items,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: const PdfColor.fromInt(0xFFE3F2FD),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      border: pw.Border.all(color: kPdfBorder),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: kPdfPrimary,
          ),
        ),
        pw.Text(
          subtitle,
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 8),
        pw.Wrap(
          spacing: 10,
          runSpacing: 6,
          children: items.map((item) => _summaryItemCard(item)).toList(),
        ),
      ],
    ),
  );
}

pw.Widget _summaryItemCard(SummaryItem item) {
  return pw.Container(
    width: 140,
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      border: pw.Border.all(color: kPdfBorder),
    ),
    child: pw.Row(
      children: [
        pw.Text(item.emoji, style: const pw.TextStyle(fontSize: 14)),
        pw.SizedBox(width: 6),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              item.label,
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              item.value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: kPdfPrimary,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ================================================================
// BASE TABLE — semua tabel pakai ini
// ================================================================
pw.Widget buildDataTable({
  required List<String> headers,
  required List<List<pw.Widget>> rows,
  Map<int, pw.TableColumnWidth>? colWidths,
}) {
  return pw.Table(
    border: pw.TableBorder.all(color: kPdfBorder, width: 0.5),
    columnWidths: colWidths,
    children: [
      // Header
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: kPdfPrimary),
        children: headers
            .map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      vertical: 5, horizontal: 4),
                  child: pw.Align(
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
      // Data rows
      ...rows.asMap().entries.map((entry) {
        final isEven = entry.key % 2 == 0;
        return pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isEven ? kPdfRowEven : PdfColors.white,
          ),
          children: entry.value
              .map((cell) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 3, horizontal: 4),
                    child: cell,
                  ))
              .toList(),
        );
      }),
    ],
  );
}

// ================================================================
// KEY-VALUE TABLE — tabel 3 kolom: Parameter | Nilai | Satuan
// ================================================================
pw.Widget buildKeyValueTable(List<List<String>> rows) {
  final headerRow = rows.first;
  final dataRows = rows.skip(1).toList();

  final List<List<pw.Widget>> widgetRows = dataRows.map((r) {
    return r.map((cellText) => pw.Text(cellText, style: const pw.TextStyle(fontSize: 8))).toList();
  }).toList();

  return buildDataTable(
    headers: headerRow,
    rows: widgetRows,
    colWidths: {
      0: const pw.FlexColumnWidth(2),
      1: const pw.FlexColumnWidth(1.5),
      2: const pw.FlexColumnWidth(1),
    },
  );
}

// ================================================================
// HELPER CLASS
// ================================================================
class SummaryItem {
  final String label;
  final String value;
  final String emoji;
  const SummaryItem(this.label, this.value, this.emoji);
}

// ================================================================
// STATS HELPER
// ================================================================
Map<String, double> calcStats(List<double> data) {
  if (data.isEmpty) return {'avg': 0, 'max': 0, 'min': 0};
  final sorted = List<double>.from(data)..sort();
  final avg = data.reduce((a, b) => a + b) / data.length;
  return {'avg': avg, 'max': sorted.last, 'min': sorted.first};
}
