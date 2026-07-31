import 'package:apk/dashboard/a_admin/function/f_murid/detai_murid.dart';
import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/database/db_siswa.dart';
import 'package:apk/dashboard/a_admin/widget/custom_button.dart';

import 'package:apk/dashboard/a_admin/function/f_murid/false_delete.dart';

class MuridPage extends StatefulWidget {
  final bool isSelectionMode;
  const MuridPage({super.key, this.isSelectionMode = false});

  @override
  State<MuridPage> createState() => _MuridPageState();
}

class _MuridPageState extends State<MuridPage> {
  final MuridService service = MuridService();

  List<Map<String, dynamic>> muridList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  String? errorMessage;

  Future<void> loadData() async {
    try {
      final data = await service.getMurid();
      setState(() {
        muridList = data;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
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
        title: const Text("Manajemen Murid"),
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
                MaterialPageRoute(builder: (_) => const FalseDeleteMuridPage()),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      "Terjadi Kesalahan:\n$errorMessage",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : muridList.isEmpty
                  ? const Center(
                      child: Text(
                        "Belum ada data murid",
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
                            itemCount: muridList.length,
                            itemBuilder: (context, index) {
                              final m = muridList[index];
                              final nama = safe(m['nama']);
                              final nis = safe(m['nis']);
                              final kelas =
                                  m['class_name']?['name_class'] ??
                                      'Belum ada kelas';

                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
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
                                            'NIS: $nis',
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
                                              'Kelas: $kelas',
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
                                      //padding: const EdgeInsets.all(20),
                                      onTap: () async {
                                        if (widget.isSelectionMode) {
                                          Navigator.pop(context, m);
                                          return;
                                        }
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                DetailMuridPage(data: m),
                                          ),
                                        );

                                        // refresh setelah balik
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