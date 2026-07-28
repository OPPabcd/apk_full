import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/database/db_guru.dart';
import 'package:apk/dashboard/a_admin/function/f_kelas/form_kelas..dart';

class FormGuruPage extends StatefulWidget {
  const FormGuruPage({super.key});

  @override
  State<FormGuruPage> createState() => _FormGuruPageState();
}

class _FormGuruPageState extends State<FormGuruPage> {
  final nikController = TextEditingController();
  final namaController = TextEditingController();
  final bidangController = TextEditingController();

  List<Map<String, dynamic>> kelasList = [];
  String? selectedClass;
  bool isWali = false;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadKelas();
  }

  Future<void> loadKelas() async {
    final data = await GuruService.getKelas();
    setState(() {
      kelasList = data;
    });
  }

  Future<void> simpan() async {
    if (nikController.text.isEmpty || namaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("NIK dan Nama wajib diisi!")),
      );
      return;
    }

    if (isWali && selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kelas wajib dipilih jika menjadi Wali Kelas!")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await GuruService.tambahGuru(
        nik: nikController.text,
        name: namaController.text,
        bidang: bidangController.text.isEmpty ? null : bidangController.text,
        idClass: selectedClass,
        wali: isWali,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data guru berhasil disimpan")),
      );

      // reset form
      nikController.clear();
      namaController.clear();
      bidangController.clear();

      setState(() {
        selectedClass = null;
        isWali = false;
      });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
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
        title: const Text("Form Guru"),
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
            // NIK
            _buildLabel("NIK *"),
            const SizedBox(height: 6),
            TextField(
              controller: nikController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              decoration: _buildDecoration("Masukkan NIK Guru"),
            ),
            const SizedBox(height: 16),

            // Nama
            _buildLabel("Nama Lengkap *"),
            const SizedBox(height: 6),
            TextField(
              controller: namaController,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              decoration: _buildDecoration("Nama Lengkap Guru"),
            ),
            const SizedBox(height: 16),

            // Bidang
            _buildLabel("Bidang Mata Pelajaran"),
            const SizedBox(height: 6),
            TextField(
              controller: bidangController,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              decoration: _buildDecoration("Contoh: Matematika"),
            ),
            const SizedBox(height: 16),

            // Pilih sebagai
            _buildLabel("Pilih sebagai"),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Card(
                    color: const Color(0xFFF1F5F9),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          isWali = true;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Wali Kelas", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600)),
                            Checkbox(
                              value: isWali,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (val) {
                                setState(() {
                                  isWali = true;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: const Color(0xFFF1F5F9),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          isWali = false;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Guru", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600)),
                            Checkbox(
                              value: !isWali,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (val) {
                                setState(() {
                                  isWali = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Kelas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLabel("Pilih Kelas (Wajib jika Wali Kelas)"),
                TextButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FormKelasPage()),
                    );
                    loadKelas();
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    "Buat Kelas",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: selectedClass,
              hint: const Text(
                "Pilih Kelas",
                style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFFC4C4C4)),
              ),
              decoration: _buildDecoration("").copyWith(hintText: null),
              items: kelasList.map((kelas) {
                return DropdownMenuItem<String>(
                  value: kelas['id_tabel'],
                  child: Text(
                    kelas['name_class'],
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedClass = value;
                });
              },
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
