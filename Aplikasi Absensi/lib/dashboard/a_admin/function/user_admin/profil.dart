import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/database/auth.dart';
import 'package:apk/dashboard/a_admin/database/storage/image_profile.dart';
import 'package:apk/dashboard/a_admin/widget/custom_button.dart';
import 'package:apk/register/page1.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apk/dashboard/a_admin/database/db_namasekolah.dart';
import 'package:apk/dashboard/a_admin/function/user_admin/update_profil.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  final AuthService _authService = AuthService();
  final ImageProfileStorage _storageService = ImageProfileStorage();

  final nameController = TextEditingController();
  final nomorIndukController = TextEditingController();
  final emailController = TextEditingController();
  final roleController = TextEditingController();
  final namaSekolahController = TextEditingController();
  final wilayahController = TextEditingController();

  bool isLoading = true;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await _authService.getProfile();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    String? loadedAvatarUrl;

    if (userId != null) {
      loadedAvatarUrl = await _storageService.getProfileImageUrl(userId);
    }
    
    final schoolData = await NamaSekolahService.getSchoolDetails();
    final schoolName = schoolData?['sekolah'] ?? '';
    final schoolWilayah = schoolData?['wilayah'] ?? '';

    if (mounted) {
      setState(() {
        if (data != null) {
          nameController.text = data['name'] ?? '';
          nomorIndukController.text = data['nomor_induk'] ?? '';
          emailController.text = data['email'] ?? '';
          roleController.text = data['role'] ?? '';
          namaSekolahController.text = schoolName;
          wilayahController.text = schoolWilayah;
        }

        _avatarUrl = loadedAvatarUrl;
        isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Home()),
        (route) => false,
      );
    }
  }

  IconData _iconForLabel(String label) {
    switch (label) {
      case "Email":
        return Icons.email_outlined;
      case "Peran":
        return Icons.verified_user_outlined;
      case "Nama Lengkap":
        return Icons.person_outline;
      case "Nomor Induk":
        return Icons.badge_outlined;
      case "Nama Sekolah":
        return Icons.account_balance_outlined;
      case "Wilayah":
        return Icons.location_on_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _displayValue(String value) {
    return value.isEmpty ? "Belum diisi" : value;
  }

  String get _nama =>
      nameController.text.isEmpty ? "Belum diisi" : nameController.text;
  String get _nomorInduk => nomorIndukController.text.isEmpty
      ? "Belum diisi"
      : nomorIndukController.text;
  String get _role =>
      roleController.text.isEmpty ? "Admin" : roleController.text;

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

  Widget field(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return _infoCard(
      icon: _iconForLabel(label),
      title: label,
      value: _displayValue(controller.text),
      isEmpty: controller.text.isEmpty,
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
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF2563EB),
            backgroundImage:
                _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
            onBackgroundImageError: _avatarUrl != null
                ? (exception, stackTrace) {
                    if (mounted) {
                      setState(() => _avatarUrl = null);
                    }
                  }
                : null,
            child: _avatarUrl == null
                ? const Icon(Icons.person, size: 36, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 16),
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
                    "No. Induk: $_nomorInduk",
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
                      Icons.admin_panel_settings_outlined,
                      size: 18,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _role,
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



  @override
  void dispose() {
    nameController.dispose();
    nomorIndukController.dispose();
    emailController.dispose();
    roleController.dispose();
    namaSekolahController.dispose();
    wilayahController.dispose();
    super.dispose();
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
      title: const Text("Profil Admin"),
      titleTextStyle: const TextStyle(
        fontFamily: "Inter",
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );

    if (isLoading) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: appBar,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        children: [
          _profileHeader(),
          const SizedBox(height: 20),
          _sectionTitle("Akun"),
          _sectionCard([
            field("Email", emailController),
            field("Peran", roleController),
          ]),
          const SizedBox(height: 18),
          _sectionTitle("Identitas"),
          _sectionCard([
            field("Nama Lengkap", nameController),
            field("Nomor Induk", nomorIndukController),
            field("Nama Sekolah", namaSekolahController),
            field("Wilayah", wilayahController),
          ]),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const UpdateProfilScreen()),
                    );
                    if (result == true) {
                      setState(() => isLoading = true);
                      _loadProfile();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    "Edit",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    "Logout",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
