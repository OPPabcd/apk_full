import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apk/dashboard/d_guru/database/db_pesan_private.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:apk/dashboard/d_guru/database/storage/image_doc.dart';
import 'package:apk/dashboard/d_guru/function/f_pesan_g/doc_image.dart';
import 'package:apk/dashboard/d_guru/function/f_pesan_g/f_notif/chat_private_n.dart';

class ChatAdminPageG extends StatefulWidget {
  const ChatAdminPageG({super.key});

  @override
  State<ChatAdminPageG> createState() => _ChatAdminPageGState();
}

class _ChatAdminPageGState extends State<ChatAdminPageG> {
  final TextEditingController _messageController = TextEditingController();
  final DbPesanPrivate _dbPesan = DbPesanPrivate();
  
  bool _isLoading = true;
  String? _errorMessage;
  String? _idAdmin;
  String? _idGuru;
  String? _userIdAdmin;
  
  Stream<List<Map<String, dynamic>>>? _chatStream;

  @override
  void initState() {
    super.initState();
    _fetchIdentities();
  }

  Future<void> _fetchIdentities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nik = prefs.getString('guru_nik');
      _userIdAdmin = prefs.getString('user_id_admin');

      if (nik == null || _userIdAdmin == null) {
        throw Exception('Data login tidak lengkap (NIK atau User ID kosong)');
      }

      // 1. Dapatkan id_guru (id_tabel)
      final guruRes = await Supabase.instance.client
          .from('guru')
          .select('id_tabel')
          .eq('user_id', _userIdAdmin!)
          .eq('nik', nik)
          .single();
      _idGuru = guruRes['id_tabel']?.toString();

      // 2. Dapatkan id_admin dari user_admin. Kolom `id` di tabel user_admin
      // adalah foreign key yang terhubung langsung ke auth.users(id).
      final adminRes = await Supabase.instance.client
          .from('user_admin')
          .select('id')
          .eq('id', _userIdAdmin!)
          .single();
      _idAdmin = adminRes['id']?.toString();

      if (_idGuru != null && _idAdmin != null) {
        _chatStream = _dbPesan.getChatWithGuruStream(_idAdmin!, _idGuru!);
        ChatPrivateNotification.setSenderUnread(_idAdmin!, false);
      }
    } catch (e) {
      _errorMessage = 'Error fetching identities: $e';
      debugPrint(_errorMessage);
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
        final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? _userIdAdmin;
        final data = {
          'text': 'IMAGE_URL:$url',
          'pengirim_guru': _idGuru,
          'penerima_admin': _idAdmin,
          'user_id': currentUserId,
        };
        await _dbPesan.sendMessage(data);
        _fetchIdentities();
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
        final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? _userIdAdmin;
        final data = {
          'text': 'DOC_URL:$url',
          'pengirim_guru': _idGuru,
          'penerima_admin': _idAdmin,
          'user_id': currentUserId,
        };
        await _dbPesan.sendMessage(data);
        _fetchIdentities();
      } else {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal unggah dokumen')));
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

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    if (_idGuru == null || _idAdmin == null || _userIdAdmin == null) return;

    final text = _messageController.text.trim();
    _messageController.clear();

    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? _userIdAdmin;

    final data = {
      'text': text,
      'pengirim_guru': _idGuru,
      'penerima_admin': _idAdmin,
      'user_id': currentUserId,
    };

    try {
      await _dbPesan.sendMessage(data);
      
      // Reload pembacaan database setelah mengirim pesan
      if (mounted) {
        setState(() {
          _chatStream = _dbPesan.getChatWithGuruStream(_idAdmin!, _idGuru!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Chat Admin Sekolah'),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))))
              : Column(
              children: [
                Expanded(
                  child: _chatStream == null
                      ? const Center(child: Text('Gagal memuat ruang obrolan (stream null)'))
                      : StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _chatStream,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return Center(child: Text('Error: ${snapshot.error}'));
                            }
                            
                            final messages = snapshot.data ?? [];
                            
                            if (messages.isEmpty) {
                              return const Center(
                                child: Text(
                                  'Belum ada pesan.\nKirim pesan pertama Anda!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontFamily: 'Inter'),
                                ),
                              );
                            }

                            return ListView.builder(
                                  reverse: true,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final msg = messages[messages.length - 1 - index];
                                    final isMe = msg['pengirim_guru'] == _idGuru;

                                    return Align(
                                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
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
                                            if (msg['text']?.toString().startsWith('IMAGE_URL:') == true)
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
                                    );
                                  },
                                );
                          },
                        ),
                ),
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
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
      child: SafeArea(
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
    );
  }
}
