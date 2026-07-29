import 'package:flutter/material.dart';

class BottomNavO extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const BottomNavO({
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: selectedIndex == 0
                        ? Colors.blue
                        : const Color(0xFFF1F5F9),
                  ),
                  child: Image.asset(
                    selectedIndex == 0
                        ? 'lib/assets/icons/w_note.png'
                        : 'lib/assets/icons/a_note.png',
                    width: 24,
                    height: 24,
                  ),
                ),
                if (selectedIndex == 0) const SizedBox(height: 2),
                if (selectedIndex == 0)
                  const Text(
                    'Absensi',
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: selectedIndex == 1
                        ? Colors.blue
                        : const Color(0xFFF1F5F9),
                  ),
                  child: Image.asset(
                    selectedIndex == 1
                        ? 'lib/assets/icons/w_add-p.png'
                        : 'lib/assets/icons/a_add-p.png',
                    width: 24,
                    height: 24,
                  ),
                ),
                if (selectedIndex == 1) const SizedBox(height: 2),
                if (selectedIndex == 1)
                  const Text(
                    'Izin',
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
        ],
      ),
    );
  }
}
