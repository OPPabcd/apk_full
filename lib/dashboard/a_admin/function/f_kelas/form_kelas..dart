import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/database/db_kelas.dart';

class FormKelasPage extends StatefulWidget {
  const FormKelasPage({super.key});

  @override
  State<FormKelasPage> createState() => _FormKelasPageState();
}

class _FormKelasPageState extends State<FormKelasPage> {
  final nameClassController = TextEditingController();
  final tahunAwalController = TextEditingController();
  final tahunAkhirController = TextEditingController();
  
  int? selectedTingkat;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    // Intentionally left empty if we don't load guru/murid here anymore.
    // If needed in the future, load other class-related data here.
  }

  Future<void> simpan() async {
    if (nameClassController.text.isEmpty || selectedTingkat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama Kelas dan Tingkat wajib diisi!")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      String tahunStr = "";
      if (tahunAwalController.text.isNotEmpty && tahunAkhirController.text.isNotEmpty) {
        tahunStr = "${tahunAwalController.text} / ${tahunAkhirController.text}";
      }

      await ClassService.tambahKelas(
        idClass: selectedTingkat!,
        nameClass: nameClassController.text,
        idGuru: null,
        idMurid: null,
        tahun: tahunStr.isEmpty ? null : tahunStr,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kelas berhasil disimpan")),
      );

      // reset form
      nameClassController.clear();
      tahunAwalController.clear();
      tahunAkhirController.clear();

      setState(() {
        selectedTingkat = null;
      });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    if (mounted) setState(() => isLoading = false);
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E293B),
      ),
    );
  }

  InputDecoration _buildDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: Color(0xFFC4C4C4),
      ),
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Image.asset('lib/assets/icons/Button.png', width: 30, height: 30),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: -5,
        title: const Text("Form Kelas"),
        titleTextStyle: const TextStyle(
          fontFamily: "Inter",
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
        child: ListView(
          children: [
            // Nama Kelas
            _buildLabel("Nama Kelas *"),
            const SizedBox(height: 6),
            TextField(
              controller: nameClassController,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              decoration: _buildDecoration("Contoh: Kelas 1A"),
            ),
            const SizedBox(height: 16),

            // Tingkat
            _buildLabel("Tingkat Kelas *"),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: selectedTingkat,
              hint: const Text(
                "Pilih Tingkat / Lain-lain",
                style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFFC4C4C4)),
              ),
              decoration: _buildDecoration("").copyWith(hintText: null),
              items: [
                for (int i = 1; i <= 6; i++)
                  DropdownMenuItem(value: i, child: Text("Tingkat $i", style: const TextStyle(fontFamily: 'Inter', fontSize: 14))),
                const DropdownMenuItem(value: 7, child: Text("Lain-lain", style: TextStyle(fontFamily: 'Inter', fontSize: 14))),
              ],
              onChanged: (value) {
                setState(() {
                  selectedTingkat = value;
                });
              },
            ),
            const SizedBox(height: 16),



            // Tahun Ajaran
            _buildLabel("Tahun Ajaran"),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: tahunAwalController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                    decoration: _buildDecoration("2024"),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "/",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: tahunAkhirController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                    decoration: _buildDecoration("2025"),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: isLoading ? null : simpan,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      "Simpan",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
