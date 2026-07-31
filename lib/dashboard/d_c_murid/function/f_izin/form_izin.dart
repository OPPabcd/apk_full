import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:apk/dashboard/d_c_murid/database/db_izin.dart';
import 'package:apk/dashboard/d_c_murid/bottom_bar/nav_screen_o.dart';

class FormIzin extends StatefulWidget {
  const FormIzin({super.key});

  @override
  State<FormIzin> createState() => _FormIzinState();
}

class _FormIzinState extends State<FormIzin> {
  final TextEditingController _keteranganController = TextEditingController();
  
  DateTime? _startDate;
  DateTime? _endDate;
  final List<PlatformFile> _selectedFiles = [];
  String _ketOpsi = 'izin'; // 'izin' or 'sakit'

  bool _isLoadingData = true;
  bool _isSubmitting = false;

  String? _userIdAdmin;
  String? _studentNis;
  String? _idMurid;
  String? _idGuru;
  String? _idClass;
  String _studentName = '';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _studentNis = prefs.getString('murid_nis');
      _userIdAdmin = prefs.getString('user_id_admin');

      if (_studentNis != null && _userIdAdmin != null) {
        final response = await Supabase.instance.client
            .from('murid')
            .select()
            .eq('user_id', _userIdAdmin!)
            .eq('nis', _studentNis!)
            .single();

        String? nameValue;
        for (var key in response.keys) {
          if (key.toLowerCase().contains('nama') || key.toLowerCase().contains('name')) {
            nameValue = response[key].toString();
            break;
          }
        }
        final resolvedStudentName = nameValue ?? 'Tanpa Nama';
        final resolvedIdMurid = response['id_tabel']?.toString();
        final resolvedIdClass = response['id_class']?.toString();
        
        String? resolvedIdGuru;
        
        debugPrint("DIAGNOSTICS: Murid Row fetched from Supabase: $response");

        if (resolvedIdClass != null) {
          try {
            final classRes = await Supabase.instance.client
                .from('class_name')
                .select('id_guru')
                .eq('id_tabel', resolvedIdClass)
                .maybeSingle();
            debugPrint("DIAGNOSTICS: class_name search result for class ID $resolvedIdClass: $classRes");
            if (classRes != null && classRes['id_guru'] != null) {
              resolvedIdGuru = classRes['id_guru']?.toString();
            }
          } catch (err) {
            debugPrint("Error looking up Wali Kelas from class_name: $err");
          }
        }
        
        if (resolvedIdGuru == null && resolvedIdClass != null) {
          try {
            final guruRes = await Supabase.instance.client
                .from('guru')
                .select('id_tabel')
                .eq('id_class', resolvedIdClass)
                .eq('wali', true)
                .maybeSingle();
            debugPrint("DIAGNOSTICS: guru search result for class ID $resolvedIdClass: $guruRes");
            if (guruRes != null) {
              resolvedIdGuru = guruRes['id_tabel']?.toString();
            }
          } catch (err) {
            debugPrint("Error looking up Wali Kelas from guru table: $err");
          }
        }

        if (resolvedIdGuru == null) {
          debugPrint("DIAGNOSTICS WARNING: Wali kelas is still null. Murid ID: $resolvedIdMurid, Class ID: $resolvedIdClass");
        }

        setState(() {
          _studentName = resolvedStudentName;
          _idMurid = resolvedIdMurid;
          _idGuru = resolvedIdGuru;
          _idClass = resolvedIdClass;
          _isLoadingData = false;
        });
      } else {
        setState(() {
          _studentName = 'Belum login (NIS tidak ditemukan)';
          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint("DIAGNOSTICS ERROR: _fetchUserData failed with: $e");
      setState(() {
        _studentName = 'Error memuat data profil: $e';
        _isLoadingData = false;
      });
    }
  }

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB), 
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      debugPrint("Error picking files: $e");
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _selectedFiles.add(PlatformFile(
            name: photo.name,
            size: bytes.length,
            bytes: bytes,
            path: photo.path,
          ));
        });
      }
    } catch (e) {
      debugPrint("Error capturing from camera: $e");
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Tambah Lampiran',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF2563EB)),
                title: const Text('Ambil Foto (Kamera)', style: TextStyle(fontFamily: 'Inter')),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined, color: Color(0xFF2563EB)),
                title: const Text('Pilih Dokumen / Galeri', style: TextStyle(fontFamily: 'Inter')),
                onTap: () {
                  Navigator.pop(context);
                  _pickFiles();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitData() async {
    if (_idMurid == null || _userIdAdmin == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal: Data profil tidak lengkap! Coba muat ulang aplikasi.')));
      return;
    }

    if (_startDate == null || _endDate == null || _keteranganController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap lengkapi isi tanggal dan keterangan izin')));
      return;
    }

    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap unggah minimal 1 foto/dokumen surat izin')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final dbIzin = DbIzin();
      final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? _userIdAdmin!;
      final List<String> lampiranUrls = [];

      for (var file in _selectedFiles) {
        if (file.bytes == null) {
          throw Exception("Gagal membaca data file: ${file.name}");
        }
        final url = await dbIzin.uploadIzinFile(currentUserId, _studentNis!, file.bytes!, file.name);
        lampiranUrls.add(url);
      }

      final lampiranString = lampiranUrls.join(' ');

      // Insert to Table leave_request
      final data = {
        'tanggal_mulai': DateFormat('yyyy-MM-dd').format(_startDate!),
        'tanggal_selesai': DateFormat('yyyy-MM-dd').format(_endDate!),
        'keterangan': _keteranganController.text,
        'verif': null, 
        'id_murid': _idMurid,
        'nama_murid': _studentName,
        'id_guru': _idGuru, 
        'user_id': currentUserId,
        'id_kelas': _idClass,
        'ket_opsi': _ketOpsi,
      };

      final inserted = await dbIzin.submitIzin(data);
      final idIzin = inserted['id_tabel'];

      if (_idGuru == null || _idGuru!.isEmpty) {
        throw Exception("Wali kelas tidak ditemukan. (Debug: id_murid=$_idMurid, id_class=$_idClass, id_guru=$_idGuru)");
      }

      final startDateStr = DateFormat('dd MMM yyyy').format(_startDate!);
      final endDateStr = DateFormat('dd MMM yyyy').format(_endDate!);
      final jenisLabel = _ketOpsi == 'sakit' ? 'Sakit' : 'Izin';
      final textPesanPrivate = "📋 *Pengajuan Izin*\nJenis: $jenisLabel\nNama: $_studentName\nTanggal: $startDateStr s/d $endDateStr\nKeterangan: ${_keteranganController.text}\nLampiran: $lampiranString\nID_IZIN: $idIzin";
      
      await Supabase.instance.client.from('chat_private').insert({
        'text': textPesanPrivate,
        'pengirim_murid': _idMurid,
        'penerima_guru': _idGuru,
        'user_id': currentUserId,
        'id_izin': idIzin,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin berhasil diajukan!')));
        
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => MainScreenOrtu()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Image.asset('lib/assets/icons/Button.png', width: 30, height: 30),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: -5,
        title: const Text("Pengajuan Izin"),
        titleTextStyle: const TextStyle(
          fontFamily: "Inter",
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Nama'),
                  _buildReadOnlyField(_studentName),
                  const SizedBox(height: 20),

                  _buildLabel('Tanggal Mulai'),
                  GestureDetector(
                    onTap: () => _pickDate(context, true),
                    child: _buildDateBox(_startDate),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Tanggal Selesai'),
                  GestureDetector(
                    onTap: () => _pickDate(context, false),
                    child: _buildDateBox(_endDate),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Pilihan Izin (Izin / Sakit)'),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Izin')),
                          selected: _ketOpsi == 'izin',
                          selectedColor: const Color(0xFF2563EB),
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            fontFamily: 'Inter',
                            color: _ketOpsi == 'izin' ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (selected) {
                            if (selected) setState(() => _ketOpsi = 'izin');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Sakit')),
                          selected: _ketOpsi == 'sakit',
                          selectedColor: const Color(0xFF2563EB),
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            fontFamily: 'Inter',
                            color: _ketOpsi == 'sakit' ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (selected) {
                            if (selected) setState(() => _ketOpsi = 'sakit');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Keterangan Izin'),
                  TextFormField(
                    controller: _keteranganController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Jelaskan alasan izin...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
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
                        borderSide: const BorderSide(color: Color(0xFF2563EB)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildLabel('Foto / Dokumen Surat Izin'),
                  GestureDetector(
                    onTap: _showAttachmentOptions,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1, 
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.file_upload_outlined,
                              color: Color(0xFF2563EB),
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Unggah Foto / Dokumen',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Mendukung banyak file & gambar dari kamera',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  _buildFileList(),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Ajukan Izin',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildFileList() {
    if (_selectedFiles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildLabel('File Terpilih (${_selectedFiles.length})'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_selectedFiles.length, (index) {
            final file = _selectedFiles[index];
            final extension = file.name.split('.').last.toLowerCase();
            final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
            final extLabel = extension.length > 4
                ? extension.substring(0, 4).toUpperCase()
                : extension.toUpperCase();
            final cleanName = file.name.replaceFirst(RegExp(r'^\d{13}_'), '');

            return Stack(
              clipBehavior: Clip.none,
              children: [
                if (isImage && file.bytes != null)
                  GestureDetector(
                    onTap: () {
                      // Pratinjau gambar penuh menggunakan bytes lokal
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.black,
                          insetPadding: EdgeInsets.zero,
                          child: Stack(
                            children: [
                              InteractiveViewer(
                                child: Image.memory(
                                  file.bytes!,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                              Positioned(
                                top: 16,
                                right: 16,
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        file.bytes!,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxWidth: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 42,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              extLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                                fontFamily: 'Inter',
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
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${extLabel} • ${(file.size / 1024).toStringAsFixed(1)} KB',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                // Tombol hapus di pojok kanan atas
                Positioned(
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFiles.removeAt(index);
                      });
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildDateBox(DateTime? date) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: Color(0xFF94A3B8), size: 20),
              const SizedBox(width: 12),
              Text(
                date != null ? DateFormat('MM/dd/yyyy').format(date) : 'mm/dd/yyyy',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: date != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const Icon(Icons.calendar_month, color: Color(0xFF1E293B), size: 20),
        ],
      ),
    );
  }
}
