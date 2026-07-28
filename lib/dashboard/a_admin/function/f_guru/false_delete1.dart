import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/database/db_guru.dart';
import 'package:apk/dashboard/a_admin/widget/custom_button.dart';

class FalseDeleteGuruPage extends StatefulWidget {
  const FalseDeleteGuruPage({super.key});

  @override
  State<FalseDeleteGuruPage> createState() => _FalseDeleteGuruPageState();
}

class _FalseDeleteGuruPageState extends State<FalseDeleteGuruPage> {
  List<Map<String, dynamic>> deletedGuruList = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final data = await GuruService.getDeletedGuru();
      if (mounted) {
        setState(() {
          deletedGuruList = data;
          isLoading = false;
          errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> restoreGuru(String idTabel, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Pulihkan Guru"),
        content: Text("Apakah Anda yakin ingin memulihkan data guru $name?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text("Pulihkan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);
    try {
      await GuruService.restoreGuru(idTabel);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Data guru $name berhasil dipulihkan")),
        );
      }
      loadData();
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memulihkan: ${e.toString().replaceAll('Exception: ', '')}")),
        );
      }
    }
  }

  Future<void> deletePermanentlyGuru(String idTabel, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Permanen"),
        content: Text("Apakah Anda yakin ingin menghapus permanen data guru $name? Tindakan ini tidak dapat dibatalkan."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);
    try {
      await GuruService.deleteGuruPermanently(idTabel);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Data guru $name berhasil dihapus permanen")),
        );
      }
      loadData();
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menghapus: ${e.toString().replaceAll('Exception: ', '')}")),
        );
      }
    }
  }

  String safe(dynamic value) {
    if (value == null || value.toString().isEmpty) return "N/A";
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Image.asset('lib/assets/icons/Button.png', width: 30, height: 30),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: -5,
        title: const Text("Tempat Sampah Guru"),
        titleTextStyle: const TextStyle(
          fontFamily: "Inter",
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: loadData,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      Center(
                        child: Text(
                          "Terjadi Kesalahan:\n$errorMessage",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  )
                : deletedGuruList.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.35),
                          const Center(
                            child: Text(
                              "Tidak ada data guru yang dihapus",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: deletedGuruList.length,
                        itemBuilder: (context, index) {
                          final g = deletedGuruList[index];
                          final nama = safe(g['name']);
                          final nik = safe(g['nik']);
                          final bidang = safe(g['bidang']);

                          return Column(
                            children: [
                              if (index == 0) const SizedBox(height: 12),
                              CustomCard(
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
                                        'Bidang: $bidang',
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
                                customIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () => restoreGuru(g['id_tabel'], nama),
                                      borderRadius: BorderRadius.circular(20),
                                      child: const Padding(
                                        padding: EdgeInsets.all(6.0),
                                        child: Icon(Icons.restore, color: Colors.green, size: 22),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => deletePermanentlyGuru(g['id_tabel'], nama),
                                      borderRadius: BorderRadius.circular(20),
                                      child: const Padding(
                                        padding: EdgeInsets.all(6.0),
                                        child: Icon(Icons.delete_forever, color: Colors.red, size: 22),
                                      ),
                                    ),
                                  ],
                                ),
                                showIcon: true,
                                iconContainerSize: 80,
                                iconPadding: EdgeInsets.zero,
                                iconDecoration: const BoxDecoration(),
                                backgroundColor: Colors.white,
                                borderColor: Colors.transparent,
                                borderWidth: 0,
                                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                              ),
                            ],
                          );
                        },
                      ),
      ),
    );
  }
}
