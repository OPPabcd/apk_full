import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/database/db_guru.dart';

class UpdateGuruPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const UpdateGuruPage({
    super.key,
    required this.data,
  });

  @override
  State<UpdateGuruPage> createState() => _UpdateGuruPageState();
}

class _UpdateGuruPageState extends State<UpdateGuruPage> {
  bool isSaving = false;

  late TextEditingController nikC;
  late TextEditingController nameC;
  late TextEditingController bidangC;

  List<Map<String, dynamic>> kelasList = [];
  String? selectedKelas;
  late bool isWali;

  @override
  void initState() {
    super.initState();

    nikC = TextEditingController(text: widget.data['nik']?.toString() ?? "");
    nameC = TextEditingController(text: widget.data['name'] ?? "");
    bidangC = TextEditingController(text: widget.data['bidang'] ?? "");

    selectedKelas = widget.data['id_class'];
    isWali = widget.data['wali'] == true;

    loadKelas();
  }

  Future<void> loadKelas() async {
    final data = await GuruService.getKelas();
    if (mounted) {
      setState(() => kelasList = data);
    }
  }

  Future<void> updateData() async {
    if (nikC.text.isEmpty || nameC.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("NIK dan Nama wajib diisi!")),
      );
      return;
    }

    if (isWali && selectedKelas == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kelas wajib dipilih jika menjadi Wali Kelas!"),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      await GuruService.updateGuru(
        idTabel: widget.data['id_tabel'],
        nik: nikC.text,
        name: nameC.text,
        bidang: bidangC.text.isEmpty ? null : bidangC.text,
        idClass: selectedKelas,
        wali: isWali,
      );

      final selectedKelasData = kelasList.where(
        (kelas) => kelas['id_tabel'] == selectedKelas,
      );

      if (mounted) {
        final Map<String, dynamic> updatedData = Map.from(widget.data);
        updatedData['nik'] = nikC.text;
        updatedData['name'] = nameC.text;
        updatedData['bidang'] = bidangC.text;
        updatedData['id_class'] = selectedKelas;
        updatedData['wali'] = isWali;
        updatedData['class_name'] = selectedKelasData.isEmpty
            ? null
            : {
                'id_tabel': selectedKelasData.first['id_tabel'],
                'name_class': selectedKelasData.first['name_class'],
              };

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data guru berhasil diperbarui')),
        );
        Navigator.pop(context, updatedData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Gagal menyimpan: ${e.toString().replaceAll('Exception: ', '')}",
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Widget field(
    String label,
    TextEditingController c, {
    TextInputType? keyboardType,
    String hint = "",
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
          controller: c,
          keyboardType: keyboardType,
          style: const TextStyle(fontFamily: 'Inter'),
          decoration: InputDecoration(
            hintText: hint,
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

  Widget kelasField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Kelas",
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: selectedKelas,
          decoration: InputDecoration(
            hintText: "Pilih Kelas",
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
          items: kelasList.map((e) {
            return DropdownMenuItem<String>(
              value: e['id_tabel'],
              child: Text(e['name_class'], style: const TextStyle(fontFamily: 'Inter')),
            );
          }).toList(),
          onChanged: (v) => setState(() => selectedKelas = v),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget waliField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Wali Kelas",
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Jadikan Wali Kelas",
                style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF1E293B)),
              ),
              Switch(
                value: isWali,
                activeColor: const Color(0xFF2563EB),
                onChanged: (val) => setState(() => isWali = val),
              ),
            ],
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
    return Expanded(
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
  void dispose() {
    nikC.dispose();
    nameC.dispose();
    bidangC.dispose();
    super.dispose();
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
        title: const Text("Edit Data Guru"),
        titleTextStyle: const TextStyle(
          fontFamily: "Inter",
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  Row(
                    children: const [
                      Text("👩‍🏫", style: TextStyle(fontSize: 14)),
                      SizedBox(width: 8),
                      Text(
                        "Data Guru",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                        field("NIK *", nikC, keyboardType: TextInputType.number, hint: "Contoh: 33111"),
                        field("Nama *", nameC, hint: "Contoh: Budi Santoso"),
                        field("Bidang", bidangC, hint: "Contoh: Matematika"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: const [
                      Text("🏫", style: TextStyle(fontSize: 14)),
                      SizedBox(width: 8),
                      Text(
                        "Wali Kelas & Kelas",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                        waliField(),
                        if (isWali || selectedKelas != null) kelasField(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _actionButton(
                  label: "Simpan",
                  color: const Color(0xFF2563EB),
                  onPressed: isSaving ? null : updateData,
                  loading: isSaving,
                ),
                const SizedBox(width: 10),
                _actionButton(
                  label: "Batal",
                  color: Colors.white,
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
