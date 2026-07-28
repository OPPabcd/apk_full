import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/fcm_notif.dart' as fcm_absen;
import 'package:apk/dashboard/d_guru/database/auth_guru.dart';
import 'package:apk/register/page1.dart';

class UserGuru extends StatefulWidget {
  const UserGuru({super.key});

  @override
  State<UserGuru> createState() => _UserGuruState();
}

class _UserGuruState extends State<UserGuru> {
  final AuthGuru _auth = AuthGuru();
  bool _isLoading = false;

  final TextEditingController userIdController = TextEditingController();
  final TextEditingController nipController = TextEditingController();

  void _login() async {
    setState(() => _isLoading = true);
    try {
      final emailAdmin = userIdController.text.trim();
      final nip = nipController.text.trim();
      final result = await _auth.signInGuru(emailAdmin, nip);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', emailAdmin);
      await prefs.setString('user_role', 'guru');

      // Daftarkan token FCM ke Supabase
      final guruId = result['id_tabel']?.toString();
      if (guruId != null && guruId.isNotEmpty) {
        await fcm_absen.NotificationFCM.saveTokenToSupabase(guruId.trim(), 'guru');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Login berhasil! Silakan tekan tombol Masuk."),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Home()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login gagal: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,  
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0,),
        children: [
                const SizedBox(height: 70),

                Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.school_outlined,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  "Masuk Sebagai Guru",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Silakan masukkan kredensial Anda",
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF94A3B8),
                  ),
                ),

                const SizedBox(height: 55),

                // EMAIL
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Email Admin",
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: userIdController,
                  decoration: InputDecoration(
                    hintText: "Masukkan Email Admin",
                    hintStyle: const TextStyle(
                      color: Color(0xFFC4C4C4),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // PASSWORD
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "NIP",
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: nipController,
                  decoration: InputDecoration(
                    hintText: "Masukkan NIP",
                    hintStyle: const TextStyle(
                      color: Color(0xFFC4C4C4),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // BUTTON
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        elevation: 8,
                        shadowColor: Colors.green.withOpacity(0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                        "Masuk",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}