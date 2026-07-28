import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:apk/dashboard/d_c_murid/database/db_absensi.dart';

class AbsenPreview extends StatefulWidget {
  final String nis;

  const AbsenPreview({super.key, required this.nis});

  @override
  State<AbsenPreview> createState() => _AbsenPreviewState();
}

class _AbsenPreviewState extends State<AbsenPreview> {
  bool _isLoading = true;
  String _error = '';
  
  Map<String, dynamic>? _todayAbsen;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant AbsenPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nis != widget.nis) {
      _fetchData();
    }
  }
  Future<void> _fetchData() async {
    if (widget.nis == '...') {
      setState(() {
        _isLoading = true;
        _error = '';
      });
      return;
    }

    if (widget.nis.isEmpty || widget.nis == '-') {
      setState(() {
        _isLoading = false;
        _error = 'NIS tidak ditemukan';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final db = DbAbsensi();
      final data = await db.getAbsensi(widget.nis);

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      Map<String, dynamic>? today;

      for (var row in data) {
        final dateStr = row['date'].toString();
        
        // Cek hari ini
        if (dateStr == todayStr || dateStr.startsWith(todayStr)) {
          today = row;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _todayAbsen = today;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hadir': return Colors.green;
      case 'izin': return Colors.blue;
      case 'sakit': return Colors.orange;
      case 'alpha': return Colors.red;
      case 'terlambat': return Colors.amber;
      case 'libur': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(
          'Gagal memuat absensi: $_error',
          style: TextStyle(color: Colors.red.shade700, fontFamily: 'Inter'),
        ),
      );
    }

    final todayStatus = _todayAbsen != null ? DbAbsensi.getStatus(_todayAbsen!) : 'Belum Absen';
    final masuk = _todayAbsen?['masuk'] ?? '--:--';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Absen Hari Ini
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Absensi Hari Ini',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(DateTime.now()),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Konten Hari Ini
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeBox('Masuk', masuk, Icons.login, Colors.green),
                Column(
                  children: [
                    const Text('Status', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    _buildStatusBadge(todayStatus),
                  ],
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildTimeBox(String label, String time, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          time,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
