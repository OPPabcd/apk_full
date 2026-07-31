import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/database/db_siswa.dart';

class UpdateMuridPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const UpdateMuridPage({
    super.key,
    required this.data,
  });

  @override
  State<UpdateMuridPage> createState() => _UpdateMuridPageState();
}

class _UpdateMuridPageState extends State<UpdateMuridPage> {
  final service = MuridService();

  bool isSaving = false;

  late TextEditingController nisC;
  late TextEditingController namaC;
  late TextEditingController genderC;
  late TextEditingController tglC;
  late TextEditingController alamatC;
  late TextEditingController ortuC;
  late TextEditingController teleC;

  List<Map<String, dynamic>> kelasList = [];
  String? selectedKelas;

  @override
  void initState() {
    super.initState();

    nisC = TextEditingController(text: widget.data['nis']?.toString() ?? "");
    namaC = TextEditingController(text: widget.data['nama'] ?? "");
    genderC = TextEditingController(text: widget.data['gender'] ?? "");
    tglC = TextEditingController(
      text: widget.data['tanggal_lahir']?.toString() ?? "",
    );
    alamatC = TextEditingController(text: widget.data['alamat'] ?? "");
    ortuC = TextEditingController(text: widget.data['orang_tua'] ?? "");
    teleC = TextEditingController(
      text: widget.data['no_tele']?.toString() ?? "",
    );

    selectedKelas = widget.data['id_class'];

    loadKelas();
  }

  Future<void> loadKelas() async {
    final data = await service.getKelas();
    if (mounted) {
      setState(() => kelasList = data);
    }
  }

  Future<void> updateData() async {
    setState(() => isSaving = true);

    try {
      await service.updateMurid(
        idTabel: widget.data['id_tabel'],
        nis: nisC.text,
        nama: namaC.text,
        idClass: selectedKelas,
        gender: genderC.text,
        tanggalLahir: tglC.text.isEmpty ? null : DateTime.tryParse(tglC.text),
        alamat: alamatC.text,
        orangTua: ortuC.text,
        noTele: num.tryParse(teleC.text),
      );

      final selectedKelasData = kelasList.where(
        (kelas) => kelas['id_tabel'] == selectedKelas,
      );

      if (mounted) {
        final Map<String, dynamic> updatedData = Map.from(widget.data);
        updatedData['nis'] = nisC.text;
        updatedData['nama'] = namaC.text;
        updatedData['id_class'] = selectedKelas;
        updatedData['gender'] = genderC.text;
        updatedData['tanggal_lahir'] = tglC.text;
        updatedData['alamat'] = alamatC.text;
        updatedData['orang_tua'] = ortuC.text;
        updatedData['no_tele'] = num.tryParse(teleC.text);
        updatedData['class_name'] = selectedKelasData.isEmpty
            ? null
            : {
                'id_tabel': selectedKelasData.first['id_tabel'],
                'name_class': selectedKelasData.first['name_class'],
              };

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data murid berhasil diperbarui')),
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

  Future<void> _pickDate() async {
    final initialDate = DateTime.tryParse(tglC.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        tglC.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Widget field(String label, TextEditingController c, {String hint = "", VoidCallback? onTap, bool readOnly = false}) {
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
          onTap: onTap,
          readOnly: readOnly,
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

  Widget genderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Gender",
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: genderC.text.isEmpty ? null : genderC.text,
          decoration: InputDecoration(
            hintText: "Pilih Gender",
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
          items: const [
            DropdownMenuItem(value: "L", child: Text("L", style: TextStyle(fontFamily: 'Inter'))),
            DropdownMenuItem(value: "P", child: Text("P", style: TextStyle(fontFamily: 'Inter'))),
          ],
          onChanged: (v) => setState(() => genderC.text = v ?? ""),
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
    nisC.dispose();
    namaC.dispose();
    genderC.dispose();
    tglC.dispose();
    alamatC.dispose();
    ortuC.dispose();
    teleC.dispose();
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
        title: const Text("Edit Data Murid"),
        titleTextStyle: const TextStyle(
          fontFamily: "Inter",
          fontSize: 16,
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
                      Text("📋", style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Text(
                        "Data Utama",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
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
                        field("NIS *", nisC, hint: "Contoh: 332817"),
                        field("Nama *", namaC, hint: "Contoh: Budi Santoso"),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: genderField()),
                            const SizedBox(width: 16),
                            Expanded(
                              child: field(
                                "Tanggal Lahir",
                                tglC,
                                hint: "YYYY-MM-DD",
                                readOnly: true,
                                onTap: _pickDate,
                              ),
                            ),
                          ],
                        ),
                        kelasField(),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Row(
                    children: const [
                      Text("📚", style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Text(
                        "Kontak & Orang Tua",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
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
                        field("Alamat", alamatC, hint: "Masukkan alamat"),
                        field("Orang Tua", ortuC, hint: "Nama orang tua"),
                        field("No Telepon", teleC, hint: "Nomor telepon"),
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
