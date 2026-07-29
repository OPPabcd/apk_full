import 'dart:async';
import 'package:apk/register/admin/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/database/auth.dart';

class SignupAdmin extends StatefulWidget {
  const SignupAdmin({super.key});

  @override
  State<SignupAdmin> createState() => _SignupAdminState();
}

class _SignupAdminState extends State<SignupAdmin> {
  final _auth = AuthService();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final otpController = TextEditingController();

  bool isHidden = true;
  bool isLoading = false;
  bool isOtpSent = false;

  Timer? timer;
  int secondsLeft = 300; // 5 menit

  /// ===============================
  /// KIRIM OTP
  /// ===============================
  Future<void> sendOtp() async {
    setState(() => isLoading = true);

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      await _auth.signUp(email, password);

      startTimer();

      setState(() {
        isOtpSent = true;
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("OTP dikirim ke email")),
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  /// ===============================
  /// TIMER 5 MENIT
  /// ===============================
  void startTimer() {
    timer?.cancel();
    secondsLeft = 300;

    timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (secondsLeft == 0) {
        t.cancel();

        /// hapus user public (jika ada)
        await _auth.deleteUserPublic(emailController.text.trim());

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Waktu habis, silakan daftar ulang")),
        );

        setState(() {
          isOtpSent = false;
          otpController.clear();
        });

      } else {
        setState(() => secondsLeft--);
      }
    });
  }

  /// ===============================
  /// VERIFY OTP
  /// ===============================
  Future<void> verifyOtp() async {
    setState(() => isLoading = true);

    try {
      final email = emailController.text.trim();
      final otp = otpController.text.trim();

      final res = await _auth.verifyOtp(email, otp);
      final user = res.user;

      if (user != null) {
        /// STOP TIMER
        timer?.cancel();

        /// INSERT SETELAH OTP VALID
        await _auth.insertUser(
          id: user.id,
          email: email,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verifikasi berhasil")),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginAdmin(),
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("OTP salah")),
      );
    }
  }

  String formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 60),
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
            "Daftar Akun Admin",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                    "Email",
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

          /// EMAIL
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    hintText: "Masukkan Email",
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
                    "Kata Sandi",
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

               TextField(
                  controller: passwordController,
                  obscureText: isHidden,
                  decoration: InputDecoration(
                    hintText: "Masukkan kata sandi",
                    hintStyle: const TextStyle(
                      color: Color(0xFFC4C4C4),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isHidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: const Color(0xFF94A3B8),
                      ),
                      onPressed: () {
                        setState(() {
                          isHidden = !isHidden;
                        });
                      },
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

          /// OTP FIELD
          if (isOtpSent) ...[
            const SizedBox(height: 22),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Kode OTP",
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            const SizedBox(height: 10),

                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "Masukkan OTP",
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
            const SizedBox(height: 10),

            Text(
              "Waktu: ${formatTime(secondsLeft)}",
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
          ],

          const SizedBox(height: 40),

          /// BUTTON
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                elevation: 8,
                shadowColor: Colors.green.withOpacity(0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: isLoading
                  ? null
                  : isOtpSent
                      ? verifyOtp
                      : sendOtp,
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(isOtpSent ? "Verifikasi" : "Daftar",
                  style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
            ),
            ),
          ),

                    const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Sudah punya akun? ",
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 15,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginAdmin(),
                    ),
                  );
                },
                child: const Text(
                  "Masuk",
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 70),
        ],
      ),
    );
  }
}