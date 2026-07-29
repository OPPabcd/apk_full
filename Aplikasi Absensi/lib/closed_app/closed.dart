import 'package:flutter/material.dart';

DateTime? _currentBackPressTime;

Future<bool> handleDoubleTapToExit(BuildContext context) async {
  final now = DateTime.now();
  
  if (_currentBackPressTime == null || 
      now.difference(_currentBackPressTime!) > const Duration(seconds: 2)) {
    // Jika belum pernah ditekan atau sudah lewat 2 detik
    _currentBackPressTime = now;
    
    // Tampilkan warning
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Tekan tombol kembali sekali lagi untuk keluar', 
          style: TextStyle(color: Colors.white, fontFamily: 'Inter'),
          textAlign: TextAlign.center,
        ),
        backgroundColor: const Color(0xFF334155), // Slate 700
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 20, left: 40, right: 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    return false;
  }
  
  // Jika ditekan dua kali dalam rentang 2 detik, izinkan keluar
  return true;
}
