import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apk/register/option_user.dart';
import 'package:apk/dashboard/a_admin/bottom_bar/main_screen.dart';
import 'package:apk/dashboard/d_guru/bottom_bar/nav_screen_g.dart';
import 'package:apk/dashboard/d_c_murid/bottom_bar/nav_screen_o.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _LoginState();
}

class _LoginState extends State<Home> {
  late Timer _timer;
  String _time = "";

  @override
  void initState() {
    super.initState();
    _updateTime();

    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _time =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _login() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('user_email');
    final userRole = prefs.getString('user_role');

    if (!mounted) return;

    if (userEmail != null && userEmail.isNotEmpty) {
      if (userRole == 'guru') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const NavScreenG()),
          (route) => false,
        );
      } else if (userRole == 'murid' || userRole == 'ortu') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const NavScreenM()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda belum login. Silakan tekan tombol gembok 🔒 untuk login terlebih dahulu.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _loginWithLock() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OptionUser()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomSheet: Container(
        color: Colors.white,
        height: 60,
        child: const Center(
          child: Text(
            'Powered by Yourself',
            style: TextStyle(
              fontFamily: "Inter",
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 50,
            right: 60,
            child: Text(
              _time,
              style: const TextStyle(
                fontFamily: 'Digital-7',
                fontSize: 60,
                color: Colors.black,
                letterSpacing: 2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 60, right: 60, bottom: 100),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Kelola semuanya\nlebih mudah & cepat',
                      style: TextStyle(
                        fontFamily: "Inter",
                        fontSize: 18,
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // ===== BUTTON ROW =====
                  Row(
                    children: [
                      // Tombol utama
                      Expanded(
                        child: SizedBox(
                          height: 58,
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(255, 15, 0, 221),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Masuk',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Tombol icon kotak
                      SizedBox(
                        width: 58,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: _loginWithLock,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 15, 0, 221),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Icon(
                            Icons.lock,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}