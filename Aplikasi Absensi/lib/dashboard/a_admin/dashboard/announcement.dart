import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/widget/custom_button.dart';
import 'package:apk/dashboard/a_admin/function/f_pesan/grup_sekolah.dart';
import 'package:apk/dashboard/a_admin/database/db_guru.dart';
import 'package:apk/dashboard/a_admin/database/db_siswa.dart';
import 'package:apk/dashboard/a_admin/function/f_pesan/chat_private.dart';
import 'package:apk/error_handler/connection.dart';
import 'package:apk/dashboard/a_admin/database/db_grup_sekolah.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apk/dashboard/a_admin/function/f_notif/preview_pesan/grup_sekolah_p.dart';
import 'package:apk/dashboard/a_admin/function/f_notif/notif_reddot.dart';

class Pengumuman extends StatefulWidget {
  const Pengumuman({super.key});

  @override
  State<Pengumuman> createState() => _PengumumanState();
}

class _PengumumanState extends State<Pengumuman> {
  final MuridService _muridService = MuridService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _listGuru = [];
  List<Map<String, dynamic>> _listMurid = [];
  DateTime? _lastVisitedGrupSekolah;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!await ConnectionHandler.checkConnection()) {
      if (mounted) {
        setState(() => _isLoading = false);
        ConnectionHandler.showNoConnectionDialog(
          context: context,
          onRetry: () {
            setState(() => _isLoading = true);
            _loadData();
          },
        );
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastVisitedStr = prefs.getString('last_visited_grup_sekolah');

      final guruRes = await GuruService.getGuru();
      final muridRes = await _muridService.getMurid();
      if (mounted) {
        setState(() {
          _lastVisitedGrupSekolah = lastVisitedStr != null ? DateTime.tryParse(lastVisitedStr) : null;
          _listGuru = guruRes;
          _listMurid = muridRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildBellIcon() {
    if (Supabase.instance.client.auth.currentUser == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DbGrupSekolah().getGrupSekolahStream(),
      builder: (context, snapshot) {
        int unreadCount = 0;

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
          for (final msg in snapshot.data!) {
            final lastMessageTimeStr = msg['created_at']?.toString();
            final senderUserId = msg['user_id']?.toString();
            if (lastMessageTimeStr != null && senderUserId != currentUserId) {
              final lastMessageTime = DateTime.tryParse(lastMessageTimeStr);
              if (lastMessageTime != null) {
                if (_lastVisitedGrupSekolah == null || lastMessageTime.isAfter(_lastVisitedGrupSekolah!)) {
                  unreadCount++;
                }
              }
            }
          }
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
              tooltip: 'Notifikasi',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GrupSekolahP()),
                ).then((_) {
                  _loadData();
                  // Re-evaluate notification state after returning
                  setState(() {});
                });
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     // bottomNavigationBar: const BottomNav(selectedIndex: 1),
      appBar: AppBar(
        //toolbarHeight: 100,
        titleSpacing: 20,
        title: const Text('Pengumuman Sekolah'),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        backgroundColor: Color(0xFF2563EB),
        elevation: 0,
        actions: [
          //_buildBellIcon(),
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: IconButton(
              icon: const Icon(Icons.refresh, 
              color: Colors.white),
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
                  child: ValueListenableBuilder<bool>(
                    valueListenable: NotificationFCM.hasUnread,
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
                            onTap: () async {
                              final prefs = await SharedPreferences.getInstance();
                              final nowStr = DateTime.now().toIso8601String();
                              await prefs.setString('last_visited_grup_sekolah', nowStr);
                              if (mounted) {
                                setState(() {
                                  _lastVisitedGrupSekolah = DateTime.tryParse(nowStr);
                                });
                                NotifRedDot.setGrupSekolahUnread(false);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const GrupSekolah()),
                                ).then((_) {
                                  _loadData();
                                });
                              }
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
                  final kelas = guru['class_name']?['name_class'] ?? 'Belum ada kelas';
                  final String guruId = guru['id_tabel']?.toString() ?? '';
                  
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
                                NotifRedDot.setChatPrivateSenderUnread(guruId, false);
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
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('List Murid', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                ),
                const SizedBox(height: 10),
                ..._listMurid.map((murid) {
                  final nama = murid['nama'] ?? '-';
                  final kelas = murid['class_name']?['name_class'] ?? 'Belum ada kelas';
                  final String muridId = murid['id_tabel']?.toString() ?? '';
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    child: ValueListenableBuilder<Set<String>>(
                      valueListenable: NotifRedDot.chatPrivateUnreadSenderIds,
                      builder: (context, unreadSenders, child) {
                        final bool hasUnread = unreadSenders.contains(muridId);
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
                                  const Text(
                                    'Siswa',
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
                                NotifRedDot.setChatPrivateSenderUnread(muridId, false);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatPrivate(
                                      receiverId: muridId,
                                      receiverType: 'murid',
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
            ),
    );
  }
}
