import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final ssidController = TextEditingController();
  final passwordController = TextEditingController();
  final urlController = TextEditingController();
  final espIPController = TextEditingController();

  bool loading = false;
  String espIP = "192.168.4.1";

  @override
  void initState() {
    super.initState();
    loadESPIP();
  }

  @override
  void dispose() {
    ssidController.dispose();
    passwordController.dispose();
    urlController.dispose();
    espIPController.dispose();
    super.dispose();
  }

  Future<void> loadESPIP() async {
    final prefs = await SharedPreferences.getInstance();
    espIP = prefs.getString('esp_ip') ?? "192.168.4.1";
    espIPController.text = espIP;
    if (mounted) setState(() {});
  }

  Future<void> saveESPIP() async {
    final prefs = await SharedPreferences.getInstance();
    espIP = espIPController.text.trim();
    await prefs.setString('esp_ip', espIP);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ESP IP: $espIP')),
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> saveConfig() async {
    setState(() => loading = true);
    try {
      final response = await http.post(
        Uri.parse('http://$espIP/save'),
        body: {
          'ssid': ssidController.text,
          'password': passwordController.text,
          'url': urlController.text,
        },
      ).timeout(const Duration(seconds: 7));
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CONFIG SAVED')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> resetServer() async {
    setState(() => loading = true);
    try {
      final response = await http.post(Uri.parse('http://$espIP/reset_server')).timeout(const Duration(seconds: 7));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.body)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    if (mounted) setState(() => loading = false);
  }

  Widget field(
    String label,
    TextEditingController controller, {
    bool obscureText = false,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(fontFamily: 'Inter'),
          decoration: InputDecoration(
            hintText: hintText ?? "Masukkan $label",
            hintStyle: const TextStyle(color: Color(0xFFC4C4C4), fontFamily: 'Inter'),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    final bool isWhite = color == Colors.white;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: isWhite ? const Color(0xFF64748B) : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: isWhite ? const BorderSide(color: Color(0xFF94A3B8)) : BorderSide.none,
          ),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: isWhite ? const Color(0xFF64748B) : Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Image.asset('lib/assets/icons/Button.png', width: 30, height: 30),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: -5,
        title: const Text("ESP32-S3 CONFIG"),
        titleTextStyle: const TextStyle(
          fontFamily: "Inter",
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  field("ESP IP", espIPController, hintText: "192.168.4.1"),
                  _actionButton(
                    label: "SIMPAN IP ESP",
                    color: Colors.white,
                    onPressed: saveESPIP,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  field("WiFi SSID", ssidController),
                  field("Password", passwordController, obscureText: true),
                  field("Server URL", urlController, hintText: "http://192.168.100.16:8000"),
                  
                  const SizedBox(height: 8),
                  
                  _actionButton(
                    label: "SAVE CONFIG",
                    color: const Color(0xFF2563EB),
                    onPressed: loading ? null : saveConfig,
                    loading: loading,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  _actionButton(
                    label: "RESET SERVER CONNECTION",
                    color: const Color(0xFFDC2626), // Red color
                    onPressed: loading ? null : resetServer,
                    loading: loading,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}