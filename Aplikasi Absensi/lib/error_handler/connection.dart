import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ConnectionHandler {
  // Mengecek ketersediaan koneksi internet
  static Future<bool> checkConnection() async {
    if (kIsWeb) return true;
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      return false;
    }
    return false;
  }

  // Menampilkan pop up peringatan jika tidak ada koneksi
  static void showNoConnectionDialog({
    required BuildContext context,
    required VoidCallback onRetry,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text(
                'Tidak Ada Koneksi', 
                style: TextStyle(
                  fontFamily: 'Inter', 
                  fontWeight: FontWeight.bold, 
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: const Text(
            'Pastikan perangkat Anda terhubung ke internet untuk memuat data terbaru.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text(
                'Coba Lagi', 
                style: TextStyle(
                  fontFamily: 'Inter', 
                  fontWeight: FontWeight.bold, 
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
