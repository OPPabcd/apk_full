import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:apk/dashboard/d_guru/database/db_kelas.dart';
import 'package:apk/dashboard/d_guru/database/db_namasekolah.dart';
import 'package:apk/dashboard/d_guru/function/absen_excel/daftar_absen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apk/dashboard/a_admin/widget/custom_button.dart';
import 'package:apk/dashboard/d_guru/function/absensi_baru/form_daftar_absen.dart';
import 'package:apk/dashboard/d_guru/function/absensi_baru/daftar_absen.dart' as absen_baru;
import 'package:apk/error_handler/connection.dart';

class Absensi extends StatefulWidget {
  const Absensi({super.key});

  @override
  State<Absensi> createState() => _AbsensiState();
}

class _AbsensiState extends State<Absensi> {
  final DbKelas _dbKelas = DbKelas();
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _muridList = [];
  String _namaKelas = '-';
  String _namaWaliKelas = '-';
  String _nikWaliKelas = '-';
  String _wilayah = '';
  String _namaSekolah = '';

  // Generate list bulan
  final List<DateTime> _months = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    await initializeDateFormatting('id_ID', null);

    bool hasConnection = await ConnectionHandler.checkConnection();
    if (!hasConnection) {
      if (mounted) {
        ConnectionHandler.showNoConnectionDialog(
          context: context,
          onRetry: () => _initData(),
        );
        setState(() {
          _errorMessage = 'Tidak ada koneksi internet';
          _isLoading = false;
        });
      }
      return;
    }
    
    try {
      final supabase = Supabase.instance.client;
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id_admin');
      final nik = prefs.getString('guru_nik');
      _nikWaliKelas = nik ?? '-';

      if (userId == null || nik == null) {
        setState(() {
          _errorMessage = 'Sesi tidak valid';
          _isLoading = false;
        });
        return;
      }

      // 1. Dapatkan info guru yang login
      final guruData = await supabase
          .from('guru')
          .select('id_tabel, id_class')
          .eq('user_id', userId)
          .eq('nik', nik)
          .maybeSingle();

      if (guruData == null) {
         setState(() {
          _errorMessage = 'Data guru tidak ditemukan';
          _isLoading = false;
        });
        return;
      }

      final guruIdTabel = guruData['id_tabel'];
      final guruIdClass = guruData['id_class'];

      // 2. Cari tanggal dibuatnya kelas (created_at paling awal dari kelas yang terhubung)
      DateTime? earliestCreatedAt;

      // Cek kelas dari relasi id_guru di tabel class_name
      final classDataList = await supabase
          .from('class_name')
          .select('id_tabel, name_class, created_at, id_class')
          .eq('id_guru', guruIdTabel);
          
      for (var c in classDataList) {
        if (c['created_at'] != null) {
          final createdAt = DateTime.parse(c['created_at'].toString());
          if (earliestCreatedAt == null || createdAt.isBefore(earliestCreatedAt)) {
            earliestCreatedAt = createdAt;
          }
        }
      }

      // Jika guru ini bukan wali kelas, cek dari id_class-nya
      if (guruIdClass != null && earliestCreatedAt == null) {
         final classData = await supabase
          .from('class_name')
          .select('created_at')
          .eq('id_tabel', guruIdClass)
          .maybeSingle();
         if (classData != null && classData['created_at'] != null) {
            earliestCreatedAt = DateTime.parse(classData['created_at'].toString());
         }
      }

      // 3. Generate bulan dari earliestCreatedAt hingga sekarang
      _months.clear();
      final now = DateTime.now();
      
      if (earliestCreatedAt != null) {
        int startYear = earliestCreatedAt.year;
        int startMonth = earliestCreatedAt.month;
        int currentYear = now.year;
        int currentMonth = now.month;

        for (int y = currentYear; y >= startYear; y--) {
           int mStart = (y == startYear) ? startMonth : 1;
           int mEnd = (y == currentYear) ? currentMonth : 12;
           for (int m = mEnd; m >= mStart; m--) {
             _months.add(DateTime(y, m, 1));
           }
        }
      } else {
        // Fallback jika tidak ditemukan kelas
        _months.add(DateTime(now.year, now.month, 1));
      }

      // Ambil nama sekolah dan wilayah
      final sekolahInfo = await NamaSekolahService.getSekolahInfo();
      _namaSekolah = sekolahInfo['sekolah'] ?? '';
      _wilayah = sekolahInfo['wilayah'] ?? '';

      // 4. Ambil data murid
      final murid = await _dbKelas.getMuridForGuru();

      // 5. Ambil nama kelas dan nama wali kelas
      String namaKelas = '-';
      String namaWaliKelas = '-';

      // Ambil nama kelas dari class_name (dari guru yang login sebagai wali kelas)
      if (classDataList.isNotEmpty) {
        final kelasRow = classDataList.first;
        if (kelasRow['name_class'] != null) {
          namaKelas = kelasRow['name_class'].toString();
        }
      } else if (guruIdClass != null) {
        // Fallback: guru bukan wali kelas tapi punya id_class
        final kelasData = await supabase
            .from('class_name')
            .select('name_class')
            .eq('id_tabel', guruIdClass)
            .maybeSingle();
        if (kelasData != null && kelasData['name_class'] != null) {
          namaKelas = kelasData['name_class'].toString();
        }
      }

      // Ambil nama wali kelas (nama guru yang login)
      final guruNamaRow = await supabase
          .from('guru')
          .select('name')
          .eq('user_id', userId)
          .eq('nik', nik)
          .maybeSingle();
      if (guruNamaRow != null && guruNamaRow['name'] != null) {
        namaWaliKelas = guruNamaRow['name'].toString();
      }

      setState(() {
        _muridList = murid;
        _namaKelas = namaKelas;
        _namaWaliKelas = namaWaliKelas;
        _isLoading = false;
        _errorMessage = null;
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Rekap Absensi Kelas'),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                _initData();
              },
            ),
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
                    _buildAbsensiBaruMenu(),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Rekap Bulanan", style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      ),
                    ),
                    Expanded(
                      child: _muridList.isEmpty
                          ? _buildEmptyState()
                          : _buildMonthList(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildAbsensiBaruMenu() {
    return Column(
      children: [
        const SizedBox(height: 16),
        CustomCard(
          title: "Buat Absensi",
          subtitle: "Buat sesi absensi baru (Misal: Ujian/Pelajaran)",
          icon: Icons.add_circle_outline,
          iconColor: const Color(0xFF2563EB),
          backgroundColor: Colors.white,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FormDaftarAbsenPage()),
            );
          },
        ),
        CustomCard(
          title: "Lihat Daftar",
          subtitle: "Daftar sesi absensi yang telah dibuat",
          icon: Icons.list_alt,
          iconColor: const Color(0xFF10B981),
          backgroundColor: Colors.white,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const absen_baru.DaftarAbsenSesiPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Tidak Ada Murid',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Anda belum memiliki murid di kelas Anda.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _months.length,
      itemBuilder: (context, index) {
        final date = _months[index];
        final monthName = DateFormat('MMMM yyyy', 'id_ID').format(date);
        // Format YYYY-MM untuk query ke database
        final yearMonth = DateFormat('yyyy-MM').format(date);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DaftarAbsenExcelPage(
                    monthName: monthName,
                    yearMonth: yearMonth,
                    muridList: _muridList,
                    namaKelas: _namaKelas,
                    namaWaliKelas: _namaWaliKelas,
                    nipWaliKelas: _nikWaliKelas,
                    wilayah: _wilayah,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.calendar_month, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rekap $monthName',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_muridList.length} Siswa',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
