import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/database/db_siswa.dart';
import 'package:apk/dashboard/a_admin/function/f_kelas/form_kelas..dart';

class FormMuridPage extends StatefulWidget {
  const FormMuridPage({super.key});

  @override
  State<FormMuridPage> createState() => _FormMuridPageState();
}

class _FormMuridPageState extends State<FormMuridPage> {
  final MuridService service = MuridService();

  final nisController = TextEditingController();
  final namaController = TextEditingController();
  final alamatController = TextEditingController();
  final orangTuaController = TextEditingController();
  final noTeleController = TextEditingController();
  final tempatLahirController = TextEditingController();

  List<Map<String, dynamic>> kelasList = [];
  String? selectedClass;
  String? selectedGender;
  DateTime? selectedDate;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadKelas();
  }

  Future<void> loadKelas() async {
    final data = await service.getKelas();
    setState(() {
      kelasList = data;
    });
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2010),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> simpan() async {
    if (nisController.text.isEmpty ||
        namaController.text.isEmpty ||
        selectedClass == null ||
        selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Field wajib belum diisi!")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await service.addMurid(
        nis: nisController.text,
        nama: namaController.text,
        idClass: selectedClass,
        gender: selectedGender,
        tanggalLahir: selectedDate,
        alamat: alamatController.text,
        orangTua: orangTuaController.text,
        noTele: num.tryParse(noTeleController.text),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data berhasil disimpan")),
      );

      // reset form
      nisController.clear();
      namaController.clear();
      alamatController.clear();
      orangTuaController.clear();
      noTeleController.clear();
      tempatLahirController.clear();

      setState(() {
        selectedClass = null;
        selectedGender = null;
        selectedDate = null;
      });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }

    setState(() => isLoading = false);
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
          icon: Image.asset('lib/assets/icons/Button.png',
              width: 30, height: 30),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: -5,
        title: const Text("Form Murid"),
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
            // NIS
            _buildLabel("NIS *"),
            const SizedBox(height: 6),
            TextField(
              controller: nisController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              decoration: _buildDecoration("Masukkan Nomor Induk Siswa"),
            ),
            const SizedBox(height: 16),

            // Nama
            _buildLabel("Nama Lengkap *"),
            const SizedBox(height: 6),
            TextField(
              controller: namaController,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              decoration: _buildDecoration("Nama lengkap sesuai akta"),
            ),
            const SizedBox(height: 16),

            // Kelas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLabel("Kelas *"),
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
              isExpanded: true,
              value: selectedClass,
              hint: const Text(
                "Pilih Kelas",
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFFC4C4C4)),
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
            const SizedBox(height: 16),

            // Gender
            _buildLabel("Jenis Kelamin *"),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: selectedGender,
              hint: const Text(
                "Pilih Jenis Kelamin",
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFFC4C4C4)),
              ),
              decoration: _buildDecoration("").copyWith(hintText: null),
              items: const [
                DropdownMenuItem(
                  value: 'L',
                  child: Text("Laki-laki", style: TextStyle(fontFamily: 'Inter', fontSize: 14)),
                ),
                DropdownMenuItem(
                  value: 'P',
                  child: Text("Perempuan", style: TextStyle(fontFamily: 'Inter', fontSize: 14)),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedGender = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Tempat Lahir
            _buildLabel("Tempat Lahir"),
            const SizedBox(height: 6),
            TextField(
              controller: tempatLahirController,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              decoration: _buildDecoration("Kota/Kabupaten kelahiran"),
            ),
            const SizedBox(height: 16),

            // Tanggal Lahir
            _buildLabel("Tanggal Lahir"),
            const SizedBox(height: 6),
            InkWell(
              onTap: pickDate,
              child: InputDecorator(
                decoration: _buildDecoration(""),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedDate == null
                          ? "mm/dd/yyyy"
                          : selectedDate.toString().split(' ')[0],
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: selectedDate == null ? 12 : 14,
                        color: selectedDate == null ? const Color(0xFFC4C4C4) : Colors.black,
                      ),
                    ),
                    const Icon(Icons.calendar_today, size: 18, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),



            // Alamat
            _buildLabel("Alamat"),
            const SizedBox(height: 6),
            TextField(
              controller: alamatController,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              decoration: _buildDecoration("Masukkan alamat"),
            ),
            const SizedBox(height: 16),

            // Orang Tua
            _buildLabel("Orang Tua"),
            const SizedBox(height: 6),
            TextField(
              controller: orangTuaController,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              decoration: _buildDecoration("Nama orang tua"),
            ),
            const SizedBox(height: 16),

            // No HP
            _buildLabel("No Telepon"),
            const SizedBox(height: 6),
            TextField(
              controller: noTeleController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              decoration: _buildDecoration("Masukkan nomor telepon"),
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