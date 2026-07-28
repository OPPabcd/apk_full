import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:apk/dashboard/a_admin/database/db_pengumuman.dart';
import 'package:apk/dashboard/a_admin/database/storage/doc_pengumuman.dart';
import 'package:apk/dashboard/a_admin/database/db_grup_sekolah.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:apk/dashboard/a_admin/function/f_pesan/doc_image_page.dart';

class PengumumanPage extends StatefulWidget {
  const PengumumanPage({super.key});

  @override
  State<PengumumanPage> createState() => _PengumumanPageState();
}

class _PengumumanPageState extends State<PengumumanPage> {
  final _titleController = TextEditingController();
  final _keteranganController = TextEditingController();
  DateTime? _tanggalMulai;
  DateTime? _tanggalSelesai;
  List<PlatformFile> _selectedFiles = [];
  bool _isLoading = false;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: true,
      withData: true,
    );

    if (result != null) {
      setState(() {
        for (var file in result.files) {
          if (file.bytes != null) {
            _selectedFiles.add(file);
          }
        }
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _tanggalMulai = picked;
        } else {
          _tanggalSelesai = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty || _tanggalMulai == null || _tanggalSelesai == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi Title, Tanggal Mulai, dan Tanggal Selesai')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Upload File if any
      List<String> uploadedUrls = [];
      for (var file in _selectedFiles) {
        if (file.bytes != null && file.extension != null) {
          await Future.delayed(const Duration(milliseconds: 10)); // Ensure unique timestamp
          final url = await DocPengumuman.uploadDoc(file.bytes!, _titleController.text, file.extension!);
          if (url != null) uploadedUrls.add(url);
        }
      }

      // 2. Determine Guru ID if sender is guru
      final roleInfo = await DbGrupSekolah.getCurrentUserRoleAndId();
      String? idGuru;
      if (roleInfo != null && roleInfo['role'] == 'guru') {
        idGuru = roleInfo['id'];
      }

      // 3. Insert Pengumuman
      String keterangan = _keteranganController.text;
      if (uploadedUrls.isNotEmpty) {
         keterangan += '\n\nLampiran: ${uploadedUrls.join(' ')}';
      }

      final pengumuman = await DbPengumuman.insertPengumuman(
        title: _titleController.text,
        tanggalMulai: DateFormat('yyyy-MM-dd').format(_tanggalMulai!),
        tanggalSelesai: DateFormat('yyyy-MM-dd').format(_tanggalSelesai!),
        keterangan: keterangan,
        idGuru: idGuru,
      );

      final pengumumanId = pengumuman['id_tabel'];

      // 4. Send to Grup Sekolah
      if (roleInfo != null) {
        await DbGrupSekolah().sendMessage(
          text: 'PENGUMUMAN_ID:$pengumumanId',
          senderId: roleInfo['id']!,
          role: roleInfo['role']!,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengumuman berhasil dikirim ke Grup Sekolah')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      backgroundColor: const Color(0xFF2563EB),
      elevation: 0,
      automaticallyImplyLeading: true,
      leading: IconButton(
        icon: Image.asset('lib/assets/icons/Button.png', width: 30, height: 30),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: -5,
      title: const Text('Buat Pengumuman'),
      titleTextStyle: const TextStyle(
        fontFamily: "Inter",
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );

    if (_isLoading) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: appBar,
      body: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  const Text("Title", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(fontFamily: 'Inter'),
                    decoration: InputDecoration(
                      hintText: "Judul Pengumuman (Title)",
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

                  // Dates
                  Row(
                    children: [
                      Expanded(child: _buildDateCard("Tanggal Mulai", _tanggalMulai, true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDateCard("Tanggal Selesai", _tanggalSelesai, false)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Keterangan
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Keterangan", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
                      Row(
                        children: const [
                          Icon(Icons.format_size, size: 16, color: Colors.grey),
                          SizedBox(width: 4),
                          Icon(Icons.edit, size: 16, color: Colors.grey),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _keteranganController,
                    maxLines: 5,
                    style: const TextStyle(fontFamily: 'Inter'),
                    decoration: InputDecoration(
                      hintText: "Tuliskan isi pengumuman secara detail di sini...",
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

                  // Upload
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.upload_file, color: Colors.purple),
                      label: const Text('Upload Doc/Image', style: TextStyle(fontFamily: 'Inter', color: Colors.purple)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Colors.purple, width: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      ),
                    ),
                  ),
                  if (_selectedFiles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text("Uploaded Files : ", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedFiles.map((file) {
                        final ext = file.extension?.toLowerCase() ?? '';
                        final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isImage ? Icons.image : Icons.picture_as_pdf,
                                color: isImage ? Colors.green : Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  file.name,
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedFiles.remove(file);
                                  });
                                },
                                child: const Icon(Icons.close, size: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A), // Dark blue
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Tulis Pengumuman', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDateCard(String title, DateTime? date, bool isStart) {
    return GestureDetector(
      onTap: () => _selectDate(context, isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ]
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    date == null ? '-' : DateFormat('dd MMM yyyy').format(date),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.black87),
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

// Widget untuk menampilkan Pengumuman di dalam obrolan Grup Sekolah
class PengumumanCard extends StatelessWidget {
  final String pengumumanId;
  const PengumumanCard({super.key, required this.pengumumanId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: DbPengumuman.getPengumumanById(pengumumanId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                height: 50,
                width: 50,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Pengumuman tidak ditemukan'),
            ),
          );
        }

        final data = snapshot.data!;
        
        // Memisahkan keterangan dan URL lampiran jika ada
        String textKeterangan = data['keterangan'] ?? '';
        List<String> lampiranUrls = [];
        
        if (textKeterangan.contains('Lampiran: ')) {
          final parts = textKeterangan.split('Lampiran: ');
          textKeterangan = parts[0].trim();
          final urlsString = parts.length > 1 ? parts[1].trim() : '';
          lampiranUrls = urlsString.split(RegExp(r'\s+')).where((s) => s.startsWith('http')).toList();
        }

        return Card(
          color: Colors.amber[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.campaign, color: Colors.amber, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data['title'] ?? 'Pengumuman',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    const Icon(Icons.date_range, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${data['tanggal_mulai']} s/d ${data['tanggal_selesai']}',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
                if (textKeterangan.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(textKeterangan, style: const TextStyle(fontSize: 14)),
                ],
                if (lampiranUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: lampiranUrls.map((lampiranUrl) {
                      return Builder(
                        builder: (context) {
                          final uri = Uri.tryParse(lampiranUrl);
                          String extension = 'FILE';
                          String fileName = 'Lampiran';
                          if (uri != null && uri.pathSegments.isNotEmpty) {
                            final fullName = Uri.decodeComponent(uri.pathSegments.last);
                            fileName = fullName.replaceFirst(RegExp(r'^\d{13}_'), '');
                            final extIndex = fullName.lastIndexOf('.');
                            if (extIndex != -1 && extIndex < fullName.length - 1) {
                              extension = fullName.substring(extIndex + 1).toLowerCase();
                            }
                          }
                          bool isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);

                          if (isImage) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => DocImagePreviewPage(imageUrl: lampiranUrl)));
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  lampiranUrl,
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          } else {
                            return GestureDetector(
                              onTap: () async {
                                final parsedUrl = Uri.parse(lampiranUrl);
                                try {
                                  await launchUrl(parsedUrl, mode: LaunchMode.externalApplication);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka lampiran')));
                                  }
                                }
                              },
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 240),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          extension.length > 4 ? extension.substring(0, 4).toUpperCase() : extension.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fileName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${extension.toUpperCase()} • Dokumen',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        },
                      );
                    }).toList(),
                  )
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}
