import 'package:flutter/material.dart';
import 'package:apk/dashboard/d_guru/bottom_bar/nav_bar.dart';
import 'package:apk/dashboard/d_guru/dashboard/absensi.dart';
import 'package:apk/dashboard/d_guru/dashboard/pengumuman.dart';
import 'package:apk/dashboard/d_guru/dashboard/guru.dart';
import 'package:apk/dashboard/d_guru/dashboard/murid.dart';
import 'package:apk/closed_app/closed.dart';
import 'package:apk/dashboard/d_guru/function/f_pesan_g/f_notif/grup_kelas_n.dart';
import 'package:apk/dashboard/d_guru/function/f_pesan_g/f_notif/grup_sekolah_n.dart';
import 'package:apk/dashboard/d_guru/function/f_pesan_g/f_notif/chat_private_n.dart';
import 'package:apk/error_handler/connection.dart';
import 'package:apk/session_timer/session_time.dart';

typedef NavScreenG = MainScreenGuru;

class MainScreenGuru extends StatefulWidget {
  const MainScreenGuru({super.key});

  @override
  State<MainScreenGuru> createState() => _MainScreenGuruState();
}

class _MainScreenGuruState extends State<MainScreenGuru> {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    GrupKelasNotification.init();
    GrupSekolahNotification.init();
    ChatPrivateNotification.init();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInternetConnection();
    });
  }

  Future<void> _checkInternetConnection() async {
    bool hasConnection = await ConnectionHandler.checkConnection();
    if (!hasConnection && mounted) {
      ConnectionHandler.showNoConnectionDialog(
        context: context,
        onRetry: () => _checkInternetConnection(),
      );
    }
  }

  final List<Widget> pages = [
    const MuridPage(),
    const Absensi(),
    const Pengumuman(),
    const GuruPage(),
  ];

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SessionTimeManager(
      child: WillPopScope(
        onWillPop: () => handleDoubleTapToExit(context),
        child: Scaffold(
          body: IndexedStack(
            index: selectedIndex,
            children: pages,
          ),
          bottomNavigationBar: BottomNavG(
            selectedIndex: selectedIndex,
            onTap: onItemTapped,
          ),
        ),
      ),
    );
  }
}