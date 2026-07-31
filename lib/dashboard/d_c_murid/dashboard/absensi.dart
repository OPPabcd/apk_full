import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apk/dashboard/d_c_murid/function/f_Pesan/dash_pesan.dart';
import 'package:apk/dashboard/d_c_murid/function/setting/setting_data.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/fcm_notif.dart';
import 'package:apk/dashboard/d_c_murid/function/absen/absen_preview.dart';
import 'package:apk/dashboard/d_c_murid/function/absen/absen_history.dart';
import 'package:apk/dashboard/d_c_murid/function/p_pengumuman.dart/preview_p.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/grup_sekolah_n.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/grup_kelas_n.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/chat_private_n.dart';
import 'package:apk/session_timer/session_time.dart';
import 'package:apk/closed_app/closed.dart';
import 'package:apk/error_handler/connection.dart';

class AbsensiOrtu extends StatefulWidget {
  const AbsensiOrtu({super.key});

  @override
  State<AbsensiOrtu> createState() => _AbsensiOrtuState();
}

class _AbsensiOrtuState extends State<AbsensiOrtu> {
  String studentName = 'Memuat...';
  String studentNis = '...';
  bool isLoading = false;
  int _refreshKey = 0;
  StreamSubscription<List<Map<String, dynamic>>>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
    _listenToNewScans();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  final Set<String> _knownScanIds = {};

  /// Dengarkan scan baru dari output_alat agar tampilan Rekap Kehadiran langsung ter-update otomatis
  void _listenToNewScans() {
    try {
      _scanSubscription = Supabase.instance.client
          .from('output_alat')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .listen((rows) {
            if (rows.isEmpty || !mounted) return;

            if (_knownScanIds.isEmpty) {
              for (final r in rows) {
                final id = r['id']?.toString();
                if (id != null) _knownScanIds.add(id);
              }
              return;
            }

            bool hasNew = false;
            for (final r in rows) {
              final id = r['id']?.toString();
              if (id != null && !_knownScanIds.contains(id)) {
                _knownScanIds.add(id);
                hasNew = true;
              }
            }

            if (hasNew && mounted) {
              setState(() {
                _refreshKey++;
              });
            }
          });
    } catch (e) {
      debugPrint('[AbsensiOrtu] Stream scan error: $e');
    }
  }

  Future<void> _fetchStudentData() async {
    final hasConn = await ConnectionHandler.checkConnection();
    if (!hasConn) {
      if (mounted) {
        setState(() {
          studentName = 'Tidak ada koneksi internet';
          studentNis = '-';
          isLoading = false;
        });
        ConnectionHandler.showNoConnectionDialog(
          context: context,
          onRetry: () {
            setState(() {
              isLoading = true;
            });
            _fetchStudentData();
          },
        );
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final nis = prefs.getString('murid_nis');
      final userId = prefs.getString('user_id_admin');

      if (nis != null && userId != null) {
        final response = await Supabase.instance.client
            .from('murid')
            .select()
            .eq('user_id', userId)
            .eq('nis', nis)
            .single();

        setState(() {
          _refreshKey = _refreshKey + 1;
          // Cari kolom yang mengandung 'nama' atau 'name'
          String? nameValue;
          for (var key in response.keys) {
            if (key.toLowerCase().contains('nama') || key.toLowerCase().contains('name')) {
              nameValue = response[key].toString();
              break;
            }
          }
          studentName = nameValue ?? 'Tanpa Nama';
          studentNis = response['nis']?.toString() ?? nis;
          
          if (nameValue != null) {
            prefs.setString('murid_nama', nameValue);
          }
        });
      } else {
        setState(() {
          studentName = 'Belum login (NIS/User ID kosong)';
          studentNis = '-';
        });
      }
    } catch (e) {
      setState(() {
        studentName = 'Error: $e';
        studentNis = '-';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionTimeManager(
      child: WillPopScope(
        onWillPop: () => handleDoubleTapToExit(context),
        child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        //toolbarHeight: 100,
        titleSpacing: 20,
        title: const Text('Info Siswa'),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: IconButton(
              icon: isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.refresh, color: Colors.white),
              onPressed: isLoading 
                  ? null 
                  : () {
                      setState(() {
                        isLoading = true;
                      });
                      _fetchStudentData();
                    },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              // Menu Buttons Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMenuButton(
                    icon: Icons.assignment_turned_in_outlined,
                    label: 'Info Absen Siswa',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AbsenHistory(nis: studentNis),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 32),
                  ValueListenableBuilder<bool>(
                    valueListenable: GrupSekolahNotification.hasUnread,
                    builder: (context, unreadSekolah, child) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: GrupKelasNotification.hasUnread,
                        builder: (context, unreadKelas, child) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: ChatPrivateNotification.hasUnread,
                            builder: (context, unreadPrivate, child) {
                              final hasAnyUnread = unreadSekolah || unreadKelas || unreadPrivate;
                              return _buildMenuButton(
                                icon: Icons.chat_bubble_outline_rounded,
                                label: 'Grup Chat',
                                showBadge: hasAnyUnread,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const DashPesan(),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // Student Info Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
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
    // Avatar


    // Info
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            studentName,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'NIS:',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  studentNis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),

    const SizedBox(width: 8),

    // Setting icon di kanan
    IconButton(
      icon: const Icon(Icons.settings_outlined, color: Color(0xFF64748B)),
      tooltip: 'Pengaturan Profil',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingDataOrtu()),
        ).then((_) => _fetchStudentData());
      },
    ),
  ],
),
              ),
              const SizedBox(height: 30),
              // Rekap Kehadiran
              const Text(
                'Rekap Kehadiran',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              AbsenPreview(
                key: ValueKey('${studentNis}_$_refreshKey'),
                nis: studentNis,
              ),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }



  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool showBadge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 100, // Fixed width to handle wrapping consistently
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8C9DCD),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8C9DCD).withOpacity(0.5),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                if (showBadge)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
