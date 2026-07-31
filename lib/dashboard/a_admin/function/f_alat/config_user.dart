import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apk/dashboard/a_admin/function/f_murid/get_murid.dart';

class ConfigUser extends StatefulWidget {
  final String? initialUid;
  const ConfigUser({super.key, this.initialUid});

  @override
  State<ConfigUser> createState() => _ConfigUserState();
}

class _ConfigUserState extends State<ConfigUser> {
  // Server URL terpisah — diset sendiri di halaman ini
  final _serverUrlController = TextEditingController();

  // Step 1 — Set Identitas (ARM)
  final _uidController = TextEditingController();

  // Step 3 — Detek / Absen
  final _thresholdController = TextEditingController(text: '0.38');
  
  bool _loadingArm = false;
  bool _loadingEnroll = false;
  bool _loadingDetect = false;

  String _statusArm = '-';
  String _statusEnroll = '-';
  String _statusDetect = '-';
  String _statusESP = '-';

  String _serverUrl = 'http://192.168.100.16:8000';

  /// Header wajib untuk melewati halaman peringatan ngrok.
  /// Aman juga dipakai ke server non-ngrok (header tak dikenal diabaikan).
  Map<String, String> get _headers => {
    'ngrok-skip-browser-warning': 'true',
    'Content-Type': 'application/x-www-form-urlencoded',
  };

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    if (widget.initialUid != null) {
      _uidController.text = widget.initialUid!;
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _uidController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // Hapus trailing slash agar tidak jadi double-slash saat digabung dengan path
    final raw = prefs.getString('face_server_url') ?? 'http://192.168.100.16:8000';
    _serverUrl = raw.replaceAll(RegExp(r'/+$'), '');
    if (mounted) {
      setState(() {
        _serverUrlController.text = _serverUrl;
      });
    }
  }

  Future<void> _saveServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    // Hapus trailing slash agar tidak jadi double-slash saat digabung dengan path
    _serverUrl = _serverUrlController.text.trim().replaceAll(RegExp(r'/+$'), '');
    _serverUrlController.text = _serverUrl;
    await prefs.setString('face_server_url', _serverUrl);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server URL disimpan: $_serverUrl'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
    }
  }
  Future<void> _arm() async {
    final input = _uidController.text.trim();
    if (input.isEmpty) {
      setState(() => _statusArm = 'UID / Nama tidak boleh kosong');
      return;
    }
    setState(() {
      _loadingArm = true;
      _statusArm = 'Mengirim...';
    });
    try {
      // /arm/enroll menerima query param ?name=... (bukan body)
      final uri = Uri.parse('$_serverUrl/arm/enroll')
          .replace(queryParameters: {'name': input});
      final resp = await http.post(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      final body = _tryPrettyJson(resp.body);
      setState(() => _statusArm = body);
    } catch (e) {
      setState(() => _statusArm = 'Error: $e');
    } finally {
      setState(() => _loadingArm = false);
    }
  }

  Future<void> _clearArm() async {
    _uidController.clear();
    setState(() => _statusArm = '-');
    try {
      // DELETE /arm/enroll untuk clear armed identity
      final uri = Uri.parse('$_serverUrl/arm/enroll');
      final req = http.Request('DELETE', uri);
      req.headers.addAll(_headers);
      final streamedResp = await req.send().timeout(const Duration(seconds: 5));
      await streamedResp.stream.drain();
    } catch (_) {}
  }

  Future<void> _enroll() async {
    setState(() {
      _loadingEnroll = true;
      _statusEnroll = 'Mengirim perintah Jepret & Daftar...';
    });
    try {
      // /job/capture_enroll — pakai armed identity yang sudah di-SET sebelumnya
      final resp = await http.post(
        Uri.parse('$_serverUrl/job/capture_enroll'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      final body = _tryPrettyJson(resp.body);
      setState(() => _statusEnroll = body);
      _fetchESPStatus();
    } catch (e) {
      setState(() => _statusEnroll = 'Error: $e');
    } finally {
      setState(() => _loadingEnroll = false);
    }
  }

  Future<void> _detect({bool quick = false}) async {
    setState(() {
      _loadingDetect = true;
      _statusDetect = 'Mendeteksi wajah...';
    });
    try {
      final threshold = _thresholdController.text.trim();
      
      // /job/recog menerima query param ?threshold=...&uid=...
      final params = <String, String>{};
      if (threshold.isNotEmpty) params['threshold'] = threshold;
            final uri = Uri.parse('$_serverUrl/job/recog')
          .replace(queryParameters: params.isNotEmpty ? params : null);

      final resp = await http.post(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
      final respBody = _tryPrettyJson(resp.body);
      setState(() => _statusDetect = respBody);
      _fetchESPStatus();
    } catch (e) {
      setState(() => _statusDetect = 'Error: $e');
    } finally {
      setState(() => _loadingDetect = false);
    }
  }

  Future<void> _fetchESPStatus() async {
    try {
      // /job/last — status pekerjaan terakhir yang dikerjakan ESP32
      final resp = await http.get(
        Uri.parse('$_serverUrl/job/last'),
        headers: _headers,
      ).timeout(const Duration(seconds: 8));
      setState(() => _statusESP = _tryPrettyJson(resp.body));
    } catch (e) {
      setState(() => _statusESP = 'Tidak dapat mengambil status: $e');
    }
  }

  String _tryPrettyJson(String raw) {
    try {
      final decoded = json.decode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Widget helpers
  // ──────────────────────────────────────────────────────────────────────────


  final _cleanupNameController = TextEditingController();
  final _cleanupUidController = TextEditingController();
  bool _loadingCleanup = false;
  String _statusCleanup = '-';

  Future<void> _deleteByName() async {
    final name = _cleanupNameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _loadingCleanup = true;
      _statusCleanup = 'Menghapus...';
    });
    try {
      final uri = Uri.parse('$_serverUrl/person/delete').replace(queryParameters: {'name': name});
      final req = http.Request('DELETE', uri)..headers.addAll(_headers);
      final resp = await req.send().timeout(const Duration(seconds: 10));
      final body = await resp.stream.bytesToString();
      setState(() => _statusCleanup = _tryPrettyJson(body));
    } catch (e) {
      setState(() => _statusCleanup = 'Error: $e');
    } finally {
      setState(() => _loadingCleanup = false);
    }
  }

  Future<void> _deleteByUid() async {
    final uid = _cleanupUidController.text.trim();
    if (uid.isEmpty) return;
    setState(() {
      _loadingCleanup = true;
      _statusCleanup = 'Menghapus...';
    });
    try {
      final uri = Uri.parse('$_serverUrl/person/delete').replace(queryParameters: {'uid': uid});
      final req = http.Request('DELETE', uri)..headers.addAll(_headers);
      final resp = await req.send().timeout(const Duration(seconds: 10));
      final body = await resp.stream.bytesToString();
      setState(() => _statusCleanup = _tryPrettyJson(body));
    } catch (e) {
      setState(() => _statusCleanup = 'Error: $e');
    } finally {
      setState(() => _loadingCleanup = false);
    }
  }

  Future<void> _cleanupUnused() async {
    setState(() {
      _loadingCleanup = true;
      _statusCleanup = 'Menghapus data kosong...';
    });
    try {
      final resp = await http.post(
        Uri.parse('$_serverUrl/cleanup/unused'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));
      setState(() => _statusCleanup = _tryPrettyJson(resp.body));
    } catch (e) {
      setState(() => _statusCleanup = 'Error: $e');
    } finally {
      setState(() => _loadingCleanup = false);
    }
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: Color(0xFF2563EB),
        ),
      );

  Widget _subLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: Color(0xFF64748B),
        ),
      );

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Color(0xFF1E293B),
          ),
        ),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFC4C4C4), fontFamily: 'Inter', fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      );

  Widget _actionBtn({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
    bool loading = false,
    double? width,
    Color? textColor,
    Color? borderColor,
  }) {
    final isOutlined = color == Colors.white || color == Colors.transparent;
    return SizedBox(
      width: width ?? double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor ?? (isOutlined ? const Color(0xFF64748B) : Colors.white),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: borderColor != null
                ? BorderSide(color: borderColor)
                : isOutlined
                    ? const BorderSide(color: Color(0xFFCBD5E1))
                    : BorderSide.none,
          ),
        ),
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: isOutlined ? const Color(0xFF64748B) : Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor ?? (isOutlined ? const Color(0xFF64748B) : Colors.white),
                ),
              ),
      ),
    );
  }

  Widget _statusBox(String text) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: SelectableText(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Color(0xFF475569),
          ),
        ),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Image.asset('lib/assets/icons/Button.png', width: 30, height: 30),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: -5,
        title: const Text("ESP32 FACE CONTROL"),
        titleTextStyle: const TextStyle(
          fontFamily: "Inter",
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Status',
            onPressed: _fetchESPStatus,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Server URL ──────────────────────────────────────────────────
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Server URL'),
                  const SizedBox(height: 4),
                  _subLabel('URL server Python / ngrok yang sedang berjalan'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _serverUrlController,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                    decoration: _inputDeco('https://xxxx.ngrok-free.app atau http://192.168.x.x:8000'),
                  ),
                  const SizedBox(height: 10),
                  _actionBtn(
                    label: 'SIMPAN URL',
                    color: Colors.white,
                    onPressed: _saveServerUrl,
                    borderColor: const Color(0xFF2563EB),
                    textColor: const Color(0xFF2563EB),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Step 1 + Step 2 + Step 3 ─────────────────────────────────
            // On narrow screen: vertical; on wide: row (handled with LayoutBuilder)
            LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _step1Card()),
                    const SizedBox(width: 12),
                    Expanded(child: _step2Card()),
                    const SizedBox(width: 12),
                    Expanded(child: _step3Card()),
                    const SizedBox(width: 12),
                    Expanded(child: _cleanupCard()),
                  ],
                );
              }
              return Column(
                children: [
                  _step1Card(),
                  const SizedBox(height: 14),
                  _step2Card(),
                  const SizedBox(height: 14),
                  _step3Card(),
                  const SizedBox(height: 14),
                  _cleanupCard(),
                ],
              );
            }),

            const SizedBox(height: 14),

            // ── Status ESP32 ─────────────────────────────────────────────
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionTitle('Status terakhir dari ESP32'),
                      TextButton.icon(
                        onPressed: _fetchESPStatus,
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text(
                          'Refresh',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _subLabel('ESP32 akan kirim hasil ke server setelah selesai.'),
                  const SizedBox(height: 10),
                  _statusBox(_statusESP),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Panel Step 1 ─────────────────────────────────────────────────────────
  Widget _step1Card() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Step 1 — Set Identitas (ARM)'),
            const SizedBox(height: 4),
            _subLabel(
              'Isi UID RFID (atau nama). Ini belum jepret.\nHanya "ngunci" identitas dulu.',
            ),
            const SizedBox(height: 14),
            _fieldLabel('UID / Name'),
            InkWell(
              onTap: () async {
                final selected = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MuridPage(isSelectionMode: true),
                  ),
                );
                if (selected != null && selected is Map<String, dynamic>) {
                  setState(() {
                    _uidController.text = selected['nama']?.toString() ?? '';
                  });
                }
              },
              child: IgnorePointer(
                child: TextField(
                  controller: _uidController,
                  readOnly: true,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                  decoration: _inputDeco('Pilih Murid dari Daftar...').copyWith(
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    label: 'SET',
                    color: const Color(0xFF2563EB),
                    onPressed: _arm,
                    loading: _loadingArm,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionBtn(
                    label: 'CLEAR',
                    color: Colors.white,
                    onPressed: _clearArm,
                    borderColor: const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _statusBox(_statusArm),
          ],
        ),
      );

  // ── Panel Step 2 ─────────────────────────────────────────────────────────
  Widget _step2Card() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Step 2 — Jepret & Daftar Wajah'),
            const SizedBox(height: 4),
            _subLabel(
              'Setelah UID/name di Step 1, pencet ini\nuntuk jepret dan enroll.',
            ),
            const SizedBox(height: 14),
            _actionBtn(
              label: 'JEPRET & DAFTAR',
              color: const Color(0xFF059669),
              onPressed: _enroll,
              loading: _loadingEnroll,
            ),
            const SizedBox(height: 10),
            _statusBox(_statusEnroll),
          ],
        ),
      );

  // ── Panel Step 3 ─────────────────────────────────────────────────────────

  // ── Panel Cleanup ────────────────────────────────────────────────────────
  Widget _cleanupCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Manajemen Data & Cleanup'),
            const SizedBox(height: 4),
            _subLabel('Hapus pengguna spesifik atau bersihkan baris data kosong tanpa wajah & kartu.'),
            const SizedBox(height: 14),
            
            _fieldLabel('Nama Pengguna'),
            TextField(
              controller: _cleanupNameController,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
              decoration: _inputDeco('Andi'),
            ),
            const SizedBox(height: 10),
            _actionBtn(
              label: 'HAPUS BY NAMA',
              color: const Color(0xFFDC2626),
              onPressed: _deleteByName,
              loading: _loadingCleanup,
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Color(0xFFE2E8F0)),
            ),
            
            _fieldLabel('UID RFID'),
            TextField(
              controller: _cleanupUidController,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
              decoration: _inputDeco('04 AB:12 CD'),
            ),
            const SizedBox(height: 10),
            _actionBtn(
              label: 'HAPUS BY RFID',
              color: const Color(0xFFDC2626),
              onPressed: _deleteByUid,
              loading: _loadingCleanup,
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Color(0xFFE2E8F0)),
            ),
            
            _actionBtn(
              label: 'BERSIHKAN DATA KOSONG',
              color: const Color(0xFFF59E0B),
              onPressed: _cleanupUnused,
              loading: _loadingCleanup,
            ),
            
            const SizedBox(height: 10),
            _statusBox(_statusCleanup),
          ],
        ),
      );

  Widget _step3Card() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Detek / Absen (Recognize)'),
            const SizedBox(height: 4),
            _subLabel(
              'Pencet untuk mulai deteksi.\nESP32 ambil foto dan kirim ke server.',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    label: 'DETEK SEKARANG',
                    color: const Color(0xFF7C3AED),
                    onPressed: () => _detect(quick: true),
                    loading: _loadingDetect,
                  ),
                ),
                const SizedBox(width: 8),
                _subLabel('1 klik,\npakai\nthreshold\ndefault'),
              ],
            ),
            const SizedBox(height: 14),
            _fieldLabel('Threshold'),
            TextField(
              controller: _thresholdController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
              decoration: _inputDeco('0.38'),
            ),
            const SizedBox(height: 10),
            _actionBtn(
              label: 'DETEK',
              color: const Color(0xFF2563EB),
              onPressed: _detect,
              loading: _loadingDetect,
            ),
            const SizedBox(height: 10),
            _statusBox(_statusDetect),
          ],
        ),
      );
}
