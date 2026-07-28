import 'package:flutter/material.dart';
import 'package:apk/dashboard/d_guru/database/db_guru.dart';

class UpdateProfilPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const UpdateProfilPage({
    super.key,
    required this.data,
  });

  @override
  State<UpdateProfilPage> createState() => _UpdateProfilPageState();
}

class _UpdateProfilPageState extends State<UpdateProfilPage> {
  bool isSaving = false;

  late TextEditingController nikC;
  late TextEditingController nameC;
  late TextEditingController bidangC;

  final DbGuru _dbGuru = DbGuru();

  @override
  void initState() {
    super.initState();
    nikC = TextEditingController(text: widget.data['nik']?.toString() ?? "");
    nameC = TextEditingController(text: widget.data['name'] ?? "");
    bidangC = TextEditingController(text: widget.data['bidang'] ?? "");
  }

  Future<void> updateData() async {
    if (nikC.text.isEmpty || nameC.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("NIK dan Nama wajib diisi!")),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      await _dbGuru.updateGuru(
        idTabel: widget.data['id_tabel'],
        nik: num.tryParse(nikC.text) ?? 0,
        name: nameC.text,
        bidang: bidangC.text.isEmpty ? null : bidangC.text,
        idClass: widget.data['id_class'], // keep unchanged
        wali: widget.data['wali'] == true, // keep unchanged
      );

      if (mounted) {
        widget.data['nik'] = num.tryParse(nikC.text) ?? 0;
        widget.data['name'] = nameC.text;
        widget.data['bidang'] = bidangC.text;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui')),
        );
        Navigator.pop(context, true);
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
        title: const Text("Edit Setting Profil", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
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
                      Text("👩‍🏫", style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Text(
                        "Data Guru",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
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
