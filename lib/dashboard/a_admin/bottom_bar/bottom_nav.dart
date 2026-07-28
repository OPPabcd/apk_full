import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/function/f_notif/notif_reddot.dart';

class BottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const BottomNav({
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
                ValueListenableBuilder<bool>(
                  valueListenable: NotifRedDot.grupSekolahHasUnread,
                  builder: (context, unreadGS, child) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: NotifRedDot.chatPrivateHasUnread,
                      builder: (context, unreadPrivate, child) {
                        final bool hasAnyUnread = unreadGS || unreadPrivate;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: selectedIndex == 1
                                    ? Colors.blue
                                    : const Color(0xFFF1F5F9),
                              ),
                              child: Image.asset(
                                selectedIndex == 1
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
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
                if (selectedIndex == 1) SizedBox(height: 2),
                if (selectedIndex == 1)
                  Text('Pengumuman',
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
            icon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: selectedIndex == 2
                        ? Colors.blue
                        : Color(0xFFF1F5F9),
                  ),
                  child: Image.asset(
                    selectedIndex == 2
                        ? 'lib/assets/icons/w_add-p.png'
                        : 'lib/assets/icons/a_add-p.png',
                    width: 24,
                    height: 24,
                  ),
                ),
                if (selectedIndex == 2) SizedBox(height: 2),
                if (selectedIndex == 2)
                  Text('Tambah',
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