import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/widget/custom_button.dart';
import 'package:apk/dashboard/d_guru/function/f_pesan_g/grup_sekolah_g.dart';
import 'package:apk/dashboard/d_guru/function/f_pesan_g/grup_kelas_g.dart';
import 'package:apk/dashboard/d_guru/function/f_pesan_g/chat_admin_g.dart';
import 'package:apk/dashboard/d_guru/function/f_pesan_g/chat_private_g.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PengumumanG extends StatefulWidget {
  const PengumumanG({super.key});

  @override
  State<PengumumanG> createState() => _PengumumanGState();
}

class _PengumumanGState extends State<PengumumanG> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _listGuru = [];
  List<Map<String, dynamic>> _listMurid = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final supabase = Supabase.instance.client;
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id_admin');
      final nik = prefs.getString('guru_nik');

      if (userId == null || nik == null) {
        if (mounted) setState(() => _isLoading = false);
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
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final guruIdTabel = guruData['id_tabel'];
      final guruIdClass = guruData['id_class'];

      // 2. Kumpulkan semua ID Kelas (UUID) — pola dari db_kelas
      Set<String> validClassIds = {};
      if (guruIdClass != null) {
        validClassIds.add(guruIdClass.toString());
      }

      final classDataList = await supabase
          .from('class_name')
          .select('id_tabel, id_class')
          .eq('id_guru', guruIdTabel);

      for (var c in classDataList) {
        validClassIds.add(c['id_tabel'].toString());
      }

      if (validClassIds.isEmpty) {
        if (mounted) {
          setState(() {
            _listGuru = [];
            _listMurid = [];
            _isLoading = false;
          });
        }
        return;
      }

      // 3. Ambil guru yang id_class-nya ada di validClassIds
      final guruInClass = await supabase
          .from('guru')
          .select('id_tabel, nik, name, bidang, wali, id_class')
          .inFilter('id_class', validClassIds.toList());

      // Buang diri sendiri
      final List<Map<String, dynamic>> filteredGuru = [];
      for (var g in guruInClass) {
        if (g['id_tabel'].toString() != guruIdTabel.toString()) {
          filteredGuru.add(g);
        }
      }

      // 4. Ambil murid — pola dari db_kelas.getMuridForGuru()
      Map<String, Map<String, dynamic>> allMurid = {};

      final muridListA = await supabase
          .from('murid')
          .select('id_tabel, nis, nama, gender, id_class')
          .inFilter('id_class', validClassIds.toList());

      for (var m in muridListA) {
        allMurid[m['id_tabel'].toString()] = m;
      }

      final classMuridRows = await supabase
          .from('class_name')
          .select('id_murid')
          .inFilter('id_tabel', validClassIds.toList())
          .not('id_murid', 'is', null);

      List<String> muridIdsFromClass = classMuridRows
          .map((r) => r['id_murid'].toString())
          .where((id) => id != 'null')
          .toList();

      if (muridIdsFromClass.isNotEmpty) {
        final muridListB = await supabase
            .from('murid')
            .select('id_tabel, nis, nama, gender, id_class')
            .inFilter('id_tabel', muridIdsFromClass);

        for (var m in muridListB) {
          allMurid[m['id_tabel'].toString()] = m;
        }
      }

      final finalMuridList = allMurid.values.toList();
      finalMuridList.sort((a, b) =>
          (a['nama']?.toString() ?? '').compareTo(b['nama']?.toString() ?? ''));

      if (mounted) {
        setState(() {
          _listGuru = filteredGuru;
          _listMurid = finalMuridList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error _loadData pengumuman_g: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Pengumuman Sekolah'),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
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
                  _isLoading = true;
                });
                _loadData();
              },
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: CustomCard(
                    title: 'Grup Sekolah',
                    titleStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                    customSubtitle: Row(
                      children: [
                        const Text(
                          'Forum',
                          style: TextStyle(
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
                            'Informasi & Diskusi',
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GrupSekolahG()),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: CustomCard(
                    title: 'Grup Kelas',
                    titleStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                    customSubtitle: Row(
                      children: [
                        const Text(
                          'Kelas',
                          style: TextStyle(
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
                            'Diskusi Khusus Kelas Anda',
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GrupKelasPageG()),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: CustomCard(
                    title: 'Admin Sekolah',
                    titleStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                    customSubtitle: Row(
                      children: [
                        const Text(
                          'Bantuan',
                          style: TextStyle(
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
                            'Hubungi Admin Sekolah',
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ChatAdminPageG()),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('List Guru', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                ),
                const SizedBox(height: 10),
                ..._listGuru.map((guru) {
                  final nama = guru['name'] ?? '-';
                  final isWali = guru['wali'] == true;
                  final roleText = isWali ? 'Wali Kelas' : 'Guru Mapel';
                  
                  final classNameObj = guru['class_name'];
                  String kelas = "Belum ada kelas";
                  if (classNameObj != null) {
                    if (classNameObj is String) {
                      kelas = classNameObj;
                    } else if (classNameObj is List && classNameObj.isNotEmpty) {
                      kelas = classNameObj[0]['name_class']?.toString() ?? "Belum ada kelas";
                    } else if (classNameObj is Map) {
                      kelas = classNameObj['name_class']?.toString() ?? "Belum ada kelas";
                    }
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
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
                            roleText,
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
                              kelas,
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPrivateG(
                              receiverId: guru['id_tabel'].toString(),
                              receiverType: 'guru',
                              receiverName: nama,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('List Murid', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                ),
                const SizedBox(height: 10),
                ..._listMurid.map((murid) {
                  final nama = murid['nama'] ?? '-';
                  
                  final nis = murid['nis']?.toString() ?? '-';
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    child: CustomCard(
                      title: nama,
                      titleStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                      customSubtitle: Text(
                        'NIS: $nis',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      showIcon: false,
                      backgroundColor: Colors.white,
                      borderColor: Colors.transparent,
                      borderWidth: 0,
                      margin: EdgeInsets.zero,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPrivateG(
                              receiverId: murid['id_tabel'].toString(),
                              receiverType: 'murid',
                              receiverName: nama,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
              ],
            ),
    );
  }
}
