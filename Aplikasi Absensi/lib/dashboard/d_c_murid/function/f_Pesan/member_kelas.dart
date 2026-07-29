import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apk/dashboard/d_c_murid/database/db_guru.dart';
import 'package:apk/dashboard/d_c_murid/database/db_murid.dart';

class MemberKelasPage extends StatefulWidget {
  final String classId;
  const MemberKelasPage({super.key, required this.classId});

  @override
  State<MemberKelasPage> createState() => _MemberKelasPageState();
}

class _MemberKelasPageState extends State<MemberKelasPage> {
  final DbGuru _dbGuru = DbGuru();
  final DbMurid _dbMurid = DbMurid();

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _gurusInClass = [];
  List<Map<String, dynamic>> _muridsInClass = [];
  String _className = 'Kelas';

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    try {
      final guruList = await _dbGuru.getAllGuru();
      final muridList = await _dbMurid.getAllMurid();

      final List<Map<String, dynamic>> gurus = [];
      final List<Map<String, dynamic>> murids = [];

      // Ambil nama kelas untuk judul
      final supabase = Supabase.instance.client;
      final classInfo = await supabase.from('class_name').select('name_class').eq('id_tabel', widget.classId).maybeSingle();
      if (classInfo?['name_class'] != null) {
        _className = classInfo!['name_class'].toString();
      }

      // Process Guru (Cek id_class dan boolean 'wali')
      for (var guru in guruList) {
        if (guru['id_class']?.toString() == widget.classId) {
          if (guru['wali'] == true) {
            guru['role'] = 'Guru / Wali Kelas';
          } else {
            guru['role'] = 'Guru';
          }
          gurus.add(guru);
        }
      }

      // Process Murid
      for (var murid in muridList) {
        if (murid['id_class']?.toString() == widget.classId) {
          murid['role'] = 'Murid';
          murids.add(murid);
        }
      }

      setState(() {
        _gurusInClass = gurus;
        _muridsInClass = murids;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat anggota kelas: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Image.asset('lib/assets/icons/Button.png', width: 30, height: 30),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: -5,
        title: Text("Anggota $_className"),
        titleTextStyle: const TextStyle(
          fontFamily: "Inter",
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
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
              : _buildMemberList(),
    );
  }

  Widget _buildMemberList() {
    if (_gurusInClass.isEmpty && _muridsInClass.isEmpty) {
       return const Center(child: Text('Belum ada anggota di kelas ini.', style: TextStyle(fontFamily: 'Inter')));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_gurusInClass.isNotEmpty)
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
        ..._gurusInClass.map((g) {
          final name = g['name'] ?? '-';
          
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF2563EB),
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(name, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
            subtitle: Text(g['role'] ?? 'Guru', style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
          );
        }).toList(),

        if (_muridsInClass.isNotEmpty)
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
        ..._muridsInClass.map((m) {
          final name = m['nama'] ?? '-';
          
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange[400],
              child: const Icon(Icons.person_outline, color: Colors.white),
            ),
            title: Text(name, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
            subtitle: const Text('Murid', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
          );
        }).toList(),
      ],
    );
  }
}
