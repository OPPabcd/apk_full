import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:apk/dashboard/d_c_murid/database/db_pengumuman.dart';
import 'package:apk/dashboard/d_c_murid/function/f_Pesan/doc_image.dart';

class PreviewPengumuman extends StatefulWidget {
  const PreviewPengumuman({super.key});

  @override
  State<PreviewPengumuman> createState() => _PreviewPengumumanState();
}

class _PreviewPengumumanState extends State<PreviewPengumuman> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _pengumumanList = [];

  @override
  void initState() {
    super.initState();
    _fetchPengumuman();
  }

  Future<void> _fetchPengumuman() async {
    try {
      // Hapus otomatis pengumuman yang sudah berakhir
      await DbPengumuman.deleteExpiredPengumuman();

      // Mengambil semua pengumuman yang diurutkan dari yang terbaru
      final response = await supabase
          .from('pengumuman')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        _pengumumanList = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat pengumuman: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return isoString;
    }
  }

  // Cek jika pengumuman masih aktif berdasarkan tanggal selesai
  bool _isActive(String tanggalSelesai) {
    try {
      final date = DateTime.parse(tanggalSelesai);
      final now = DateTime.now();
      // Bandingkan tanpa peduli jam (hanya tanggal)
      final endDate = DateTime(date.year, date.month, date.day, 23, 59, 59);
      return now.isBefore(endDate) || now.isAtSameMomentAs(endDate);
    } catch (_) {
      return true;
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
        title: const Text("Pengumuman Sekolah & Kelas"),
        titleTextStyle: const TextStyle(
          fontFamily: "Inter",
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontFamily: 'Inter')),
                  ),
                )
              : _pengumumanList.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _fetchPengumuman,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pengumumanList.length,
                        itemBuilder: (context, index) {
                           final p = _pengumumanList[index];
                           final bool active = _isActive(p['tanggal_selesai']);

                           // Memisahkan keterangan dan URL lampiran jika ada
                           String textKeterangan = p['keterangan'] ?? '';
                           List<String> lampiranUrls = [];
                           
                           if (textKeterangan.contains('Lampiran: ')) {
                             final parts = textKeterangan.split('Lampiran: ');
                             textKeterangan = parts[0].trim();
                             final urlsString = parts.length > 1 ? parts[1].trim() : '';
                             lampiranUrls = urlsString.split(RegExp(r'\s+')).where((s) => s.startsWith('http')).toList();
                           }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shadowColor: Colors.black.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: active ? const Color(0xFF2563EB).withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p['title'] ?? 'Tanpa Judul',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: active ? const Color(0xFF1E293B) : Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: active ? const Color(0xFFEFF6FF) : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          active ? 'Aktif' : 'Berakhir',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: active ? const Color(0xFF2563EB) : Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.date_range, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_formatDate(p['tanggal_mulai'])} - ${_formatDate(p['tanggal_selesai'])}',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (textKeterangan.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        textKeterangan,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 14,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (lampiranUrls.isNotEmpty) ...[
                                    const SizedBox(height: 12),
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
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => DocImagePreviewPage(imageUrl: lampiranUrl),
                                                    ),
                                                  );
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
                                                onTap: () => _launchURL(lampiranUrl),
                                                child: Container(
                                                  constraints: const BoxConstraints(maxWidth: 240),
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
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
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 16),
                                    FutureBuilder<String?>(
                                      future: _getDocUrl(p['id_tabel']),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          );
                                        }
                                        
                                        final url = snapshot.data;
                                        if (url != null && url.isNotEmpty) {
                                          return SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              icon: const Icon(Icons.attach_file, size: 18),
                                              label: const Text('Buka Lampiran Dokumen', style: TextStyle(fontFamily: 'Inter')),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFF2563EB),
                                                side: const BorderSide(color: Color(0xFF2563EB)),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                              onPressed: () => _launchURL(url),
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Tidak Ada Pengumuman',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Belum ada pengumuman yang dibagikan.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _getDocUrl(String id) async {
    try {
      // Format file dari db_pengumuman.dart adalah doc_$id
      // Namun kita perlu cek apakah file itu ada. Supabase API tidak punya "exists" yang simpel, 
      // tapi kita bisa coba membuat publicUrl.
      final String url = Supabase.instance.client.storage
          .from('pengumuman')
          .getPublicUrl('doc_$id');
          
      // Supabase selalu mengembalikan URL publik meskipun file tidak ada. 
      // Untuk memvalidasi, bisa gunakan head/list, namun demi performa kita kembalikan saja URL-nya.
      // Jika pengguna menekan, mereka akan diarahkan ke browser dan melihat NotFound jika kosong.
      return url;
    } catch (e) {
      return null;
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat membuka tautan: $url')),
        );
      }
    }
  }
}
