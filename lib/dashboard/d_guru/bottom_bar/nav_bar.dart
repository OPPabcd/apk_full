import 'package:flutter/material.dart';
import 'package:apk/dashboard/d_guru/function/f_pesan_g/f_notif/grup_sekolah_n.dart';
import 'package:apk/dashboard/d_guru/function/f_pesan_g/f_notif/grup_kelas_n.dart';
import 'package:apk/dashboard/d_guru/function/f_pesan_g/f_notif/chat_private_n.dart';

class BottomNavG extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const BottomNavG({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50, // Mengatur tinggi bar
      child: BottomNavigationBar(
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedFontSize: 0,
        unselectedFontSize: 0,
        type: BottomNavigationBarType.fixed,
        currentIndex: selectedIndex,
        onTap: onTap,

        items: [
          BottomNavigationBarItem(
            icon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: selectedIndex == 0
                        ? Colors.blue
                        : Color(0xFFF1F5F9),
                  ),
                  child: Image.asset(
                    selectedIndex == 0
                        ? 'lib/assets/icons/w_building.png'
                        : 'lib/assets/icons/a_building.png',
                    width: 24,
                    height: 24,
                  ),
                ),
                if (selectedIndex == 0) SizedBox(height: 2),
                if (selectedIndex == 0)
                  Text(
                    'Daftar Kelas',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                    ),
                  ),
              ],
            ),
            label: '',
          ),

          BottomNavigationBarItem(
            icon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: selectedIndex == 1
                        ? Colors.blue
                        : Color(0xFFF1F5F9),
                  ),
                  child: Image.asset(
                    selectedIndex == 1
                        ? 'lib/assets/icons/w_note.png'
                        : 'lib/assets/icons/a_note.png',
                    width: 24,
                    height: 24,
                  ),
                ),
                if (selectedIndex == 1) SizedBox(height: 2),
                if (selectedIndex == 1)
                  Text('Absensi',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      )),
              ],
            ),
            label: '',
          ),

          BottomNavigationBarItem(
            icon: ValueListenableBuilder<bool>(
              valueListenable: GrupSekolahNotification.hasUnread,
              builder: (context, unreadSekolah, child) {
                return ValueListenableBuilder<bool>(
                  valueListenable: GrupKelasNotification.hasUnread,
                  builder: (context, unreadKelas, child) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: ChatPrivateNotification.hasUnread,
                      builder: (context, unreadPrivate, child) {
                        final hasAnyUnread = unreadSekolah || unreadKelas || unreadPrivate;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: selectedIndex == 2
                                        ? Colors.blue
                                        : const Color(0xFFF1F5F9),
                                  ),
                                  child: Image.asset(
                                    selectedIndex == 2
                                        ? 'lib/assets/icons/w_bell.png'
                                        : 'lib/assets/icons/a_bell.png',
                                    width: 24,
                                    height: 24,
                                  ),
                                ),
                                if (hasAnyUnread)
                                  Positioned(
                                    top: -2,
                                    right: -2,
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
                            ),
                            if (selectedIndex == 2) const SizedBox(height: 2),
                            if (selectedIndex == 2)
                              const Text('Pengumuman',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue,
                                  )),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
            label: '',
          ),

          BottomNavigationBarItem(
            icon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: selectedIndex == 3
                        ? Colors.blue
                        : Color(0xFFF1F5F9),
                  ),
                  child: Image.asset(
                    selectedIndex == 3
                        ? 'lib/assets/icons/w_people.png'
                        : 'lib/assets/icons/a_people.png',
                    width: 24,
                    height: 24,
                  ),
                ),
                if (selectedIndex == 3) SizedBox(height: 2),
                if (selectedIndex == 3)
                  Text('Daftar Guru',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      )),
              ],
            ),
            label: '',
          ),
        ],
      ),
    );
  }
}