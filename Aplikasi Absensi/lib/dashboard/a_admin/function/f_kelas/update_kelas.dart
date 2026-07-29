import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/database/db_kelas.dart';
import 'package:apk/dashboard/a_admin/function/f_murid/form_murid.dart';
import 'package:apk/dashboard/a_admin/function/f_guru/form_guru.dart';

class UpdateKelasPage extends StatefulWidget {
  final Map<String, dynamic> classData;

  const UpdateKelasPage({super.key, required this.classData});

  @override
  State<UpdateKelasPage> createState() => _UpdateKelasPageState();
}

class _UpdateKelasPageState extends State<UpdateKelasPage> {
  final nameController = TextEditingController();
  final levelController = TextEditingController();
  final tahunController = TextEditingController();

  bool isLoading = false;

  List<Map<String, dynamic>> muridInClass = [];
  List<Map<String, dynamic>> guruInClass = [];
  
  List<Map<String, dynamic>> muridUnassigned = [];
  List<Map<String, dynamic>> guruUnassigned = [];

  @override
  void initState() {
    super.initState();
    nameController.text = widget.classData['name_class']?.toString() ?? '';
    levelController.text = widget.classData['id_class']?.toString() ?? '';
    tahunController.text = widget.classData['tahun']?.toString() ?? '';
    
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);
    try {
      final idTabel = widget.classData['id_tabel'];
      final mc = await ClassService.getMuridByClass(idTabel);
      final gc = await ClassService.getGuruByClass(idTabel);
      final mu = await ClassService.getMuridUnassigned();
      final gu = await ClassService.getGuruUnassigned();

      setState(() {
        muridInClass = mc;
        guruInClass = gc;
        muridUnassigned = mu;
        guruUnassigned = gu;
      });
    } catch (e) {
      print("Error fetching update data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> simpanInfoKelas() async {
    if (nameController.text.isEmpty || levelController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama Kelas dan Tingkat Kelas wajib diisi!")),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      await ClassService.updateKelas(
        idTabel: widget.classData['id_tabel'],
        idClass: int.tryParse(levelController.text) ?? 1,
        nameClass: nameController.text,
        tahun: tahunController.text.isEmpty ? null : tahunController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Info kelas berhasil diupdate")),
      );
      Navigator.pop(context, {
        'name_class': nameController.text,
        'id_class': int.tryParse(levelController.text) ?? 1,
        'tahun': tahunController.text.isEmpty ? null : tahunController.text,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal mengupdate info: $e")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> hapusKelas() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Kelas"),
        content: const Text("Yakin ingin menghapus kelas ini? Semua guru dan murid di kelas ini akan dikeluarkan dari kelas."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => isLoading = true);
    try {
      await ClassService.deleteKelas(widget.classData['id_tabel']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kelas berhasil dihapus")),
      );
      Navigator.pop(context); // close update page
      Navigator.pop(context); // close detail page, back to list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal menghapus kelas: $e")),
      );
      setState(() => isLoading = false);
    }
  }

  void assignGuru(String idGuru, bool asWali) async {
    setState(() => isLoading = true);
    try {
      await ClassService.assignGuruToClass(idGuru, widget.classData['id_tabel'], isWali: asWali);
      await fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal assign guru: $e")));
      setState(() => isLoading = false);
    }
  }

  void unassignGuru(String idGuru) async {
    setState(() => isLoading = true);
    try {
      await ClassService.removeGuruFromClass(idGuru);
      await fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal remove guru: $e")));
      setState(() => isLoading = false);
    }
  }

  void assignMurid(String idMurid) async {
    setState(() => isLoading = true);
    try {
      await ClassService.assignMuridToClass(idMurid, widget.classData['id_tabel']);
      await fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal assign murid: $e")));
      setState(() => isLoading = false);
    }
  }

  void unassignMurid(String idMurid) async {
    setState(() => isLoading = true);
    try {
      await ClassService.removeMuridFromClass(idMurid);
      await fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal remove murid: $e")));
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Image.asset('lib/assets/icons/Button.png', width: 30, height: 30),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: -5,
        title: const Text("Update Kelas"),
        titleTextStyle: const TextStyle(
          fontFamily: "Inter",
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionTitle("Informasi Kelas"),
                _buildInfoForm(),
                const SizedBox(height: 30),
                
                _buildSectionTitle(
                  "Kelola Guru",
                  onAdd: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const FormGuruPage())).then((_) => fetchData());
                  },
                ),
                _buildGuruList(),
                
                const SizedBox(height: 30),
                _buildSectionTitle(
                  "Kelola Murid",
                  onAdd: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const FormMuridPage())).then((_) => fetchData());
                  },
                ),
                _buildMuridList(),

                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: hapusKelas,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red[700],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.red[200]!),
                    ),
                  ),
                  child: const Text("Hapus Kelas", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title, {VoidCallback? onAdd}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          if (onAdd != null)
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Buat Baru"),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Nama Kelas"),
          const SizedBox(height: 6),
          TextField(
            controller: nameController,
            decoration: _inputDecoration("Contoh: Kelas 1A"),
          ),
          const SizedBox(height: 16),

          const Text("Tingkat Kelas (Angka)"),
          const SizedBox(height: 6),
          TextField(
            controller: levelController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration("Contoh: 1"),
          ),
          const SizedBox(height: 16),

          const Text("Tahun Ajaran"),
          const SizedBox(height: 6),
          TextField(
            controller: tahunController,
            decoration: _inputDecoration("Contoh: 2023/2024"),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: simpanInfoKelas,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Simpan Perubahan", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildGuruList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
             color: Colors.black.withOpacity(0.05),
             blurRadius: 10,
             offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (guruInClass.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Guru di kelas ini:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
            ...guruInClass.map((g) => ListTile(
              title: Text(g['name'] ?? ''),
              subtitle: Text(g['wali'] == true ? "Wali Kelas" : "Guru Mapel"),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red),
                onPressed: () => unassignGuru(g['id_tabel']),
              ),
            )),
            const Divider(),
          ],
          
          if (guruUnassigned.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Tambahkan Guru:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            ),
            ...guruUnassigned.map((g) => ListTile(
              title: Text(g['name'] ?? ''),
              subtitle: Text("Mapel: ${g['bidang'] ?? '-'}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => assignGuru(g['id_tabel'], true),
                    child: const Text("Jadikan Wali"),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    onPressed: () => assignGuru(g['id_tabel'], false),
                  ),
                ],
              ),
            )),
          ] else if (guruInClass.isEmpty) ...[
             const Padding(
               padding: EdgeInsets.all(16),
               child: Text("Tidak ada guru yang tersedia."),
             )
          ]
        ],
      ),
    );
  }

  Widget _buildMuridList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
             color: Colors.black.withOpacity(0.05),
             blurRadius: 10,
             offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (muridInClass.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Murid di kelas ini:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
            ...muridInClass.map((m) => ListTile(
              title: Text(m['nama'] ?? ''),
              subtitle: Text("NIS: ${m['nis'] ?? '-'}"),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red),
                onPressed: () => unassignMurid(m['id_tabel']),
              ),
            )),
            const Divider(),
          ],
          
          if (muridUnassigned.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Tambahkan Murid:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            ),
            ...muridUnassigned.map((m) => ListTile(
              title: Text(m['nama'] ?? ''),
              subtitle: Text("NIS: ${m['nis'] ?? '-'}"),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: () => assignMurid(m['id_tabel']),
              ),
            )),
          ] else if (muridInClass.isEmpty) ...[
             const Padding(
               padding: EdgeInsets.all(16),
               child: Text("Tidak ada murid yang tersedia."),
             )
          ]
        ],
      ),
    );
  }
}
