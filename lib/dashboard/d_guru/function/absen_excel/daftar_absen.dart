import 'package:flutter/material.dart';
import 'package:apk/dashboard/d_guru/function/absen_excel/download.dart';
import 'package:apk/dashboard/d_guru/database/db_absensi.dart';
import 'package:apk/dashboard/d_guru/database/db_namasekolah.dart';
import 'package:apk/dashboard/d_guru/function/absen_excel/pdf/pdf_export_service.dart';
import 'package:apk/dashboard/d_guru/function/absen_excel/pdf/export_pdf_button.dart';
import 'package:apk/dashboard/d_guru/database/holiday_service.dart';
import 'package:apk/dashboard/d_guru/function/absen_excel/setting_L/pengaturan_absen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DaftarAbsenExcelPage extends StatefulWidget {
  final String monthName;
  final String yearMonth;
  final List<Map<String, dynamic>> muridList;
  final String namaKelas;
  final String namaWaliKelas;
  final String nipWaliKelas;
  final String wilayah;

  const DaftarAbsenExcelPage({
    super.key,
    required this.monthName,
    required this.yearMonth,
    required this.muridList,
    this.namaKelas = '-',
    this.namaWaliKelas = '-',
    this.nipWaliKelas = '-',
    this.wilayah = '',
  });

  @override
  State<DaftarAbsenExcelPage> createState() => _DaftarAbsenExcelPageState();
}

class _DaftarAbsenExcelPageState extends State<DaftarAbsenExcelPage> {
  final DbAbsensi _dbAbsensi = DbAbsensi();
  bool _isLoading = true;
  String? _errorMessage;
  String _namaSekolah = '';

  // ScrollControllers untuk Scrollbar (wajib saat thumbVisibility: true)
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  // Struktur data: attendanceMap[nisStr][day] = status
  final Map<String, Map<int, String>> _attendanceMap = {};
  // Map composite key "${idMurid}_$day" -> idTabel of the record
  final Map<String, String> _absenIdMap = {};
  int _daysInMonth = 31;

  String get _cacheKey => 'cache_absen_${widget.yearMonth}_${widget.namaKelas}';

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDataStr = prefs.getString(_cacheKey);
      if (cachedDataStr != null) {
        final Map<String, dynamic> cachedJson = jsonDecode(cachedDataStr);
        
        // Restore attendance map
        final Map<String, dynamic> rawAttMap = cachedJson['attendanceMap'] ?? {};
        _attendanceMap.clear();
        rawAttMap.forEach((nis, daysObj) {
          final Map<int, String> dayMap = {};
          if (daysObj is Map) {
            daysObj.forEach((dayStr, status) {
              final dayInt = int.tryParse(dayStr);
              if (dayInt != null) {
                dayMap[dayInt] = status.toString();
              }
            });
          }
          _attendanceMap[nis] = dayMap;
        });

        // Restore absen ID map
        final Map<String, dynamic> rawIdMap = cachedJson['absenIdMap'] ?? {};
        _absenIdMap.clear();
        rawIdMap.forEach((key, val) {
          _absenIdMap[key] = val.toString();
        });

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert attendance map day keys from int to String for JSON encoding
      final Map<String, Map<String, String>> jsonAttMap = {};
      _attendanceMap.forEach((nis, dayMap) {
        final Map<String, String> strDayMap = {};
        dayMap.forEach((day, status) {
          strDayMap[day.toString()] = status;
        });
        jsonAttMap[nis] = strDayMap;
      });

      final Map<String, dynamic> cacheData = {
        'attendanceMap': jsonAttMap,
        'absenIdMap': _absenIdMap,
      };

      await prefs.setString(_cacheKey, jsonEncode(cacheData));
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = _attendanceMap.isEmpty);
    await _loadFromCache();
    _syncInBackground();
  }

  Future<void> _syncInBackground() async {
    try {
      // Ambil nama sekolah
      final sekolah = await NamaSekolahService.getNamaSekolah();
      _namaSekolah = sekolah ?? '';

      int year = DateTime.now().year;
      int month = DateTime.now().month;
      // Hitung jumlah hari dalam bulan ini
      final parts = widget.yearMonth.split('-');
      if (parts.length == 2) {
        year = int.parse(parts[0]);
        month = int.parse(parts[1]);
        _daysInMonth = DateTime(year, month + 1, 0).day;
      }

      // Ambil daftar NIS (sebagai String agar tidak crash jika DB mengembalikan String)
      final List<String> listNis = widget.muridList
          .map((m) => m['nis']?.toString())
          .where((nis) => nis != null && nis.isNotEmpty)
          .cast<String>()
          .toList();

      if (listNis.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // Generate rekap bulan ini jika belum ada (hanya insert baris kosong, tidak overwrite)
      // Kirim muridList langsung agar filter per kelas benar
      await _dbAbsensi.generateMonthlyRekap(widget.yearMonth, widget.muridList);

      // Kumpulkan id_murid untuk sync kelas ini
      final List<String> listIdMuridStr = widget.muridList
          .map((mu) => mu['id_tabel']?.toString())
          .where((id) => id != null)
          .cast<String>()
          .toList();

      // Sync otomatis saat pertama buka: data dari output_alat/access_bridge langsung masuk ke absen
      // (user tidak perlu klik Refresh manual)
      if (listIdMuridStr.isNotEmpty) {
        await _dbAbsensi.syncMonthlyRekap(widget.yearMonth, listIdMuridStr);
      }

      // Tampilkan data rekap
      await _loadData(year: year, month: month);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat rekap tabel: $e';
          _isLoading = false;
        });
      }
    }
  }


  /// Hanya fetch + tampilkan data dari DB tanpa menjalankan sync.
  /// Dipanggil setelah manual update agar perubahan manual tidak tertimpa sync.
  Future<void> _loadData({int? year, int? month}) async {
    try {
      // Tentukan tahun & bulan jika belum ada
      int y = year ?? DateTime.now().year;
      int m = month ?? DateTime.now().month;
      final parts = widget.yearMonth.split('-');
      if (parts.length == 2) {
        y = int.parse(parts[0]);
        m = int.parse(parts[1]);
        _daysInMonth = DateTime(y, m + 1, 0).day;
      }

      final List<String> nisList = widget.muridList
          .map((mu) => mu['nis']?.toString())
          .where((nis) => nis != null && nis.isNotEmpty)
          .cast<String>()
          .toList();

      _absenIdMap.clear();

      // Inisialisasi map default (key = nis sebagai String)
      for (var nisStr in nisList) {
        _attendanceMap[nisStr] = {};
        for (int i = 1; i <= _daysInMonth; i++) {
          final date = DateTime(y, m, i);
          if (date.weekday == DateTime.sunday || HolidayService.isHoliday(date)) {
            _attendanceMap[nisStr]![i] = 'L';
          } else {
            _attendanceMap[nisStr]![i] = '-';
          }
        }
      }

      // Kumpulkan id_murid dari muridList untuk query rekap
      final List<String> listIdMuridStr = widget.muridList
          .map((mu) => mu['id_tabel']?.toString())
          .where((id) => id != null)
          .cast<String>()
          .toList();

      final rekapRecords = await _dbAbsensi.getMonthlyRekapData(
          widget.yearMonth, listIdMuridStr);

      // Build lookup id_murid -> nis (String)
      final Map<String, String> idMuridToNis = {};
      for (var mu in widget.muridList) {
        final id = mu['id_tabel']?.toString();
        final nisStr = mu['nis']?.toString();
        if (id != null && nisStr != null && nisStr.isNotEmpty) {
          idMuridToNis[id] = nisStr;
        }
      }

      // Mapping data rekap ke _attendanceMap
      for (var record in rekapRecords) {
        final idMurid = record['id_murid']?.toString();
        if (idMurid == null) continue;
        final nisStr = idMuridToNis[idMurid];
        if (nisStr == null) continue;
        final dateStr = record['date']?.toString();
        if (dateStr == null) continue;

        try {
          final date = DateTime.parse(dateStr);
          if (date.year != y || date.month != m) continue;
          final day = date.day;

          final idTabel = record['id_tabel']?.toString();
          if (idTabel != null) {
            _absenIdMap['${idMurid}_$day'] = idTabel;
          }

          if (_attendanceMap.containsKey(nisStr) && day >= 1 && day <= _daysInMonth) {
            String shortStatus = '-';
            if (record['Null_data']?.toString() == 'Belum Absen') {
              shortStatus = '-';
            } else if (record['ket_libur'] != null && record['ket_libur'].toString().isNotEmpty) {
              shortStatus = 'L';
            } else if (record['ket_sakit'] != null && record['ket_sakit'].toString().isNotEmpty) {
              shortStatus = 'S';
            } else if (record['ket_izin'] != null && record['ket_izin'].toString().isNotEmpty) {
              shortStatus = 'I';
            } else if (record['ket_alpha'] != null && record['ket_alpha'].toString().isNotEmpty) {
              shortStatus = 'A';
            } else if (record['ket_hadir'] != null && record['ket_hadir'].toString().isNotEmpty) {
              shortStatus = 'H'; // Terlambat tetap dihitung sebagai Hadir
            }
            _attendanceMap[nisStr]![day] = shortStatus;
          }
        } catch (_) {}
      }

      await _saveToCache();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat rekap tabel: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncAndReload() async {
    setState(() => _isLoading = true);
    try {
      // Kumpulkan id_murid untuk sync hanya kelas ini
      final List<String> listIdMuridStr = widget.muridList
          .map((mu) => mu['id_tabel']?.toString())
          .where((id) => id != null)
          .cast<String>()
          .toList();
      await _dbAbsensi.syncMonthlyRekap(widget.yearMonth, listIdMuridStr);
      await _loadData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal sync data: $e';
          _isLoading = false;
        });
      }
    }
  }

  // Menghitung rekap per siswa
  int _countStatus(String nisStr, String shortStatus) {
    if (!_attendanceMap.containsKey(nisStr)) return 0;
    int count = 0;
    for (int i = 1; i <= _daysInMonth; i++) {
      final status = _attendanceMap[nisStr]![i] ?? '-';
      if (status.startsWith(shortStatus)) count++;
    }
    return count;
  }

  // Mewarnai sel berdasarkan status
  Color _getCellColor(String status) {
    if (status.startsWith('H')) return Colors.green.withOpacity(0.2);
    if (status.startsWith('S')) return Colors.blue.withOpacity(0.2);
    if (status.startsWith('I')) return Colors.orange.withOpacity(0.2);
    if (status.startsWith('A')) return Colors.red.withOpacity(0.2);
    if (status.startsWith('T')) return Colors.purple.withOpacity(0.2);
    if (status.startsWith('L')) return Colors.red.withOpacity(0.15);
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        title: Text('Rekap ${widget.monthName}'),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Pembaruan Massal',
            onPressed: () {
              final allStudents = widget.muridList
                  .map((m) => m['id_tabel']?.toString())
                  .whereType<String>()
                  .toList();
              final allDays = List.generate(_daysInMonth, (i) => i + 1);

              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => UpdateAbsenBottomSheet(
                  muridList: widget.muridList,
                  daysInMonth: _daysInMonth,
                  yearMonth: widget.yearMonth,
                  absenIdMap: _absenIdMap,
                  initialSelectedStudentIds: allStudents,
                  initialSelectedDays: allDays,
                  onUpdated: _loadData,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Sync Data',
            onPressed: _isLoading ? null : _syncAndReload,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontFamily: 'Inter')),
                  ),
                )
              : Column(
                  children: [
                    // Kop Judul di dalam halaman (seperti foto Excel)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.black12, width: 1)),
                      ),
                      child: Column(
                        children: [
                          if (_namaSekolah.isNotEmpty) ...[
                            Text(
                              _namaSekolah.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          const Text(
                            'ABSENSI SISWA',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'BULAN : ${widget.monthName.toUpperCase()}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Info Kelas & Jumlah Murid (kiri atas tabel)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Kelas', widget.namaKelas),
                            const SizedBox(height: 4),
                            _buildInfoRow('Jumlah Murid', '${widget.muridList.length} Siswa'),
                          ],
                        ),
                      ),
                    ),

                    // Tombol Download Excel & PDF
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _downloadExcel,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A), // Hijau untuk Excel
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.grid_on, color: Colors.white, size: 18),
                              label: const Text(
                                'Download Excel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ExportPdfButton(
                              onExport: _downloadPdf,
                              style: ExportButtonStyle.elevated,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tabel Data
                    Expanded(child: _buildExcelTable()),

                    // Area Tanda Tangan Wali Kelas
                    _buildSignatureSection(),
                  ],
                ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        const Text(
          ': ',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildSignatureSection() {
    final now = DateTime.now();
    final tanggal =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
    final lokasiTanggal =
        widget.wilayah.isNotEmpty ? '${widget.wilayah}, $tanggal' : tanggal;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.black12, width: 1)),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lokasiTanggal,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Wali Kelas,',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 60), // Ruang tanda tangan
              Text(
                widget.namaWaliKelas,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 200,
                height: 1,
                color: Colors.black54,
              ),
              const SizedBox(height: 4),
              Text(
                'NIP. ${widget.nipWaliKelas}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExcelTable() {
    if (widget.muridList.isEmpty) {
      return const Center(child: Text('Tidak ada data murid.', style: TextStyle(fontFamily: 'Inter')));
    }

    return Scrollbar(
      thumbVisibility: true,
      controller: _verticalScrollController,
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        scrollDirection: Axis.vertical,
        child: Scrollbar(
          thumbVisibility: true,
          controller: _horizontalScrollController,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildRawDataTable(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRawDataTable() {
    if (widget.muridList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('Tidak ada data murid.', style: TextStyle(fontFamily: 'Inter', color: Colors.black))),
      );
    }
    
    return DataTable(
      showCheckboxColumn: false,
      headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
      columnSpacing: 16,
      horizontalMargin: 8,
      dataRowMinHeight: 35,
      dataRowMaxHeight: 45,
      headingRowHeight: 45,
      border: TableBorder.all(color: Colors.grey.withOpacity(0.5), width: 1),
      columns: [
        const DataColumn(label: Text('NO', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13))),
        const DataColumn(label: Text('NIS', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13))),
        const DataColumn(label: Text('NAMA SISWA', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13))),
        const DataColumn(label: Text('L/P', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13))),
        
        // Kolom Tanggal 1 s/d 31 (Klik angka tanggal di header untuk pembaruan massal kolom/hari tersebut)
        ...List.generate(_daysInMonth, (i) {
          final d = i + 1;
          return DataColumn(
            label: InkWell(
              onTap: () {
                final allStudents = widget.muridList
                    .map((m) => m['id_tabel']?.toString())
                    .whereType<String>()
                    .toList();

                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => UpdateAbsenBottomSheet(
                    muridList: widget.muridList,
                    daysInMonth: _daysInMonth,
                    yearMonth: widget.yearMonth,
                    absenIdMap: _absenIdMap,
                    initialSelectedStudentIds: allStudents,
                    initialSelectedDays: [d],
                    onUpdated: _loadData,
                  ),
                );
              },
              child: Container(
                width: 22,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('$d', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13)),
              ),
            ),
          );
        }),
        
        // Kolom Rekap (Keterangan)
        const DataColumn(
          label: SizedBox(
            width: 22,
            child: Center(
              child: Text('S', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13, color: Colors.blue)),
            ),
          ),
        ),
        const DataColumn(
          label: SizedBox(
            width: 22,
            child: Center(
              child: Text('I', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13, color: Colors.orange)),
            ),
          ),
        ),
        const DataColumn(
          label: SizedBox(
            width: 22,
            child: Center(
              child: Text('A', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13, color: Colors.red)),
            ),
          ),
        ),
      ],
      rows: List.generate(widget.muridList.length, (index) {
        final m = widget.muridList[index];
        final nisStr = m['nis']?.toString();
        final idMurid = m['id_tabel']?.toString();
        
        // Cells standar (Identitas - Klik nama murid untuk update massal seluruh bulan/baris)
        final cells = <DataCell>[
          DataCell(Text('${index + 1}', style: const TextStyle(fontFamily: 'Inter', fontSize: 12))),
          DataCell(Text(nisStr ?? '-', style: const TextStyle(fontFamily: 'Inter', fontSize: 12))),
          DataCell(
            InkWell(
              onTap: () {
                if (idMurid == null) return;
                final allDays = List.generate(_daysInMonth, (i) => i + 1);

                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => UpdateAbsenBottomSheet(
                    muridList: widget.muridList,
                    daysInMonth: _daysInMonth,
                    yearMonth: widget.yearMonth,
                    absenIdMap: _absenIdMap,
                    initialSelectedStudentIds: [idMurid],
                    initialSelectedDays: allDays,
                    onUpdated: _loadData,
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m['nama']?.toString() ?? '-',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 10, color: Color(0xFF2563EB)),
                ],
              ),
            ),
          ),
          DataCell(
            Center(
              child: Text(
                m['gender']?.toString() ?? '-',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12),
              ),
            ),
          ),
        ];

        // Cells harian 1-31
        for (int d = 1; d <= _daysInMonth; d++) {
          String status = '-';
          if (nisStr != null && _attendanceMap.containsKey(nisStr)) {
            status = _attendanceMap[nisStr]![d] ?? '-';
          }
          final idTabel = idMurid != null ? _absenIdMap['${idMurid}_$d'] : null;

          cells.add(DataCell(
            InkWell(
              onTap: idTabel == null || idMurid == null
                  ? null
                  : () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (context) => UpdateAbsenBottomSheet(
                          muridList: widget.muridList,
                          daysInMonth: _daysInMonth,
                          yearMonth: widget.yearMonth,
                          absenIdMap: _absenIdMap,
                          initialSelectedStudentIds: [idMurid],
                          initialSelectedDays: [d],
                          onUpdated: _loadData,
                        ),
                      );
                    },
              child: Container(
                alignment: Alignment.center,
                width: double.infinity,
                height: double.infinity,
                color: _getCellColor(status),
                child: Text(
                  status,
                  style: TextStyle(
                    fontWeight: status != '-' ? FontWeight.bold : FontWeight.normal, 
                    fontFamily: 'Inter',
                    fontSize: 12,
                  ),
                ),
              ),
            )
          ));
        }

        // Cells rekapitulasi akhir
        String sVal = nisStr != null ? _countStatus(nisStr, 'S').toString() : '-';
        String iVal = nisStr != null ? _countStatus(nisStr, 'I').toString() : '-';
        String aVal = nisStr != null ? _countStatus(nisStr, 'A').toString() : '-';

        cells.add(DataCell(Container(color: Colors.blue.withOpacity(0.1), alignment: Alignment.center, width: double.infinity, height: double.infinity, child: Text(sVal, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')))));
        cells.add(DataCell(Container(color: Colors.orange.withOpacity(0.1), alignment: Alignment.center, width: double.infinity, height: double.infinity, child: Text(iVal, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')))));
        cells.add(DataCell(Container(color: Colors.red.withOpacity(0.1), alignment: Alignment.center, width: double.infinity, height: double.infinity, child: Text(aVal, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')))));

        return DataRow(
          cells: cells,
        );
      }),
    );
  }

  Future<void> _downloadExcel() async {
    await AbsensiExcelDownloader.downloadExcel(
      context: context,
      namaSekolah: _namaSekolah,
      monthName: widget.monthName,
      yearMonth: widget.yearMonth,
      namaKelas: widget.namaKelas,
      namaWaliKelas: widget.namaWaliKelas,
      nipWaliKelas: widget.nipWaliKelas,
      wilayah: widget.wilayah,
      muridList: widget.muridList,
      daysInMonth: _daysInMonth,
      attendanceMap: _attendanceMap,
      countStatus: _countStatus,
    );
  }

  Future<void> _downloadPdf() async {
    try {
      final fullPath = await PdfExportService.absensi(
        namaSekolah: _namaSekolah,
        monthName: widget.monthName,
        yearMonth: widget.yearMonth,
        namaKelas: widget.namaKelas,
        namaWaliKelas: widget.namaWaliKelas,
        nipWaliKelas: widget.nipWaliKelas,
        wilayah: widget.wilayah,
        muridList: widget.muridList,
        daysInMonth: _daysInMonth,
        attendanceMap: _attendanceMap,
        countStatus: _countStatus,
      );

      if (mounted) {
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
                    'PDF Berhasil Didownload',
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: ${fullPath.split('/').last}', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                const Text('Lokasi Penyimpanan:', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey)),
                Text(fullPath, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.black87)),
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
      rethrow;
    }
  }
}
