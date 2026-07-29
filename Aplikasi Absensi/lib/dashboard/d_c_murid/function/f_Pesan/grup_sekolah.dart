import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:apk/dashboard/d_c_murid/database/db_grup_sekolah.dart';
import 'package:apk/dashboard/d_c_murid/function/f_Pesan/member_sekolah.dart';
import 'package:apk/dashboard/d_c_murid/function/f_Pesan/pengumuman_card.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:apk/dashboard/d_c_murid/database/storage/image_doc.dart';
import 'package:apk/dashboard/d_c_murid/function/f_Pesan/doc_image.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/grup_sekolah_n.dart';

class GrupSekolah extends StatefulWidget {
  const GrupSekolah({super.key});

  @override
  State<GrupSekolah> createState() => _GrupSekolahState();
}

class _GrupSekolahState extends State<GrupSekolah> {
  final TextEditingController _messageController = TextEditingController();
  
  bool _isLoading = true;
  String? _errorMessage;
  
  String? _currentUserId;
  String? _currentUserRole; // 'admin', 'guru', or 'murid'
  
  Stream<List<Map<String, dynamic>>>? _chatStream;
  Map<String, String> _userNames = {}; // mapping ID ke Nama

  @override
  void initState() {
    super.initState();
    _initChat();
    GrupSekolahNotification.setUnread(false);
  }

  Future<void> _initChat() async {
    try {
      // Fetch mapping nama semua user
      _userNames = await DbGrupSekolah.fetchAllNames();

      // Fetch current user info
      final currentUserInfo = await DbGrupSekolah.getCurrentUserRoleAndId();
      
      if (currentUserInfo != null) {
        _currentUserId = currentUserInfo['id'];
        _currentUserRole = currentUserInfo['role'];
        _chatStream = DbGrupSekolah().getGrupSekolahStream();
      } else {
        _errorMessage = 'Gagal memuat profil. Pastikan Anda telah login dengan benar.';
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final name = pickedFile.name;
      setState(() => _isLoading = true);
      final url = await ImageDocStorage.uploadFileObject(file, name);
      if (url != null) {
        await DbGrupSekolah().sendMessage(
          text: 'IMAGE_URL:$url',
          senderId: _currentUserId!,
          role: _currentUserRole!,
        );
        await _initChat();
      } else {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal unggah gambar')));
      }
    }
  }

  Future<void> _pickAndSendDoc() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'zip', 'rar'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      final name = result.files.single.name;
      setState(() => _isLoading = true);
      final url = await ImageDocStorage.uploadFile(bytes, name);
      if (url != null) {
        await DbGrupSekolah().sendMessage(
          text: 'DOC_URL:$url',
          senderId: _currentUserId!,
          role: _currentUserRole!,
        );
        await _initChat();
      } else {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal unggah dokumen')));
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null || _currentUserRole == null) return;

    _messageController.clear();

    try {
      await DbGrupSekolah().sendMessage(
        text: text,
        senderId: _currentUserId!,
        role: _currentUserRole!,
      );
      
      // Reload stream dari database setelah mengirim pesan
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
        await _initChat();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _formatTime(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('HH:mm').format(date);
    } catch (_) {
      return '';
    }
  }

  String _getSenderId(Map<String, dynamic> msg) {
    if (msg['pengirim_admin'] != null) return msg['pengirim_admin'].toString();
    if (msg['pengirim_guru'] != null) return msg['pengirim_guru'].toString();
    if (msg['pengirim_murid'] != null) return msg['pengirim_murid'].toString();
    return '';
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
        title: const Text("Grup Sekolah"),
        titleTextStyle: const TextStyle(
          fontFamily: "Inter",
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Anggota Grup',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MemberSekolahPage()),
              );
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))))
              : Column(
                  children: [
                    Expanded(
                      child: _chatStream == null
                          ? const Center(child: Text('Gagal memuat ruang obrolan'))
                          : StreamBuilder<List<Map<String, dynamic>>>(
                              stream: _chatStream,
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return Center(child: Text('Error: ${snapshot.error}'));
                                }
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                final messages = snapshot.data ?? [];

                                if (messages.isEmpty) {
                                  return const Center(child: Text('Belum ada pesan. Mulai obrolan!'));
                                }

                                return ListView.builder(
                                  reverse: true,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final msg = messages[messages.length - 1 - index];
                                    bool isMe = false;
                                    if (_currentUserRole == 'admin') {
                                      isMe = msg['pengirim_admin']?.toString() == _currentUserId;
                                    } else if (_currentUserRole == 'guru') {
                                      isMe = msg['pengirim_guru']?.toString() == _currentUserId;
                                    } else if (_currentUserRole == 'murid') {
                                      isMe = msg['pengirim_murid']?.toString() == _currentUserId;
                                    }
                                    final senderId = _getSenderId(msg);
                                    final senderName = _userNames[senderId] ?? 'Pengguna';

                                    return Align(
                                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(vertical: 6),
                                        child: Column(
                                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                          children: [
                                            if (!isMe)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 4, bottom: 2),
                                                child: Text(
                                                  senderName,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black54,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: isMe ? const Color(0xFF2563EB) : Colors.grey[200],
                                                borderRadius: BorderRadius.only(
                                                  topLeft: const Radius.circular(16),
                                                  topRight: const Radius.circular(16),
                                                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                                                  bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                                children: [
                                                  if (msg['text']?.toString().startsWith('PENGUMUMAN_ID:') == true)
                                                    PengumumanCard(pengumumanId: msg['text'].toString().split(':')[1])
                                                  else if (msg['text']?.toString().startsWith('IMAGE_URL:') == true)
                                                    GestureDetector(
                                                      onTap: () {
                                                        Navigator.push(context, MaterialPageRoute(builder: (_) => DocImagePreviewPage(imageUrl: msg['text'].toString().replaceFirst('IMAGE_URL:', ''))));
                                                      },
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: Image.network(
                                                          msg['text'].toString().replaceFirst('IMAGE_URL:', ''),
                                                          width: 200,
                                                          height: 200,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    )
                                                  else if (msg['text']?.toString().startsWith('DOC_URL:') == true)
                                                    Builder(
                                                      builder: (context) {
                                                        final url = msg['text'].toString().replaceFirst('DOC_URL:', '');
                                                        final uri = Uri.tryParse(url);
                                                        String fileName = 'Dokumen';
                                                        String extension = 'FILE';
                                                        
                                                        if (uri != null && uri.pathSegments.isNotEmpty) {
                                                          fileName = Uri.decodeComponent(uri.pathSegments.last);
                                                          final regex = RegExp(r'^\d{13}_');
                                                          fileName = fileName.replaceFirst(regex, '');
                                                          final extIndex = fileName.lastIndexOf('.');
                                                          if (extIndex != -1 && extIndex < fileName.length - 1) {
                                                            extension = fileName.substring(extIndex + 1).toUpperCase();
                                                          }
                                                        }

                                                        return GestureDetector(
                                                          onTap: () async {
                                                            final parsedUrl = Uri.parse(url);
                                                            try {
                                                              await launchUrl(parsedUrl, mode: LaunchMode.externalApplication);
                                                            } catch (e) {
                                                              if (context.mounted) {
                                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka dokumen')));
                                                              }
                                                            }
                                                          },
                                                          child: Container(
                                                            constraints: const BoxConstraints(maxWidth: 240),
                                                            padding: const EdgeInsets.all(8),
                                                            decoration: BoxDecoration(
                                                              color: isMe ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.5),
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Container(
                                                                  width: 42,
                                                                  height: 52,
                                                                  decoration: BoxDecoration(
                                                                    color: isMe ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.05),
                                                                    borderRadius: BorderRadius.circular(6),
                                                                  ),
                                                                  child: Center(
                                                                    child: Text(
                                                                      extension.length > 4 ? extension.substring(0, 4) : extension,
                                                                      style: TextStyle(
                                                                        fontSize: 12,
                                                                        fontWeight: FontWeight.bold,
                                                                        color: isMe ? Colors.white : Colors.black87,
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
                                                                        style: TextStyle(
                                                                          fontSize: 14,
                                                                          color: isMe ? Colors.white : Colors.black87,
                                                                          fontWeight: FontWeight.w500,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(height: 4),
                                                                      Text(
                                                                        '$extension • Dokumen',
                                                                        style: TextStyle(
                                                                          fontSize: 12,
                                                                          color: isMe ? Colors.white70 : Colors.black54,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    )
                                                  else
                                                    Text(
                                                      msg['text'] ?? '',
                                                      style: TextStyle(
                                                        color: isMe ? Colors.white : Colors.black87,
                                                      ),
                                                    ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _formatTime(msg['created_at']),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: isMe ? Colors.white70 : Colors.black54,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            offset: const Offset(0, -2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.attach_file, color: Colors.orange),
                            tooltip: 'Lampiran',
                            offset: const Offset(0, -120),
                            onSelected: (value) {
                              if (value == 'image') {
                                _pickAndSendImage();
                              } else if (value == 'document') {
                                _pickAndSendDoc();
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'image',
                                child: Row(
                                  children: [
                                    Icon(Icons.image, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('Gambar'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'document',
                                child: Row(
                                  children: [
                                    Icon(Icons.insert_drive_file, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Dokumen'),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Tulis pesan...',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: const Color(0xFF2563EB),
                            child: IconButton(
                              icon: const Icon(Icons.send, color: Colors.white, size: 20),
                              onPressed: _sendMessage,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
