import 'package:flutter/material.dart';

/// ============================================================
/// Export PDF Button — Reusable Widget
/// Letakkan di: lib/function/f_guru/absen_excel/pdf/export_pdf_button.dart
/// ============================================================

class ExportPdfButton extends StatefulWidget {
  /// Callback async yang memanggil PdfExportService
  final Future<void> Function() onExport;

  /// Label tombol (default: "Download PDF")
  final String label;

  /// Style: FAB (floating) atau ElevatedButton (inline)
  final ExportButtonStyle style;

  const ExportPdfButton({
    super.key,
    required this.onExport,
    this.label = 'Download PDF',
    this.style = ExportButtonStyle.elevated,
  });

  @override
  State<ExportPdfButton> createState() => _ExportPdfButtonState();
}

class _ExportPdfButtonState extends State<ExportPdfButton> {
  bool _isLoading = false;

  Future<void> _handleExport() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await widget.onExport();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal download PDF: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.style == ExportButtonStyle.fab
        ? _buildFab()
        : _buildElevated();
  }

  // — FAB style (floating action button)
  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _isLoading ? null : _handleExport,
      backgroundColor: const Color(0xFFEF4444), // Red for PDF
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.picture_as_pdf, color: Colors.white),
      label: Text(
        _isLoading ? 'Menyiapkan...' : widget.label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
      ),
    );
  }

  // — Elevated button style (inline di dalam konten)
  Widget _buildElevated() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _handleExport,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFEF4444), // Red for PDF
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      icon: _isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
      label: Text(
        _isLoading ? 'Menyiapkan PDF...' : widget.label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

enum ExportButtonStyle { fab, elevated }
