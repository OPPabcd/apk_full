import 'package:flutter/material.dart';
import 'package:apk/dashboard/d_guru/database/db_kelas.dart';
import 'package:apk/dashboard/a_admin/widget/custom_button.dart';
import 'package:apk/dashboard/d_guru/database/db_guru.dart';
import 'package:apk/dashboard/d_guru/database/db_namasekolah.dart';
import 'package:apk/dashboard/d_guru/function/detail_murid/detail_murid.dart';
import 'package:apk/error_handler/connection.dart';

class MuridPage extends StatefulWidget {
  const MuridPage({super.key});

  @override
  State<MuridPage> createState() => _MuridPageState();
}

class _MuridPageState extends State<MuridPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> _allMurid = [];
  bool isSearchActive = false;
  String? searchQuery;
  String namaSekolah = "Memuat..."; 
  String namaKelas = ""; 

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    bool hasConnection = await ConnectionHandler.checkConnection();
    if (!hasConnection) {
      if (mounted) {
        ConnectionHandler.showNoConnectionDialog(
          context: context,
          onRetry: () => fetchData(),
        );
        setState(() => isLoading = false);
      }
      return;
    }
    try {
      final data = await DbKelas().getMuridForGuru();
      
      String className = "Tidak Terdaftar";
      try {
        final guruData = await DbGuru().getLoggedInGuruInfo();
        if (guruData['class_name'] != null && guruData['class_name'].toString().isNotEmpty) {
          className = "${guruData['class_name']}";
        }
      } catch (e) {
        // Abaikan jika gagal ambil info guru
      }

      String fetchedSekolah = "Tidak Terdaftar";
      try {
        final schoolName = await NamaSekolahService.getNamaSekolah();
        if (schoolName != null && schoolName.isNotEmpty) {
          fetchedSekolah = schoolName;
        }
      } catch (e) {
        // Abaikan jika gagal ambil nama sekolah
      }

      if (mounted) {
        setState(() {
          _allMurid = data;
          namaSekolah = fetchedSekolah;
          namaKelas = className;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int dataCount = _allMurid.length;

    // Apply search filter
    final keyword = (searchQuery ?? '').toLowerCase();
    final muridList = _allMurid.where((murid) {
      final nama = murid['nama']?.toString().toLowerCase() ?? '';
      final nis = murid['nis']?.toString().toLowerCase() ?? '';
      return nama.contains(keyword) || nis.contains(keyword);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2563EB),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: Container(
            height: 45,
            width: double.infinity,
            color: const Color(0xFF2563EB),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        namaKelas.isNotEmpty ? "Daftar Murid  |  $namaKelas" : "Daftar Murid",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$dataCount murid terdaftar",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    setState(() => isLoading = true);
                    fetchData();
                  },
                ),
              ],
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          // SEARCH BAR
          Container(
            height: 70,
            color: const Color(0xFF2563EB),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: isSearchActive
                    ? TextField(
                        autofocus: true,
                        onChanged: (value) {
                          setState(() => searchQuery = value);
                        },
                        decoration: InputDecoration(
                          hintText: "Cari nama atau NIS...",
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFCCCCCC),
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          prefixIcon: IconButton(
                            icon: const Icon(Icons.arrow_back, size: 18),
                            onPressed: () {
                              setState(() {
                                isSearchActive = false;
                                searchQuery = null;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Transform.translate(
                            offset: const Offset(-12, 0),
                            child: IconButton(
                              icon: const Icon(Icons.search, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  isSearchActive = true;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: Text(
                              namaSekolah,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontFamily: "Inter",
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // CONTENT
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allMurid.isEmpty
                    ? const Center(child: Text('Belum ada murid di kelas Anda.'))
                    : muridList.isEmpty
                        ? const Center(child: Text('Pencarian tidak ditemukan.'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: muridList.length,
                            itemBuilder: (context, index) {
                              final murid = muridList[index];
                              final nama = murid['nama']?.toString() ?? 'Tanpa Nama';
                              final nis = murid['nis']?.toString() ?? '-';
                              
                              return CustomCard(
                                title: nama,
                                subtitle: 'NIS: $nis',
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                                subtitleStyle: const TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                                backgroundColor: Colors.white,
                                borderColor: Colors.transparent,
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DetailMuridPage(data: murid),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}