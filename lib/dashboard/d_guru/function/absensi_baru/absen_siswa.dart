import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:apk/dashboard/d_guru/database/db_absensi.dart';
import 'package:apk/dashboard/d_guru/function/absen_excel/pdf/absen_baru_pdf.dart';

class AbsenSiswaPage extends StatefulWidget {
  final String judul;
  final String date;

  const AbsenSiswaPage({
    super.key,
    required this.judul,
    required this.date,
  });

  @override
  State<AbsenSiswaPage> createState() => _AbsenSiswaPageState();
}

class _AbsenSiswaPageState extends State<AbsenSiswaPage> {
  bool _isLoading = true;
  bool _isTableMode = false;
  bool _isExporting = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _students = [];

  // Map id_tabel -> selected status ('hadir', 'izin', 'sakit', 'alpha', or null)
  final Map<String, String?> _selectedStatus = {};

  final List<String> _statusOptions = ['hadir', 'izin', 'sakit', 'alpha'];
  final Map<String, String> _statusLabels = {
    'hadir': 'Hadir',
    'izin': 'Izin',
    'sakit': 'Sakit',
    'alpha': 'Alpha',

  };
  final Map<String, Color> _statusColors = {
    'hadir': const Color(0xFF10B981),
    'izin': const Color(0xFFF59E0B),
    'sakit': const Color(0xFF3B82F6),
    'alpha': const Color(0xFFEF4444),

  };
  final Map<String, IconData> _statusIcons = {
    'hadir': Icons.check_circle,
    'izin': Icons.mail_outline,
    'sakit': Icons.local_hospital,
    'alpha': Icons.cancel,

  };

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final students = await DbAbsensi().getSessionStudents(widget.judul, widget.date);
      if (!mounted) return;

      // Initialize selected statuses from database
      for (var s in students) {
        final id = s['id_tabel'].toString();
        String? status;
        if (s['Null_data']?.toString() == 'Belum Absen') {
          status = null;
        } else if (s['ket_hadir'] != null && s['ket_hadir'].toString().isNotEmpty) {
          status = 'hadir';
        } else if (s['ket_izin'] != null && s['ket_izin'].toString().isNotEmpty) {
          status = 'izin';
        } else if (s['ket_sakit'] != null && s['ket_sakit'].toString().isNotEmpty) {
          status = 'sakit';
        } else if (s['ket_alpha'] != null && s['ket_alpha'].toString().isNotEmpty) {
          status = 'alpha';
        } else if (s['ket_libur'] != null && s['ket_libur'].toString().isNotEmpty) {
          status = 'libur';
        }
        _selectedStatus[id] = status;
      }

      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat data siswa: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String idTabel, String? status) async {
    setState(() {
      _selectedStatus[idTabel] = status;
    });

    try {
      await DbAbsensi().updateStudentSessionStatus(
        idTabel: idTabel,
        selectedStatus: status,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e', style: const TextStyle(fontFamily: 'Inter'))),
      );
    }
  }

  Future<void> _deleteSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Sesi', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin menghapus sesi absensi ini? Data tidak dapat dikembalikan.',
            style: TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(fontFamily: 'Inter', color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(fontFamily: 'Inter', color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DbAbsensi().deleteSession(widget.judul, widget.date);
        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e', style: const TextStyle(fontFamily: 'Inter'))),
        );
      }
    }
  }

  void _switchToTableMode() {
    setState(() {
      _isTableMode = true;
    });
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);

    try {
      // Build student data list for PDF
      final List<Map<String, dynamic>> pdfStudents = [];
      for (int i = 0; i < _students.length; i++) {
        final s = _students[i];
        final id = s['id_tabel'].toString();
        final status = _selectedStatus[id];
        final nama = s['murid']?['nama']?.toString() ?? 'Tanpa Nama';
        final nis = s['murid']?['nis'];

        String keterangan = '-';
        if (status != null && _statusLabels.containsKey(status)) {
          keterangan = _statusLabels[status]!;
        }

        pdfStudents.add({
          'no': i + 1,
          'nis': nis,
          'nama': nama,
          'keterangan': keterangan,
        });
      }

      final path = await exportAbsenBaruPdf(
        judul: widget.judul,
        date: widget.date,
        students: pdfStudents,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF berhasil disimpan di: $path', style: const TextStyle(fontFamily: 'Inter')),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal export PDF: $e', style: const TextStyle(fontFamily: 'Inter'))),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _getFormattedDate() {
    try {
      final parsed = DateTime.parse(widget.date);
      return DateFormat('dd MMMM yyyy', 'id_ID').format(parsed);
    } catch (_) {
      return widget.date;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(_isTableMode ? 'Hasil Absensi' : 'Absen Siswa'),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_errorMessage!,
                        style: const TextStyle(color: Colors.red, fontFamily: 'Inter')),
                  ),
                )
              : _isTableMode
                  ? _buildTableMode()
                  : _buildChecklistMode(),
    );
  }

  // ─── CHECKLIST MODE ──────────────────────────────────────────────
  Widget _buildChecklistMode() {
    return Column(
      children: [
        // Header info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF2563EB),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.judul,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _getFormattedDate(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_students.length} Siswa',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Student list
        Expanded(
          child: _students.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Tidak ada siswa',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    final idTabel = student['id_tabel'].toString();
                    final nama = student['murid']?['nama']?.toString() ?? 'Tanpa Nama';
                    final nis = student['murid']?['nis']?.toString() ?? '-';
                    final currentStatus = _selectedStatus[idTabel];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Student info
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nama,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'NIS: $nis',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Status chips (radio-style)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _statusOptions.map((status) {
                                final isSelected = currentStatus == status;
                                final color = _statusColors[status]!;
                                return GestureDetector(
                                  onTap: () {
                                    // Toggle: tap again to unselect
                                    final newStatus = isSelected ? null : status;
                                    _updateStatus(idTabel, newStatus);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? color.withOpacity(0.15) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected ? color : const Color(0xFFE2E8F0),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isSelected ? _statusIcons[status] : Icons.radio_button_unchecked,
                                          size: 16,
                                          color: isSelected ? color : const Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _statusLabels[status]!,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                            color: isSelected ? color : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Bottom buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _deleteSession,
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                  label: const Text('Hapus', style: TextStyle(fontFamily: 'Inter', color: Color(0xFFEF4444))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _switchToTableMode,
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text('Selesai',
                      style: TextStyle(fontFamily: 'Inter', color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── TABLE MODE ──────────────────────────────────────────────────
  Widget _buildTableMode() {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.judul,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(
                      _getFormattedDate(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Summary row
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: _statusOptions.map((status) {
              final count = _selectedStatus.values.where((v) => v == status).length;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _statusColors[status]!.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _statusColors[status]!.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$count',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _statusColors[status],
                        ),
                      ),
                      Text(
                        _statusLabels[status]!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          color: _statusColors[status],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Table
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF2563EB)),
                  headingTextStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  dataTextStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF334155),
                  ),
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(label: Text('No')),
                    DataColumn(label: Text('Nama')),
                    DataColumn(label: Text('Keterangan')),
                  ],
                  rows: List.generate(_students.length, (index) {
                    final s = _students[index];
                    final id = s['id_tabel'].toString();
                    final nama = s['murid']?['nama']?.toString() ?? 'Tanpa Nama';
                    final status = _selectedStatus[id];
                    final label = status != null ? _statusLabels[status]! : '-';
                    final color = status != null ? _statusColors[status]! : const Color(0xFF94A3B8);

                    return DataRow(
                      color: WidgetStateProperty.resolveWith<Color?>(
                        (states) => index.isEven ? const Color(0xFFF8FAFC) : Colors.white,
                      ),
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(Text(nama, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),

        // Bottom buttons (Back to checklist + Download PDF)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _isTableMode = false),
                  icon: const Icon(Icons.edit, color: Color(0xFF2563EB), size: 18),
                  label: const Text('Edit', style: TextStyle(fontFamily: 'Inter', color: Color(0xFF2563EB))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isExporting ? null : _exportPdf,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.picture_as_pdf, color: Colors.white),
                  label: Text(
                    _isExporting ? 'Mengunduh...' : 'Download PDF',
                    style: const TextStyle(fontFamily: 'Inter', color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
