import 'package:flutter/material.dart';
import 'package:apk/dashboard/d_guru/database/db_guru.dart';
import 'package:apk/dashboard/a_admin/widget/custom_button.dart';

import 'package:apk/dashboard/d_guru/function/d_guru/daftar_guru.dart';
import 'package:apk/dashboard/d_guru/function/setting_p/setting_p.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apk/error_handler/connection.dart';

class GuruPage extends StatefulWidget {
  const GuruPage({super.key});

  @override
  State<GuruPage> createState() => _GuruPageState();
}

class _GuruPageState extends State<GuruPage> {
  final DbGuru _dbGuru = DbGuru();
  List<Map<String, dynamic>> guruList = [];
  bool isLoading = true;
  String? errorMessage;

  String guruName = 'Memuat...';
  String guruNik = '...';
  bool isWaliKelas = false;
  String? className;
  bool isLoadingGuru = true;
  Map<String, dynamic>? _rawGuruData;

  @override
  void initState() {
    super.initState();
    _fetchGuruData();
    loadData();
  }

  Future<void> _fetchGuruData() async {
    bool hasConnection = await ConnectionHandler.checkConnection();
    if (!hasConnection) {
      if (mounted) {
        ConnectionHandler.showNoConnectionDialog(
          context: context,
          onRetry: () => _fetchGuruData(),
        );
        setState(() {
          guruName = 'Tidak Ada Koneksi';
          isLoadingGuru = false;
        });
      }
      return;
    }
    try {
      final guruData = await _dbGuru.getLoggedInGuruInfo();
      if (mounted) {
        setState(() {
          _rawGuruData = guruData;
          String? nameValue;
          for (var key in guruData.keys) {
            if (key.toLowerCase().contains('nama') || key.toLowerCase().contains('name')) {
              nameValue = guruData[key].toString();
              break;
            }
          }
          guruName = nameValue ?? 'Tanpa Nama';
          guruNik = guruData['nik']?.toString() ?? '-';
          isWaliKelas = guruData['is_wali_kelas'] ?? false;
          className = guruData['class_name'];
          isLoadingGuru = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          guruName = 'Error memuat profil';
          guruNik = '-';
          isLoadingGuru = false;
        });
      }
    }
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline, color: Color(0xFF1E293B)),
                title: const Text('Setting Profil', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(context); // Close bottom sheet
                  if (_rawGuruData != null) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettingProfilPage(data: _rawGuruData!),
                      ),
                    );
                    _fetchGuruData(); // Refresh data after returning
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Data profil belum siap.')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context); // Close bottom sheet
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    await Supabase.instance.client.auth.signOut();
                    
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal logout: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentNik = prefs.getString('guru_nik');
      
      final data = await _dbGuru.getGuruForLoggedGuruClass();
      
      setState(() {
        guruList = data.where((g) => g['nik'].toString() != currentNik).toList();
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  String safe(dynamic value) {
    if (value == null || value.toString().isEmpty) return "N/A";
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text("Manajemen Guru"),
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
                setState(() {
                  isLoading = true;
                  isLoadingGuru = true;
                  errorMessage = null;
                });
                _fetchGuruData();
                loadData();
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // GURU INFO CARD
          Container(
            color: const Color(0xFF2563EB), // Extend the blue background slightly
            padding: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    
                    const SizedBox(width: 16),
                    
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guruName,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'NIK/NIP: $guruNik',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isWaliKelas ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isWaliKelas ? 'Wali Kelas ${className ?? ''}' : 'Bukan Wali Kelas',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isWaliKelas ? const Color(0xFF059669) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Settings Icon
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Color(0xFF64748B)),
                      onPressed: () => _showSettingsBottomSheet(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            "Terjadi Kesalahan:\n$errorMessage",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red, fontFamily: 'Inter'),
                          ),
                        ),
                      )
                    : guruList.isEmpty
                        ? const Center(
                            child: Text(
                              "Belum ada data guru",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              const SizedBox(height: 12),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: guruList.length,
                                  itemBuilder: (context, index) {
                                    final g = guruList[index];
                                    final nama = safe(g['name']);
                                    final nik = safe(g['nik']);
                                    final isWali = g['wali'] == true;
                                    
                                    final classNameObj = g['class_name'];
                                    String kelas = 'Belum ada kelas';
                                    
                                    if (classNameObj != null) {
                                      if (classNameObj is List && classNameObj.isNotEmpty) {
                                        kelas = classNameObj[0]['name_class']?.toString() ?? 'Belum ada kelas';
                                      } else if (classNameObj is Map) {
                                        kelas = classNameObj['name_class']?.toString() ?? 'Belum ada kelas';
                                      }
                                    }

                                    final bidang = safe(g['bidang']);
                                    final detail = isWali
                                        ? 'Wali Kelas: $kelas'
                                        : 'Bidang: $bidang';

                                    return Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 0,
                                          ),
                                          child: CustomCard(
                                            title: nama,
                                            subtitle: 'NIK: $nik\n$detail',
                                            backgroundColor: Colors.white,
                                            borderColor: Colors.transparent,
                                            borderWidth: 0,
                                            margin: EdgeInsets.zero,
                                            onTap: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => DetailGuruPage(data: g),
                                                ),
                                              );
                                              loadData();
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}
