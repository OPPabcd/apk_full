import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apk/dashboard/d_c_murid/bottom_bar/nav_bar.dart';
import 'package:apk/dashboard/d_c_murid/dashboard/absensi.dart';
import 'package:apk/dashboard/d_c_murid/function/f_izin/form_izin.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/fcm_notif.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/grup_kelas_n.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/grup_sekolah_n.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/chat_private_n.dart';
import 'package:apk/error_handler/connection.dart';
import 'package:apk/session_timer/session_time.dart';
import 'package:apk/closed_app/closed.dart';

typedef NavScreenM = MainScreenOrtu;
typedef MainScreenMurid = MainScreenOrtu;

class MainScreenOrtu extends StatefulWidget {
  const MainScreenOrtu({super.key});

  @override
  State<MainScreenOrtu> createState() => _MainScreenOrtuState();
}

class _MainScreenOrtuState extends State<MainScreenOrtu> {
  int selectedIndex = 0;

  final List<Widget> pages = [
    const AbsensiOrtu(),
    const FormIzin(),
  ];

  @override
  void initState() {
    super.initState();
    NotificationFCM.init();
    _subscribeOutputAlat();  // filter ke user saat ini
    GrupKelasNotification.init();
    GrupSekolahNotification.init();
    ChatPrivateNotification.init();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInternetConnection();
    });
  }

  /// Subscribe output_alat hanya untuk user yang sedang login
  Future<void> _subscribeOutputAlat() async {
    final prefs = await SharedPreferences.getInstance();
    // Prioritas: nama murid → nama guru
    final nama = prefs.getString('murid_nama') ?? prefs.getString('guru_nama') ?? '';
    if (nama.isNotEmpty) {
      NotificationFCM.subscribeOutputAlatForCurrentUser(nama);
    }
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
          bottomNavigationBar: BottomNavO(
            selectedIndex: selectedIndex,
            onTap: onItemTapped,
          ),
        ),
      ),
    );
  }
}
