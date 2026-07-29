import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/database/db_guru.dart';
import 'package:apk/dashboard/a_admin/widget/custom_button.dart';
import 'package:apk/dashboard/a_admin/function/f_guru/detail_guru.dart';

import 'package:apk/dashboard/a_admin/function/f_guru/false_delete1.dart';

class GuruPage extends StatefulWidget {
  const GuruPage({super.key});

  @override
  State<GuruPage> createState() => _GuruPageState();
}

class _GuruPageState extends State<GuruPage> {
  List<Map<String, dynamic>> guruList = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final data = await GuruService.getGuru();
      setState(() {
        guruList = data;
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Image.asset('lib/assets/icons/Button.png', width: 30, height: 30),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: -5,
        title: const Text("Manajemen Guru"),
        titleTextStyle: const TextStyle(
          fontFamily: "Inter",
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore_from_trash, color: Colors.white),
            tooltip: 'Tempat Sampah',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FalseDeleteGuruPage()),
              );
              loadData();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    //padding: const EdgeInsets.all(16.0),
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                    child: Text(
                      "Terjadi Kesalahan:\n$errorMessage",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : guruList.isEmpty
                  ? const Center(
                      child: Text(
                        "Belum ada data guru",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
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
                              final kelas = g['class_name']?['name_class'] ??
                                  'Belum ada kelas';
                              final bidang = safe(g['bidang']);
                              final detail = isWali
                                  ? 'Wali Kelas: $kelas'
                                  : 'Bidang: $bidang';

                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 0,
                                    ),
                                    child: CustomCard(
                                      title: nama,
                                      titleStyle: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                      customSubtitle: Row(
                                        children: [
                                          Text(
                                            'NIK: $nik',
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 4,
                                            height: 4,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFCBD5E1),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              detail,
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF64748B),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      showIcon: false,
                                      backgroundColor: Colors.white,
                                      borderColor: Colors.transparent,
                                      borderWidth: 0,
                                      margin: EdgeInsets.zero,
                                      onTap: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                DetailGuruPage(data: g),
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
    );
  }
}
