import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/widget/custom_button.dart';
import 'package:apk/dashboard/d_guru/function/setting_p/update_data.dart';

class SettingProfilPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const SettingProfilPage({
    super.key,
    required this.data,
  });

  @override
  State<SettingProfilPage> createState() => _SettingProfilPageState();
}

class _SettingProfilPageState extends State<SettingProfilPage> {

  bool get _isWali => widget.data['wali'] == true;
  String get _nama => widget.data['name']?.toString().isEmpty ?? true ? "Belum diisi" : widget.data['name'].toString();
  String get _nik => widget.data['nik']?.toString().isEmpty ?? true ? "Belum diisi" : widget.data['nik'].toString();
  String get _bidang => widget.data['bidang']?.toString().isEmpty ?? true ? "Belum diisi" : widget.data['bidang'].toString();

  String get _kelasStr {
    final classNameObj = widget.data['class_name'];
    String kelas = "";
    if (classNameObj != null) {
      if (classNameObj is String) {
        kelas = classNameObj;
      } else if (classNameObj is List && classNameObj.isNotEmpty) {
        kelas = classNameObj[0]['name_class']?.toString() ?? "";
      } else if (classNameObj is Map) {
        kelas = classNameObj['name_class']?.toString() ?? "";
      }
    }
    return kelas;
  }

  String get _badge {
    String kelas = _kelasStr;
    if (_isWali) {
      return kelas.isEmpty ? "Wali Kelas" : kelas;
    }
    return _bidang == "Belum diisi" ? "Guru" : _bidang;
  }

  Widget waliField() {
    return _infoCard(
      icon: Icons.verified_user_outlined,
      title: "Wali Kelas",
      value: _isWali ? "Ya" : "Tidak",
    );
  }

  Widget kelasField() {
    String kelas = _kelasStr;
    return _infoCard(
      icon: Icons.school_outlined,
      title: "Kelas",
      value: kelas.isEmpty ? "Belum diisi" : kelas,
      isEmpty: kelas.isEmpty,
    );
  }

  Widget bidangField() {
    return _infoCard(
      icon: Icons.menu_book_outlined,
      title: "Bidang",
      value: _bidang,
      isEmpty: _bidang == "Belum diisi",
    );
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
    return SizedBox(
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomCard(
            title: "",
            showIcon: false,
            height: 126,
            backgroundColor: Colors.white,
            borderColor: const Color(0xFFE8EEF6),
            borderWidth: 1,
            borderRadius: 18,
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.13),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _nama,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),
              const SizedBox(height: 10),
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
                    "NIK: $_nik",
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                      _badge,
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
  }) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text("Setting Profil", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        children: [
          _profileHeader(),
          const SizedBox(height: 20),
          _sectionTitle("Identitas"),
          _sectionCard([
            bidangField(),
            waliField(),
            if (_isWali || _kelasStr.isNotEmpty) kelasField(),
          ]),
          const SizedBox(height: 24),
          Row(
            children: [
              _actionButton(
                label: "Edit Profil",
                color: const Color(0xFF2563EB),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UpdateProfilPage(data: widget.data),
                    ),
                  );
                  if (result == true) {
                    setState(() {});
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
