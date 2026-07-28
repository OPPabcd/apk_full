// Removed dart:io
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:apk/dashboard/d_c_murid/database/db_izin.dart';
import 'package:apk/dashboard/d_c_murid/bottom_bar/nav_screen_o.dart';
import 'package:apk/session_timer/session_time.dart';
import 'package:apk/closed_app/closed.dart';
import 'package:apk/error_handler/connection.dart';

class LeaveRequest extends StatefulWidget {
  const LeaveRequest({super.key});

  @override
  State<LeaveRequest> createState() => _LeaveRequestState();
}

class _LeaveRequestState extends State<LeaveRequest> {
  final TextEditingController _keteranganController = TextEditingController();
  
  DateTime? _startDate;
  DateTime? _endDate;
  PlatformFile? _selectedFile;
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
    final hasConn = await ConnectionHandler.checkConnection();
    if (!hasConn) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ConnectionHandler.showNoConnectionDialog(
          context: context,
          onRetry: () {
            setState(() => _isLoadingData = true);
            _fetchUserData();
          },
        );
      }
      return;
    }

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

        // 1. Coba cari Wali Kelas dari tabel class_name
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
        
        // 2. Fallback: Coba cari dari tabel guru di mana id_class = resolvedIdClass
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
          // Validasi jika tanggal akhir lebih kecil dari tanggal mulai
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf'],
      withData: true, // Sangat penting untuk support Web
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  Future<void> _submitData() async {
    final hasConn = await ConnectionHandler.checkConnection();
    if (!hasConn) {
      if (mounted) {
        ConnectionHandler.showNoConnectionDialog(
          context: context,
          onRetry: () {
            // Can be retried by clicking submit again
          },
        );
      }
      return;
    }

    if (_idMurid == null || _userIdAdmin == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal: Data profil tidak lengkap! Coba muat ulang aplikasi.')));
      return;
    }

    if (_startDate == null || _endDate == null || _keteranganController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap lengkapi isi tanggal dan keterangan izin')));
      return;
    }

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap unggah foto/dokumen surat izin')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final dbIzin = DbIzin();
      
      // Pastikan file memiliki bytes (khususnya untuk Web)
      if (_selectedFile!.bytes == null) {
        throw Exception("Gagal membaca data file.");
      }

      // Ambil Supabase Current User ID agar lolos dari RLS Policy
      final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? _userIdAdmin!;

      // Upload File ke Supabase Storage (doc_izin/auth_id/nis/filename)
      final lampiranUrl = await dbIzin.uploadIzinFile(currentUserId, _studentNis!, _selectedFile!.bytes!, _selectedFile!.name);

      // Insert to Table leave_request
      final data = {
        'tanggal_mulai': DateFormat('yyyy-MM-dd').format(_startDate!),
        'tanggal_selesai': DateFormat('yyyy-MM-dd').format(_endDate!),
        'keterangan': _keteranganController.text,
        'verif': null, // default is null (pending)
        'id_murid': _idMurid,
        'nama_murid': _studentName,
        'id_guru': _idGuru, // Memasukkan ID Guru dari tabel murid untuk verifikasi wali kelas
        'user_id': currentUserId,
        'id_kelas': _idClass,
        'ket_opsi': _ketOpsi,
      };

      final inserted = await dbIzin.submitIzin(data);
      final idIzin = inserted['id_tabel'];

      // Kirim pesan privat ke Wali Kelas
      if (_idGuru == null || _idGuru!.isEmpty) {
        throw Exception("Wali kelas tidak ditemukan. (Debug: id_murid=$_idMurid, id_class=$_idClass, id_guru=$_idGuru)");
      }

      final startDateStr = DateFormat('dd MMM yyyy').format(_startDate!);
      final endDateStr = DateFormat('dd MMM yyyy').format(_endDate!);
      final jenisLabel = _ketOpsi == 'sakit' ? 'Sakit' : 'Izin';
      final textPesanPrivate = "📋 *Pengajuan Izin*\nJenis: $jenisLabel\nNama: $_studentName\nTanggal: $startDateStr s/d $endDateStr\nKeterangan: ${_keteranganController.text}\nLampiran: $lampiranUrl\nID_IZIN: $idIzin";
      
      await Supabase.instance.client.from('chat_private').insert({
        'text': textPesanPrivate,
        'pengirim_murid': _idMurid,
        'penerima_guru': _idGuru,
        'user_id': currentUserId,
        'id_izin': idIzin,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin berhasil diajukan!')));
        
        // Reload halaman dengan kembali ke MainScreenOrtu (beranda)
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
    return SessionTimeManager(
      child: WillPopScope(
        onWillPop: () => handleDoubleTapToExit(context),
        child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Pengajuan Izin'),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama Field (Read Only)
                  _buildLabel('Nama'),
                  _buildReadOnlyField(_studentName),
                  const SizedBox(height: 20),

                  // Tanggal Mulai
                  _buildLabel('Tanggal Mulai'),
                  GestureDetector(
                    onTap: () => _pickDate(context, true),
                    child: _buildDateBox(_startDate),
                  ),
                  const SizedBox(height: 20),

                  // Tanggal Selesai
                  _buildLabel('Tanggal Selesai'),
                  GestureDetector(
                    onTap: () => _pickDate(context, false),
                    child: _buildDateBox(_endDate),
                  ),
                  const SizedBox(height: 20),

                  // Pilihan Izin / Sakit (ket_opsi)
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

                  // Keterangan Izin
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

                  // Upload Surat Izin
                  _buildLabel('Foto Surat Izin'),
                  GestureDetector(
                    onTap: _pickFile,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          style: BorderStyle.solid,
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
                          const SizedBox(height: 16),
                          Text(
                            _selectedFile != null
                                ? _selectedFile!.name
                                : 'Upload Foto / Dokumen',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _selectedFile != null ? const Color(0xFF1E293B) : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap untuk memilih file',
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
                  const SizedBox(height: 40),

                  // Submit Button
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
        ),
      ),
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
