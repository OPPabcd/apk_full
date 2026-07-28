import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:apk/dashboard/d_c_murid/database/db_pengumuman.dart';
import 'package:apk/dashboard/d_c_murid/function/f_Pesan/doc_image.dart';

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
