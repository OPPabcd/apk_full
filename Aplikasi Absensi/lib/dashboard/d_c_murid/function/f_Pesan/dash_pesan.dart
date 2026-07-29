import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apk/dashboard/d_c_murid/function/f_Pesan/grup_sekolah.dart';
import 'package:apk/dashboard/d_c_murid/function/f_Pesan/grup_kelas.dart';
import 'package:apk/dashboard/d_c_murid/function/f_Pesan/chat_admin.dart';
import 'package:apk/dashboard/d_c_murid/function/f_Pesan/chat_private.dart';
import 'package:apk/dashboard/d_c_murid/widget/custom_button.dart';
import 'package:apk/dashboard/d_c_murid/database/db_guru.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/grup_sekolah_n.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/grup_kelas_n.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/chat_private_n.dart';

class DashPesan extends StatefulWidget {
  const DashPesan({super.key});

  @override
  State<DashPesan> createState() => _DashPesanState();
}

class _DashPesanState extends State<DashPesan> {
  String? _adminId;

  @override
  void initState() {
    super.initState();
    _loadAdminId();
  }

  Future<void> _loadAdminId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _adminId = prefs.getString('user_id_admin');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Pilih Grup Chat'),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DbGuru().getGuruForStudentClass(),
        builder: (context, snapshot) {
          final gurus = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: ValueListenableBuilder<bool>(
                  valueListenable: GrupSekolahNotification.hasUnread,
                  builder: (context, hasUnread, child) {
                    return Stack(
                      children: [
                        CustomCard(
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
                            GrupSekolahNotification.setUnread(false);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const GrupSekolah()),
                            );
                          },
                        ),
                        if (hasUnread)
                          Positioned(
                            top: 12,
                            right: 16,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: ValueListenableBuilder<bool>(
                  valueListenable: GrupKelasNotification.hasUnread,
                  builder: (context, hasUnread, child) {
                    return Stack(
                      children: [
                        CustomCard(
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
                            GrupKelasNotification.setUnread(false);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const GrupKelasPage()),
                            );
                          },
                        ),
                        if (hasUnread)
                          Positioned(
                            top: 12,
                            right: 16,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: ValueListenableBuilder<Set<String>>(
                  valueListenable: ChatPrivateNotification.unreadSenderIds,
                  builder: (context, unreadSenders, child) {
                    final bool hasUnread = _adminId != null && unreadSenders.contains(_adminId);
                    return Stack(
                      children: [
                        CustomCard(
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
                            if (_adminId != null) {
                              ChatPrivateNotification.setSenderUnread(_adminId!, false);
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ChatAdminPage()),
                            );
                          },
                        ),
                        if (hasUnread)
                          Positioned(
                            top: 12,
                            right: 16,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              if (gurus.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Pesan ke Guru',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...gurus.map((guru) {
                  final String nama = guru['name'] ?? 'Guru';
                  final String nip = guru['nik']?.toString() ?? '-';
                  final String bidang = (guru['bidang']?.toString().isEmpty ?? true)
                      ? 'Guru'
                      : guru['bidang'].toString();
                  final String guruId = guru['id_tabel'].toString();

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    child: ValueListenableBuilder<Set<String>>(
                      valueListenable: ChatPrivateNotification.unreadSenderIds,
                      builder: (context, unreadSenders, child) {
                        final bool hasUnread = unreadSenders.contains(guruId);
                        return Stack(
                          children: [
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
                                    "NIP: $nip",
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
                                      bidang,
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
                                ChatPrivateNotification.setSenderUnread(guruId, false);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatPrivate(
                                      receiverId: guruId,
                                      receiverType: 'guru',
                                      receiverName: nama,
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (hasUnread)
                              Positioned(
                                top: 12,
                                right: 16,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  );
                }).toList(),
              ],
            ],
          );
        },
      ),
    );
  }
}
