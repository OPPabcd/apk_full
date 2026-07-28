import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/database/auth.dart';
import 'package:apk/dashboard/a_admin/database/storage/image_profile.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apk/dashboard/a_admin/database/db_namasekolah.dart';

class UpdateProfilScreen extends StatefulWidget {
  const UpdateProfilScreen({super.key});

  @override
  State<UpdateProfilScreen> createState() => _UpdateProfilScreenState();
}

class _UpdateProfilScreenState extends State<UpdateProfilScreen> {
  final AuthService _authService = AuthService();
  final ImageProfileStorage _storageService = ImageProfileStorage();

  final nameController = TextEditingController();
  final nomorIndukController = TextEditingController();
  final emailController = TextEditingController();
  final roleController = TextEditingController();
  final namaSekolahController = TextEditingController();
  final wilayahController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
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

  Future<void> _updateProfile() async {
    setState(() => isSaving = true);

    try {
      await _authService.updateProfile(
        name: nameController.text,
        nomorInduk: nomorIndukController.text,
      );
      await NamaSekolahService.updateNamaSekolah(
        namaSekolahController.text,
        wilayahController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui')),
        );
        Navigator.pop(context, true); // return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => isLoading = true);

    try {
      final bytes = await pickedFile.readAsBytes();
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw 'User belum login';

      final newUrl = await _storageService.uploadProfileImage(userId, bytes);

      if (mounted) {
        setState(() => _avatarUrl = newUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil diperbarui')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengupload foto: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _deleteImage() async {
    setState(() => isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw 'User belum login';

      await _storageService.deleteProfileImage(userId);

      if (mounted) {
        setState(() => _avatarUrl = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil dihapus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus foto: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showEditProfileSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF2563EB)),
                title: const Text('Upload foto dari galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadImage();
                },
              ),
              if (_avatarUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Hapus foto profil', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _avatarEditor() {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: const Color(0xFF2563EB),
          backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
          onBackgroundImageError: _avatarUrl != null
              ? (exception, stackTrace) {
                  if (mounted) {
                    setState(() => _avatarUrl = null);
                  }
                }
              : null,
          child: _avatarUrl == null
              ? const Icon(Icons.person, size: 50, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: isSaving ? null : _showEditProfileSheet,
          icon: const Icon(Icons.edit, size: 16, color: Color(0xFF2563EB)),
          label: const Text(
            'Edit Foto',
            style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget field(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          style: const TextStyle(fontFamily: 'Inter'),
          decoration: InputDecoration(
            hintText: "Masukkan $label",
            hintStyle: const TextStyle(color: Color(0xFFC4C4C4), fontFamily: 'Inter'),
            filled: true,
            fillColor: readOnly ? const Color(0xFFE8EEF6) : const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
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
    final customAppBar = AppBar(
      backgroundColor: const Color(0xFF2563EB),
      elevation: 0,
      automaticallyImplyLeading: true,
      leading: IconButton(
        icon: Image.asset('lib/assets/icons/Button.png', width: 30, height: 30),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: -5,
      title: const Text("Edit Profil"),
      titleTextStyle: const TextStyle(
        fontFamily: "Inter",
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );

    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: customAppBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: customAppBar,
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _avatarEditor(),
                  const SizedBox(height: 24),
                  Row(
                    children: const [
                      Icon(Icons.person, color: Color(0xFF1E293B), size: 24),
                      SizedBox(width: 8),
                      Text(
                        "Akun",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        field("Email", emailController, readOnly: true),
                        field("Peran", roleController, readOnly: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: const [
                      Icon(Icons.person, color: Color(0xFF1E293B), size: 24),
                      SizedBox(width: 8),
                      Text(
                        "Profil",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        field("Nama Lengkap", nameController),
                        field(
                          "Nomor Induk",
                          nomorIndukController,
                          keyboardType: TextInputType.number,
                        ),
                        field("Nama Sekolah", namaSekolahController),
                        field("Wilayah", wilayahController),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _actionButton(
                  label: "Simpan",
                  color: const Color(0xFF2563EB),
                  onPressed: isSaving ? null : _updateProfile,
                  loading: isSaving,
                ),
                const SizedBox(width: 10),
                _actionButton(
                  label: "Batal",
                  color: Colors.white,
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
