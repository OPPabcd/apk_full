import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/database/db_guru.dart';
import 'package:apk/dashboard/a_admin/database/db_siswa.dart';
import 'package:apk/dashboard/a_admin/database/db_kelas.dart';
import 'package:apk/dashboard/a_admin/widget/custom_button.dart'; // Jika ingin menggunakan CustomCard, opsional.

class MemberSekolah extends StatefulWidget {
  const MemberSekolah({super.key});

  @override
  State<MemberSekolah> createState() => _MemberSekolahState();
}

class _MemberSekolahState extends State<MemberSekolah> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _listClass = [];
  List<Map<String, dynamic>> _listGuru = [];
  List<Map<String, dynamic>> _listMurid = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final classRes = await ClassService.getClasses();
      final guruRes = await GuruService.getGuru();
      final muridRes = await MuridService().getMurid();

      if (mounted) {
        setState(() {
          _listClass = classRes;
          _listGuru = guruRes;
          _listMurid = muridRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      backgroundColor: const Color(0xFF2563EB),
      elevation: 0,
      automaticallyImplyLeading: true,
      leading: IconButton(
        icon: Image.asset('lib/assets/icons/Button.png', width: 30, height: 30),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: -5,
      title: const Text('Anggota Grup Sekolah'),
      titleTextStyle: const TextStyle(
        fontFamily: "Inter",
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );

    if (_isLoading) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: _buildMemberList(),
    );
  }

  Widget _buildMemberList() {
    // Kita bisa mengelompokkan berdasarkan id_class
    // Tambahkan 1 kelas "Tanpa Kelas" jika ada yang id_class nya null
    List<Map<String, dynamic>> allClasses = List.from(_listClass);
    allClasses.add({
      'id_tabel': null,
      'name_class': 'Tanpa Kelas (Belum Dimasukkan Kelas)'
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allClasses.length,
      itemBuilder: (context, index) {
        final currentClass = allClasses[index];
        final classId = currentClass['id_tabel'];
        final className = currentClass['name_class'];

        // Filter Guru dan Murid untuk kelas ini
        final gurusInClass = _listGuru
            .where((g) => g['id_class'] == classId)
            .toList();
        final muridsInClass = _listMurid
            .where((m) => m['id_class'] == classId)
            .toList();

        if (gurusInClass.isEmpty && muridsInClass.isEmpty && classId == null) {
          return const SizedBox.shrink(); // Jangan tampilkan 'Tanpa Kelas' jika kosong
        }

        return ExpansionTile(
          title: Text(
            className,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          children: [
            if (gurusInClass.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Daftar Guru:',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ...gurusInClass.map((g) {
              final isWali = g['wali'] == true;
              final name = g['name'] ?? '-';
              final initial = name.isNotEmpty ? name[0].toUpperCase() : '-';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF2563EB),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                title: Text(name),
                subtitle: Text(isWali ? 'Guru / Wali Kelas' : 'Guru'),
              );
            }).toList(),

            if (muridsInClass.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Daftar Murid:',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ...muridsInClass.map((m) {
              final nama = m['nama'] ?? '-';
              final initial = nama.isNotEmpty ? nama[0].toUpperCase() : '-';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange[400],
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                title: Text(nama),
                subtitle: const Text('Murid'),
              );
            }).toList(),
            if (gurusInClass.isEmpty && muridsInClass.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Belum ada anggota di kelas ini.'),
              )
          ],
        );
      },
    );
  }
}
