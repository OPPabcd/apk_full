import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:apk/dashboard/d_c_murid/database/storage/image_doc.dart';
import 'package:apk/dashboard/d_c_murid/function/f_Pesan/doc_image.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/chat_private_n.dart';

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
  final supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentMuridId;
  String? _userIdAdmin;
  
  Stream<List<Map<String, dynamic>>>? _chatStream;

  @override
  void initState() {
    super.initState();
    _initChat();
    ChatPrivateNotification.setSenderUnread(widget.receiverId, false);
  }

  Future<void> _initChat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nis = prefs.getString('murid_nis');
      _userIdAdmin = prefs.getString('user_id_admin');

      if (nis == null || _userIdAdmin == null) {
        throw Exception('Data login tidak lengkap (NIS atau User ID kosong)');
      }

      // Dapatkan id_murid (id_tabel)
      final muridRes = await supabase
          .from('murid')
          .select('id_tabel')
          .eq('user_id', _userIdAdmin!)
          .eq('nis', nis)
          .single();
      _currentMuridId = muridRes['id_tabel']?.toString();

      if (_currentMuridId != null) {
        if (widget.receiverType == 'guru') {
          _chatStream = supabase
            .from('chat_private')
            .stream(primaryKey: ['id_tabel'])
            .order('created_at', ascending: true)
            .map((data) => data
                .where((e) => 
                    (e['pengirim_murid']?.toString() == _currentMuridId && e['penerima_guru']?.toString() == widget.receiverId) ||
                    (e['pengirim_guru']?.toString() == widget.receiverId && e['penerima_murid']?.toString() == _currentMuridId))
                .map((e) => e as Map<String, dynamic>)
                .toList());
        } else if (widget.receiverType == 'murid') {
          _chatStream = supabase
            .from('chat_private')
            .stream(primaryKey: ['id_tabel'])
            .order('created_at', ascending: true)
            .map((data) => data
                .where((e) => 
                    (e['pengirim_murid']?.toString() == _currentMuridId && e['penerima_murid']?.toString() == widget.receiverId) ||
                    (e['pengirim_murid']?.toString() == widget.receiverId && e['penerima_murid']?.toString() == _currentMuridId))
                .map((e) => e as Map<String, dynamic>)
                .toList());
        }
      } else {
        _errorMessage = 'Gagal memuat profil Murid.';
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
        final userId = supabase.auth.currentUser?.id ?? _userIdAdmin;
        if (widget.receiverType == 'guru') {
          await supabase.from('chat_private').insert({
            'text': 'IMAGE_URL:$url',
            'pengirim_murid': _currentMuridId,
            'penerima_guru': widget.receiverId,
            'user_id': userId,
          });
        } else if (widget.receiverType == 'murid') {
          await supabase.from('chat_private').insert({
            'text': 'IMAGE_URL:$url',
            'pengirim_murid': _currentMuridId,
            'penerima_murid': widget.receiverId,
            'user_id': userId,
          });
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
        final userId = supabase.auth.currentUser?.id ?? _userIdAdmin;
        if (widget.receiverType == 'guru') {
          await supabase.from('chat_private').insert({
            'text': 'DOC_URL:$url',
            'pengirim_murid': _currentMuridId,
            'penerima_guru': widget.receiverId,
            'user_id': userId,
          });
        } else if (widget.receiverType == 'murid') {
          await supabase.from('chat_private').insert({
            'text': 'DOC_URL:$url',
            'pengirim_murid': _currentMuridId,
            'penerima_murid': widget.receiverId,
            'user_id': userId,
          });
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
    if (text.isEmpty || _currentMuridId == null) return;

    _messageController.clear();

    try {
      final userId = supabase.auth.currentUser?.id ?? _userIdAdmin;

      if (widget.receiverType == 'guru') {
        await supabase.from('chat_private').insert({
          'text': text,
          'pengirim_murid': _currentMuridId,
          'penerima_guru': widget.receiverId,
          'user_id': userId,
        });
      } else if (widget.receiverType == 'murid') {
        await supabase.from('chat_private').insert({
          'text': text,
          'pengirim_murid': _currentMuridId,
          'penerima_murid': widget.receiverId,
          'user_id': userId,
        });
      }
      
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat: ${widget.receiverName}'),
        backgroundColor: const Color(0xFF2563EB),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
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
                                  return const Center(child: Text('Belum ada pesan'));
                                }

                                return ListView.builder(
                                  reverse: true,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final msg = messages[messages.length - 1 - index];
                                    final isMe = msg['pengirim_murid']?.toString() == _currentMuridId;
                                    final textMsg = msg['text']?.toString() ?? '';
                                    if (textMsg.startsWith("📋 *Pengajuan Izin*")) {
                                      return _buildIzinCard(textMsg, widget.receiverName, _formatTime(msg['created_at']), isMe);
                                    }

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

  Widget _buildIzinCard(String text, String senderName, String time, bool isMe) {
    final lines = text.split('\n');
    String nama = '';
    String tanggal = '';
    String keterangan = '';
    List<String> lampiranUrls = [];
    String idIzin = '';
    String jenis = '';
    
    for (var rawLine in lines) {
      final line = rawLine.trim();
      if (line.startsWith('Nama: ')) nama = line.substring(6).trim();
      else if (line.startsWith('Tanggal: ')) tanggal = line.substring(9).trim();
      else if (line.startsWith('Keterangan: ')) keterangan = line.substring(12).trim();
      else if (line.startsWith('Lampiran: ')) {
        final urlsString = line.substring(10).trim();
        if (urlsString.isNotEmpty) {
          lampiranUrls = urlsString.split(RegExp(r'\s+')).where((s) => s.startsWith('http')).toList();
        }
      }
      else if (line.startsWith('ID_IZIN: ')) idIzin = line.substring(8).trim();
      else if (line.startsWith('Jenis: ')) jenis = line.substring(7).trim();
      else if (keterangan.isNotEmpty && lampiranUrls.isEmpty && !line.startsWith('📋') && !line.startsWith('ID_IZIN:') && !line.startsWith('Jenis:')) {
        keterangan += '\n$line';
      }
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Card(
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
                    Icon(
                      jenis.toLowerCase() == 'sakit' ? Icons.sick : Icons.assignment_ind,
                      color: jenis.toLowerCase() == 'sakit' ? Colors.red : Colors.amber,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        jenis.isNotEmpty ? 'Pengajuan $jenis' : 'Pengajuan Izin',
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
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      nama,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.date_range, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      tanggal,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
                if (keterangan.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Keterangan:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(keterangan, style: const TextStyle(fontSize: 14)),
                ],
                if (lampiranUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: lampiranUrls.map((urlStr) {
                      final uri = Uri.tryParse(urlStr);
                      String extension = 'file';
                      String cleanName = 'Lampiran';
                      if (uri != null && uri.pathSegments.isNotEmpty) {
                        final fullName = Uri.decodeComponent(uri.pathSegments.last);
                        cleanName = fullName.replaceFirst(RegExp(r'^\d{13}_(?:camera_)?'), '');
                        final extIdx = fullName.lastIndexOf('.');
                        if (extIdx != -1 && extIdx < fullName.length - 1) {
                          extension = fullName.substring(extIdx + 1).toLowerCase();
                        }
                      }
                      final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
                      final extLabel = extension.length > 4
                          ? extension.substring(0, 4).toUpperCase()
                          : extension.toUpperCase();

                      if (isImage) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => DocImagePreviewPage(imageUrl: urlStr),
                            ));
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              urlStr,
                              width: 110,
                              height: 110,
                              fit: BoxFit.cover,
                              loadingBuilder: (ctx, child, progress) =>
                                  progress == null ? child : const SizedBox(width: 110, height: 110, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                              errorBuilder: (ctx, _, __) => const SizedBox(width: 110, height: 110, child: Icon(Icons.broken_image)),
                            ),
                          ),
                        );
                      } else {
                        return GestureDetector(
                          onTap: () async {
                            if (uri != null) {
                              try {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Tidak dapat membuka lampiran')),
                                  );
                                }
                              }
                            }
                          },
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 220),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
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
                                      extLabel,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cleanName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$extLabel • Dokumen',
                                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    }).toList(),
                  ),
                ],
                if (idIzin.isNotEmpty) ...[
                  const Divider(),
                  IzinStatusWidget(idIzin: idIzin, isTeacher: false, textPesan: text),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    time,
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class IzinStatusWidget extends StatefulWidget {
  final String idIzin;
  final bool isTeacher;
  final String? textPesan;
  const IzinStatusWidget({super.key, required this.idIzin, required this.isTeacher, this.textPesan});

  @override
  State<IzinStatusWidget> createState() => _IzinStatusWidgetState();
}

class _IzinStatusWidgetState extends State<IzinStatusWidget> {
  bool? _verifStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    if (widget.idIzin.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('leave_request')
          .select('verif')
          .eq('id_tabel', widget.idIzin)
          .maybeSingle();
      if (res != null && mounted) {
        setState(() {
          _verifStatus = res['verif'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(bool status) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('leave_request')
          .update({'verif': status})
          .eq('id_tabel', widget.idIzin);
          
      if (mounted) {
        setState(() {
          _verifStatus = status;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status ? 'Pengajuan izin disetujui!' : 'Pengajuan izin ditolak!'),
            backgroundColor: status ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_verifStatus == true) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Color(0xFF059669), size: 16),
            SizedBox(width: 6),
            Text(
              'Disetujui',
              style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Inter'),
            ),
          ],
        ),
      );
    }

    if (_verifStatus == false) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel, color: Color(0xFFDC2626), size: 16),
            SizedBox(width: 6),
            Text(
              'Ditolak',
              style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Inter'),
            ),
          ],
        ),
      );
    }

    // Status: Pending (null)
    if (widget.isTeacher) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _updateStatus(true),
              icon: const Icon(Icons.check, size: 16, color: Colors.white),
              label: const Text('Setujui', style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _updateStatus(false),
              icon: const Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
              label: const Text('Tolak', style: TextStyle(color: Color(0xFFDC2626), fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDC2626)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty, color: Color(0xFFD97706), size: 16),
          SizedBox(width: 6),
          Text(
            'Menunggu Persetujuan',
            style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Inter'),
          ),
        ],
      ),
    );
  }
}
