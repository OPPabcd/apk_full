import 'package:apk/dashboard/a_admin/bottom_bar/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:apk/closed_app/closed.dart';
import '../dashboard/class.dart';
import '../dashboard/announcement.dart';
import '../dashboard/add_person.dart';
import 'package:apk/dashboard/a_admin/function/f_notif/notif_reddot.dart';
  
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    NotificationFCM.init();
  }

  final List<Widget> pages = [
    const DaftarKelas(),
    const Pengumuman(),
    const TambahPengguna(),
  ];

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        final bool shouldPop = await handleDoubleTapToExit(context);
        if (shouldPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: selectedIndex,
          children: pages,
        ),

        bottomNavigationBar: BottomNav(
          selectedIndex: selectedIndex,
          onTap: onItemTapped,
        ),
      ),
    );
  }
}