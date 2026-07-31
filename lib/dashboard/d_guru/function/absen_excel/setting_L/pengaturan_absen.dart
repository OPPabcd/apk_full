import 'package:flutter/material.dart';
import 'package:apk/dashboard/d_guru/database/db_absensi.dart';

class UpdateAbsenBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> muridList;
  final int daysInMonth;
  final String yearMonth;
  final Map<String, String> absenIdMap;
  final List<String> initialSelectedStudentIds;
  final List<int> initialSelectedDays;
  final VoidCallback onUpdated;

  const UpdateAbsenBottomSheet({
    super.key,
    required this.muridList,
    required this.daysInMonth,
    required this.yearMonth,
    required this.absenIdMap,
    required this.initialSelectedStudentIds,
    required this.initialSelectedDays,
    required this.onUpdated,
  });

  @override
  State<UpdateAbsenBottomSheet> createState() => _UpdateAbsenBottomSheetState();
}

class _UpdateAbsenBottomSheetState extends State<UpdateAbsenBottomSheet> {
  final DbAbsensi _dbAbsensi = DbAbsensi();
  String? _selectedStatusKey = 'alpha';
  bool _isSaving = false;
  String? _errorMessage;

  late Set<String> _selectedStudentIds;
  late Set<int> _selectedDays;

  final List<Map<String, dynamic>> _statusOptions = [
    {
      'key': 'alpha',
      'label': 'Alpha',
      'code': 'A',
      'color': const Color(0xFFDC2626),
      'lightColor': const Color(0xFFFEE2E2),
    },
    {
      'key': 'libur',
      'label': 'Libur',
      'code': 'L',
      'color': const Color(0xFF4F46E5),
      'lightColor': const Color(0xFFE0E7FF),
    },
    {
      'key': 'belum_absen',
      'label': 'Belum Absen',
      'code': '-',
      'color': const Color(0xFF64748B),
      'lightColor': const Color(0xFFF1F5F9),
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedStudentIds = Set<String>.from(widget.initialSelectedStudentIds);
    _selectedDays = Set<int>.from(widget.initialSelectedDays);
  }

  Future<void> _saveChanges() async {
    if (_selectedStudentIds.isEmpty) {
      setState(() {
        _errorMessage = 'Silakan centang minimal 1 siswa.';
      });
      return;
    }
    if (_selectedDays.isEmpty) {
      setState(() {
        _errorMessage = 'Silakan centang minimal 1 hari.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final dbStatus = _selectedStatusKey == 'belum_absen' ? null : _selectedStatusKey;
      
      // Kumpulkan semua idTabel dari database untuk kombinasi yang dipilih
      final List<String> idsToUpdate = [];
      for (final idM in _selectedStudentIds) {
        for (final d in _selectedDays) {
          final idTab = widget.absenIdMap['${idM}_$d'];
          if (idTab != null) {
            idsToUpdate.add(idTab);
          }
        }
      }

      if (idsToUpdate.isEmpty) {
        setState(() {
          _errorMessage = 'Tidak ditemukan data absensi untuk kombinasi siswa & tanggal terpilih.';
          _isSaving = false;
        });
        return;
      }

      // Jalankan update secara paralel agar sangat cepat
      await Future.wait(
        idsToUpdate.map((id) => _dbAbsensi.updateStudentSessionStatus(
          idTabel: id,
          selectedStatus: dbStatus,
        ))
      );

      if (mounted) {
        widget.onUpdated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Absensi ${idsToUpdate.length} record berhasil diupdate.'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal menyimpan perubahan: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Header info
            const Text(
              'Pembaruan Massal Absensi',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bulan/Tahun: ${widget.yearMonth}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const Divider(height: 24),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFFDC2626),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Section 1: Pilihan Status
            const Text(
              '1. Pilih Status Absensi',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.0,
              ),
              itemCount: _statusOptions.length,
              itemBuilder: (context, index) {
                final opt = _statusOptions[index];
                final isSelected = _selectedStatusKey == opt['key'];
                return InkWell(
                  onTap: _isSaving
                      ? null
                      : () {
                          setState(() {
                            _selectedStatusKey = opt['key'];
                            if (_selectedStatusKey == 'libur') {
                              _selectedStudentIds = widget.muridList
                                  .map((m) => m['id_tabel']?.toString())
                                  .whereType<String>()
                                  .toSet();
                            }
                          });
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? opt['lightColor'] : Colors.white,
                      border: Border.all(
                        color: isSelected ? opt['color'] : const Color(0xFFE2E8F0),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: opt['color'],
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            opt['code'],
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            opt['label'],
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: const Color(0xFF334155),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // Section 2: Pilihan Hari
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '2. Pilih Hari (${_selectedDays.length}/${widget.daysInMonth})',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              setState(() {
                                _selectedDays = List.generate(widget.daysInMonth, (i) => i + 1).toSet();
                              });
                            },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Semua', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              setState(() {
                                _selectedDays.clear();
                              });
                            },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Kosongkan', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: List.generate(widget.daysInMonth, (index) {
                  final d = index + 1;
                  final isSel = _selectedDays.contains(d);
                  return InkWell(
                    onTap: _isSaving
                        ? null
                        : () {
                            setState(() {
                              if (isSel) {
                                _selectedDays.remove(d);
                              } else {
                                _selectedDays.add(d);
                              }
                            });
                          },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF2563EB) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                          width: 1,
                        ),
                        boxShadow: isSel
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$d',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: isSel ? Colors.white : const Color(0xFF334155),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Section 3: Pilihan Siswa
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '3. Pilih Siswa (${_selectedStudentIds.length}/${widget.muridList.length})',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _isSaving || _selectedStatusKey == 'libur'
                          ? null
                          : () {
                              setState(() {
                                _selectedStudentIds = widget.muridList
                                    .map((m) => m['id_tabel']?.toString())
                                    .whereType<String>()
                                    .toSet();
                              });
                            },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Semua', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _isSaving || _selectedStatusKey == 'libur'
                          ? null
                          : () {
                              setState(() {
                                _selectedStudentIds.clear();
                              });
                            },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Kosongkan', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            if (_selectedStatusKey == 'libur') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hari Libur otomatis berlaku untuk semua siswa.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFF1D4ED8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.muridList.length,
                  itemBuilder: (context, index) {
                    final m = widget.muridList[index];
                    final idM = m['id_tabel']?.toString();
                    final nama = m['nama']?.toString() ?? 'Siswa';
                    final nis = m['nis']?.toString() ?? '-';
                    final isSel = idM != null && _selectedStudentIds.contains(idM);
                    
                    return InkWell(
                      onTap: _isSaving || idM == null || _selectedStatusKey == 'libur'
                          ? null
                          : () {
                              setState(() {
                                if (isSel) {
                                  _selectedStudentIds.remove(idM);
                                } else {
                                  _selectedStudentIds.add(idM);
                                }
                              });
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: isSel,
                                activeColor: const Color(0xFF2563EB),
                                onChanged: _isSaving || idM == null || _selectedStatusKey == 'libur'
                                    ? null
                                    : (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedStudentIds.add(idM);
                                          } else {
                                            _selectedStudentIds.remove(idM);
                                          }
                                        });
                                      },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nama,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    'NIS: $nis',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      color: Colors.grey[500],
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
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Actions Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Simpan',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
