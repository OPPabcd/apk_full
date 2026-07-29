import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/database/db_siswa.dart';
import 'package:apk/dashboard/a_admin/widget/custom_button.dart';
import 'package:apk/dashboard/a_admin/function/f_murid/update_murid.dart';
import 'package:apk/dashboard/a_admin/function/f_alat/config_user.dart';

class DetailMuridPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const DetailMuridPage({
    super.key,
    required this.data,
  });

  @override
  State<DetailMuridPage> createState() => _DetailMuridPageState();
}

class _DetailMuridPageState extends State<DetailMuridPage> {
  final service = MuridService();
  late Map<String, dynamic> currentData;

  bool _isLoadingStatus = true;
  bool _hasFace = false;
  bool _hasRFID = false;
  String _rfidUid = '';
  String _serverUrl = 'http://192.168.100.16:8000';

  @override
  void initState() {
    super.initState();
    currentData = Map.from(widget.data);
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverUrl = (prefs.getString('face_server_url') ?? 'http://192.168.100.16:8000').replaceAll(RegExp(r'/+$'), '');
      
      final res = await http.get(Uri.parse('$_serverUrl/api/persons')).timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final items = data['items'] as List;
        final nameToFind = currentData['nama']?.toString() ?? "";
        final match = items.where((e) => e['person'] == nameToFind).toList();
        if (match.isNotEmpty) {
          _hasFace = match.first['has_face'] == true;
          _rfidUid = match.first['rfid_uid']?.toString() ?? '';
          _hasRFID = _rfidUid.isNotEmpty;
        }
      }
    } catch (e) {
      debugPrint('Error fetch status alat: $e');
    }
    if (mounted) {
      setState(() {
        _isLoadingStatus = false;
      });
    }
  }

  Future<void> deleteData() async {
    try {
      await service.deleteMurid(currentData['id_tabel']);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  String get _nama => currentData['nama']?.toString().isEmpty ?? true ? "Belum diisi" : currentData['nama'];
  String get _nis => currentData['nis']?.toString().isEmpty ?? true ? "Belum diisi" : currentData['nis'].toString();
  String get _kelas {
    final kelas = currentData['class_name']?['name_class']?.toString() ?? "";
    return kelas.isEmpty ? "Belum ada kelas" : kelas;
  }

  String _displayValue(String label, String? value) {
    if (value == null || value.isEmpty) return "Belum diisi";
    if (label != "Tanggal Lahir") return value;

    final date = DateTime.tryParse(value);
    if (date == null) return value;

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return "$day-$month-${date.year}";
  }

  IconData _iconForLabel(String label) {
    switch (label) {
      case "Wajah":
        return Icons.face;
      case "RFID":
        return Icons.credit_card;
      case "NIS":
        return Icons.badge_outlined;
      case "Nama":
        return Icons.person_outline;
      case "Gender":
        return Icons.person_pin_outlined;
      case "Tanggal Lahir":
        return Icons.calendar_month_outlined;
      case "Alamat":
        return Icons.location_on_outlined;
      case "Orang Tua":
        return Icons.groups_2_outlined;
      case "No Telepon":
        return Icons.phone_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
    bool isEmpty = false,
  }) {
    return CustomCard(
      title: title,
      subtitle: value,
      icon: icon,
      iconPosition: IconPosition.left,
      iconColor: const Color(0xFF2563EB),
      iconSize: 24,
      iconContainerSize: 46,
      iconDecoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(9),
      ),
      backgroundColor: Colors.white,
      borderColor: Colors.transparent,
      borderWidth: 0,
      borderRadius: 0,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      boxShadow: const [],
      titleStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF8FA0BA),
      ),
      subtitleStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
        color: isEmpty ? const Color(0xFFC8D2E0) : const Color(0xFF172033),
      ),
      showIcon: true,
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EEF6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF0F4FA),
                  indent: 82,
                  endIndent: 20,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _profileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _nama,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 18,
                    color: Color(0xFF8FA0BA),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "NIS: $_nis",
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.school_outlined,
                      size: 18,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _kelas,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
  Widget build(BuildContext context) {
    final gender = currentData['gender']?.toString() ?? "";
    final tglLahir = currentData['tanggal_lahir']?.toString() ?? "";
    final alamat = currentData['alamat']?.toString() ?? "";
    final ortu = currentData['orang_tua']?.toString() ?? "";
    final tele = currentData['no_tele']?.toString() ?? "";

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
        title: const Text("Detail Murid"),
        titleTextStyle: const TextStyle(
          fontFamily: "Inter",
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        children: [
          _profileHeader(),
          const SizedBox(height: 20),
          _sectionTitle("Identitas"),
          _sectionCard([
            _infoCard(
              icon: _iconForLabel("Gender"),
              title: "Gender",
              value: _displayValue("Gender", gender),
              isEmpty: gender.isEmpty,
            ),
            _infoCard(
              icon: _iconForLabel("Tanggal Lahir"),
              title: "Tanggal Lahir",
              value: _displayValue("Tanggal Lahir", tglLahir),
              isEmpty: tglLahir.isEmpty,
            ),
            _infoCard(
              icon: _iconForLabel("Alamat"),
              title: "Alamat",
              value: _displayValue("Alamat", alamat),
              isEmpty: alamat.isEmpty,
            ),
          ]),
          const SizedBox(height: 18),
          _sectionTitle("Status Registrasi Alat"),
          _sectionCard([
            _infoCard(
              icon: _iconForLabel("Wajah"),
              title: "Wajah",
              value: _isLoadingStatus ? "Loading..." : (_hasFace ? "Terdaftar" : "Belum Terdaftar"),
              isEmpty: !_hasFace && !_isLoadingStatus,
            ),
            _infoCard(
              icon: _iconForLabel("RFID"),
              title: "RFID",
              value: _isLoadingStatus ? "Loading..." : (_hasRFID ? _rfidUid : "Belum Terdaftar"),
              isEmpty: !_hasRFID && !_isLoadingStatus,
            ),
          ]),
          const SizedBox(height: 18),
          _sectionTitle("Kontak Orang Tua"),
          _sectionCard([
            _infoCard(
              icon: _iconForLabel("Orang Tua"),
              title: "Orang Tua",
              value: _displayValue("Orang Tua", ortu),
              isEmpty: ortu.isEmpty,
            ),
            _infoCard(
              icon: _iconForLabel("No Telepon"),
              title: "No Telepon",
              value: _displayValue("No Telepon", tele),
              isEmpty: tele.isEmpty,
            ),
          ]),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ConfigUser(initialUid: currentData['nama']?.toString()),
                ),
              );
            },
            icon: const Icon(Icons.face_retouching_natural, color: Colors.white, size: 20),
            label: const Text(
              "Hubungkan ke Alat (Set Identitas)",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981), // Emerald green
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _actionButton(
                label: "Edit",
                color: const Color(0xFF2563EB),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UpdateMuridPage(data: currentData),
                    ),
                  );
                  if (result != null && mounted) {
                    setState(() {
                      currentData = result;
                    });
                  }
                },
              ),
              const SizedBox(width: 10),
              _actionButton(
                label: "Delete",
                color: Colors.red,
                onPressed: deleteData,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
