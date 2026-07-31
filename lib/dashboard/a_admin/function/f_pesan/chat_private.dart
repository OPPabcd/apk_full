import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apk/dashboard/a_admin/database/db_pesan_private.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:apk/dashboard/a_admin/database/storage/image_doc.dart';
import 'package:apk/dashboard/a_admin/function/f_pesan/doc_image_page.dart';
import 'package:apk/dashboard/a_admin/function/f_notif/notif_reddot.dart';

class ChatPrivate extends StatefulWidget {
  final String receiverId;
  final String receiverType; // 'guru' or 'murid'
  final String receiverName;

  const ChatPrivate({
    super.key,
    required this.receiverId,
    required this.receiverType,
    required this.receiverName,
  });

  @override
  State<ChatPrivate> createState() => _ChatPrivateState();
}

class _ChatPrivateState extends State<ChatPrivate> {
  final TextEditingController _messageController = TextEditingController();
  final DbPesanPrivate _dbPesan = DbPesanPrivate();
  
  bool _isLoading = true;
  String? _errorMessage;
  String? _idAdmin;
  String? _currentUserId;
  
  Stream<List<Map<String, dynamic>>>? _chatStream;

  @override
  void initState() {
    super.initState();
    _initChat();
    NotifRedDot.setChatPrivateSenderUnread(widget.receiverId, false);
  }

  Future<void> _initChat() async {
    try {
      _currentUserId = DbPesanPrivate.userId;
      _idAdmin = await _dbPesan.getAdminId();

      if (_idAdmin != null) {
        if (widget.receiverType == 'guru') {
          _chatStream = _dbPesan.getChatWithGuruStream(_idAdmin!, widget.receiverId);
        } else if (widget.receiverType == 'murid') {
          _chatStream = _dbPesan.getChatWithMuridStream(_idAdmin!, widget.receiverId);
        }
      } else {
        _errorMessage = 'Gagal memuat profil Admin. Pastikan Anda login sebagai Admin.';
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
        if (widget.receiverType == 'guru') {
          await _dbPesan.sendMessageToGuru(text: 'IMAGE_URL:$url', idAdmin: _idAdmin!, idGuru: widget.receiverId);
        } else if (widget.receiverType == 'murid') {
          await _dbPesan.sendMessageToMurid(text: 'IMAGE_URL:$url', idAdmin: _idAdmin!, idMurid: widget.receiverId);
        }
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
        if (widget.receiverType == 'guru') {
          await _dbPesan.sendMessageToGuru(text: 'DOC_URL:$url', idAdmin: _idAdmin!, idGuru: widget.receiverId);
        } else if (widget.receiverType == 'murid') {
          await _dbPesan.sendMessageToMurid(text: 'DOC_URL:$url', idAdmin: _idAdmin!, idMurid: widget.receiverId);
        }
        await _initChat();
      } else {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal unggah dokumen')));
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _idAdmin == null) return;

    _messageController.clear();

    try {
      if (widget.receiverType == 'guru') {
        await _dbPesan.sendMessageToGuru(
          text: text,
          idAdmin: _idAdmin!,
          idGuru: widget.receiverId,
        );
      } else if (widget.receiverType == 'murid') {
        await _dbPesan.sendMessageToMurid(
          text: text,
          idAdmin: _idAdmin!,
          idMurid: widget.receiverId,
        );
      }
      
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
      title: Text('Chat: ${widget.receiverName}'),
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
      appBar: appBar,
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            )
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
                                  return const Center(child: Text('Belum ada pesan'));
                                }

                                return ListView.builder(
                                  reverse: true,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final msg = messages[messages.length - 1 - index];
                                    final isMe = msg['pengirim_admin'] == _idAdmin;

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
