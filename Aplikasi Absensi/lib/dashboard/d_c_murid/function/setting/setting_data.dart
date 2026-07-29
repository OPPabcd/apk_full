import 'package:flutter/material.dart';
import 'package:apk/dashboard/d_c_murid/database/db_murid.dart';
import 'package:apk/dashboard/d_c_murid/widget/custom_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apk/dashboard/d_c_murid/function/setting/edit_data.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/fcm_notif.dart';

class SettingDataOrtu extends StatefulWidget {
  const SettingDataOrtu({super.key});

  @override
  State<SettingDataOrtu> createState() => _SettingDataOrtuState();
}

class _SettingDataOrtuState extends State<SettingDataOrtu> {
  final service = DbMurid();

  bool isLoading = true;
  Map<String, dynamic>? data;
  List<Map<String, dynamic>> kelasList = [];

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
    loadKelas();
  }

  Future<void> loadKelas() async {
    final kData = await service.getKelas();
    if (mounted) {
      setState(() => kelasList = kData);
    }
  }

  Future<void> _fetchStudentData() async {
    setState(() {
      isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final nis = prefs.getString('murid_nis');
      final userId = prefs.getString('user_id_admin');

      if (nis != null && userId != null) {
        final response = await Supabase.instance.client
            .from('murid')
            .select()
            .eq('user_id', userId)
            .eq('nis', nis)
            .single();

        if (mounted) {
          setState(() {
            data = response;
            isLoading = false;
          });

          String namaVal = response['nama'] ?? "";
          if (namaVal.isEmpty) {
            for (var key in response.keys) {
              if (key.toLowerCase() == 'nama' || key.toLowerCase() == 'name') {
                namaVal = response[key].toString();
                break;
              }
            }
          }
          if (namaVal.isNotEmpty) {
            prefs.setString('murid_nama', namaVal);
          }
        }
      } else {
         if (mounted) {
           setState(() {
             isLoading = false;
           });
         }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error memuat data: $e')),
        );
      }
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal logout: $e')),
        );
      }
    }
  }

  Widget field(String label, String value) {
    return _infoCard(
      icon: _iconForLabel(label),
      title: label,
      value: _displayValue(label, value),
      isEmpty: value.isEmpty,
    );
  }

  IconData _iconForLabel(String label) {
    switch (label) {
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

  String get _nama {
    String namaVal = data?['nama'] ?? "";
    if (namaVal.isEmpty && data != null) {
      for (var key in data!.keys) {
        if (key.toLowerCase() == 'nama' || key.toLowerCase() == 'name') {
          namaVal = data![key].toString();
          break;
        }
      }
    }
    return namaVal.isEmpty ? "Belum diisi" : namaVal;
  }

  String get _nis => data?['nis']?.toString() ?? "Belum diisi";

  String get _kelas {
    final selectedKelas = data?['id_class'];
    if (selectedKelas != null && kelasList.isNotEmpty) {
      final kelas = kelasList.firstWhere(
        (k) => k['id_tabel'] == selectedKelas, 
        orElse: () => <String, dynamic>{},
      );
      return kelas['name_class']?.toString() ?? "Belum ada kelas";
    }
    return "Belum ada kelas";
  }

  String _displayValue(String label, String value) {
    if (value.isEmpty) return "Belum diisi";
    if (label != "Tanggal Lahir") return value;

    final date = DateTime.tryParse(value);
    if (date == null) return value;

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return "$day-$month-${date.year}";
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
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Color(0xFF8FA0BA),
      ),
      subtitleStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
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
            color: Colors.black.withValues(alpha: 0.04),
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
          fontSize: 12,
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
                color: Colors.black.withValues(alpha: 0.13),
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
                  fontSize: 12,
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
                    "NIS: $_nis",
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
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
                      _kelas,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
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
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          title: const Text("Pengaturan Profil", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600)),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (data == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          title: const Text("Pengaturan Profil", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600)),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          elevation: 0,
        ),
        body: const Center(child: Text("Data profil tidak ditemukan")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text("Pengaturan Profil", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600)),
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
            field("Gender", data?['gender'] ?? ""),
            field("Tanggal Lahir", data?['tanggal_lahir']?.toString() ?? ""),
            field("Alamat", data?['alamat'] ?? ""),
          ]),
          const SizedBox(height: 18),
          _sectionTitle("Kontak Orang Tua"),
          _sectionCard([
            field("Orang Tua", data?['orang_tua'] ?? ""),
            field("No Telepon", data?['no_tele']?.toString() ?? ""),
          ]),
          const SizedBox(height: 24),
          Row(
            children: [
              _actionButton(
                label: "Edit Profil",
                color: const Color(0xFF2563EB),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EditDataOrtu(data: data!)),
                  ).then((updated) {
                    if (updated != null && updated is Map<String, dynamic>) {
                      setState(() {
                        data = updated;
                      });
                    }
                  });
                },
              ),
              const SizedBox(width: 10),
              _actionButton(
                label: "Logout",
                color: Colors.red,
                onPressed: logout,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
