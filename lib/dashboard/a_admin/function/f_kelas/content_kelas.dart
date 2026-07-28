import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/database/db_kelas.dart';
import 'package:apk/dashboard/a_admin/database/db_absen.dart';
import 'package:apk/dashboard/a_admin/widget/custom_button.dart';
import 'package:apk/dashboard/a_admin/function/f_kelas/update_kelas.dart';
import 'package:apk/dashboard/a_admin/function/f_murid/detai_murid.dart';
import 'package:apk/dashboard/a_admin/function/f_guru/detail_guru.dart';

class ContentKelas extends StatefulWidget {
  final Map<String, dynamic> classData;

  const ContentKelas({super.key, required this.classData});

  @override
  State<ContentKelas> createState() => _ContentKelasState();
}

class _ContentKelasState extends State<ContentKelas> {
  List<Map<String, dynamic>> muridList = [];
  List<Map<String, dynamic>> guruList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final String classId = widget.classData['id_tabel'];
      final resMurid = await ClassService.getMuridByClass(classId);
      final resGuru = await ClassService.getGuruByClass(classId);
      
      setState(() {
        muridList = resMurid ?? [];
        guruList = resGuru ?? [];
        isLoading = false;
      });
    } catch (e) {
      print(e);
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showPromoteDialog() async {
    if (muridList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tidak ada murid di kelas ini untuk dinaikkan tingkat.")),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Peringatan Naik Tingkat",
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red),
        ),
        content: const Text(
          "Proses naik tingkat kelas akan memindahkan seluruh murid ke kelas baru dan me-reset seluruh data absensi serta riwayat chat private mereka secara permanen.\n\nApakah Anda yakin ingin melanjutkan?",
          style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF1E293B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal", style: TextStyle(fontFamily: 'Inter', color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              "Lanjut",
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);
    try {
      final classes = await ClassService.getClasses();
      final currentClassId = widget.classData['id_tabel'];
      final otherClasses = classes.where((c) => c['id_tabel'] != currentClassId).toList();

      setState(() => isLoading = false);

      if (otherClasses.isEmpty) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Kelas Tujuan Tidak Ditemukan", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            content: const Text("Silakan buat kelas tujuan baru terlebih dahulu untuk menaikkan tingkat kelas ini."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK", style: TextStyle(fontFamily: 'Inter', color: Color(0xFF2563EB))),
              )
            ],
          ),
        );
        return;
      }

      String? selectedTargetClass;
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text(
                  "Naik Tingkat Kelas",
                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 18),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Pilih kelas tujuan untuk memindahkan seluruh murid di kelas ini:",
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedTargetClass,
                      hint: const Text(
                        "Pilih Kelas Tujuan",
                        style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFFC4C4C4)),
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      items: otherClasses.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['id_tabel'].toString(),
                          child: Text(
                            c['name_class'] ?? 'Tanpa Nama',
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedTargetClass = val;
                        });
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Batal", style: TextStyle(fontFamily: 'Inter', color: Color(0xFF64748B))),
                  ),
                  ElevatedButton(
                    onPressed: selectedTargetClass == null
                        ? null
                        : () {
                            Navigator.pop(context);
                            final targetClassObj = otherClasses.firstWhere((c) => c['id_tabel'].toString() == selectedTargetClass);
                            final targetStudentCount = (targetClassObj['murid'] as List? ?? []).length;
                            _confirmPromotion(
                              selectedTargetClass!,
                              targetClassObj['name_class'] ?? '',
                              targetStudentCount,
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      "Lanjut",
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal memuat kelas tujuan: $e")),
      );
    }
  }

  void _confirmPromotion(String targetClassId, String targetClassName, int targetStudentCount) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Konfirmasi Naik Tingkat",
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Apakah Anda yakin ingin memindahkan seluruh murid ke kelas '$targetClassName'?\n\nTindakan ini akan me-reset seluruh data absen dan riwayat chat private murid-murid tersebut secara permanen. Data murid itu sendiri tidak akan dihapus.",
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF1E293B)),
              ),
              if (targetStudentCount > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Peringatan: Kelas tujuan '$targetClassName' saat ini masih memiliki $targetStudentCount murid. Murid baru akan digabungkan dengan murid yang sudah ada di kelas tersebut.",
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal", style: TextStyle(fontFamily: 'Inter', color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => isLoading = true);
                try {
                  final studentIds = muridList.map((m) => m['id_tabel'].toString()).toList();
                  debugPrint("Promoting class for student IDs: $studentIds");
                  await AbsenService.promoteClass(
                    sourceClassId: widget.classData['id_tabel'].toString(),
                    targetClassId: targetClassId,
                    studentIds: studentIds,
                  );
                  debugPrint("AbsenService.promoteClass completed successfully");

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Berhasil menaikkan tingkat murid ke kelas '$targetClassName'"),
                      backgroundColor: Colors.green,
                    ),
                  );
                  debugPrint("Refreshing murid/guru lists...");
                  await loadData();
                  debugPrint("loadData completed");
                } catch (e) {
                  debugPrint("Exception during class promotion: $e");
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Gagal menaikkan tingkat kelas: $e")),
                  );
                } finally {
                  if (mounted) {
                    setState(() => isLoading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                "Ya, Proses",
                style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final nameClass = widget.classData['name_class'] ?? 'Tanpa Nama';
    
    String guruName = '-';
    if (widget.classData['guru'] is List) {
      final List gurus = widget.classData['guru'] as List;
      final waliGuru = gurus.firstWhere((g) => g['wali'] == true, orElse: () => null);
      if (waliGuru != null) {
        guruName = waliGuru['name']?.toString() ?? '-';
      }
    }

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
        title: Text(nameClass),
        titleTextStyle: const TextStyle(
          fontFamily: "Inter",
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        actions: [
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                widget.classData['tahun'] ?? '-',
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UpdateKelasPage(classData: widget.classData),
                    ),
                  ).then((result) {
                    if (result != null && result is Map<String, dynamic>) {
                      setState(() {
                        widget.classData['name_class'] = result['name_class'];
                        widget.classData['id_class'] = result['id_class'];
                        widget.classData['tahun'] = result['tahun'];
                      });
                    }
                    loadData(); // Refresh data after returning
                  });
                },
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
                    padding: const EdgeInsets.only(bottom: 20),
                    children: [
                      // --- BAGIAN GURU ---
                      if (guruList.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Daftar Guru",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ),
                        ...guruList.map((g) {
                          final isWali = g['wali'] == true;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            child: CustomCard(
                              title: g['name'] ?? 'Tanpa Nama',
                              titleStyle: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                              customSubtitle: Row(
                                children: [
                                  Text(
                                    isWali ? "Wali Kelas" : "Guru Mapel",
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
                                      'NIK: ${g['nik'] ?? '-'}',
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
                                    builder: (_) => DetailGuruPage(data: g),
                                  ),
                                );
                                loadData();
                              },
                            ),
                          );
                        }),
                      ],

                      // --- BAGIAN MURID ---
                      const Padding(
                        padding: EdgeInsets.only(left: 20.0, right: 20.0, top: 20, bottom: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Daftar Murid",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ),
                      if (muridList.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              "Belum ada murid di kelas ini",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ...muridList.map((m) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            child: CustomCard(
                              title: m['nama'] ?? 'Tanpa Nama',
                              titleStyle: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                              customSubtitle: Row(
                                children: [
                                  Text(
                                    'NIS: ${m['nis'] ?? '-'}',
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
                                  const Flexible(
                                    child: Text(
                                      'Siswa',
                                      style: TextStyle(
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
                                    builder: (_) => DetailMuridPage(data: m),
                                  ),
                                );
                                loadData();
                              },
                            ),
                          );
                        }),
                      if (muridList.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ElevatedButton.icon(
                            onPressed: _showPromoteDialog,
                            icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 18),
                            label: const Text(
                              "Naik Tingkat Kelas",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
    );
  }
}
