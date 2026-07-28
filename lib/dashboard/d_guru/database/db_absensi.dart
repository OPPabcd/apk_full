import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db_kelas.dart';

import 'holiday_service.dart';

class DbAbsensi {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getAbsensi(String nisOrId) async {
    try {
      String idMurid = nisOrId;
      String? studentNis;
      String? userId;
      String? studentName;
      
      final isNumeric = RegExp(r'^\d+$').hasMatch(nisOrId);
      if (isNumeric) {
        final res = await _supabase
            .from('murid')
            .select('id_tabel, user_id, nis, nama')
            .eq('nis', nisOrId)
            .maybeSingle();
        if (res != null) {
          idMurid = res['id_tabel'].toString();
          userId = res['user_id']?.toString();
          studentNis = res['nis']?.toString();
          studentName = res['nama']?.toString();
        }
      } else {
        final res = await _supabase
            .from('murid')
            .select('user_id, nis, nama')
            .eq('id_tabel', nisOrId)
            .maybeSingle();
        if (res != null) {
          userId = res['user_id']?.toString();
          studentNis = res['nis']?.toString();
          studentName = res['nama']?.toString();
        }
      }

      final response = await _supabase
          .from('absen')
          .select('*, leave_request:id_izin(*), access_bridge:id_access(*, output_alat(*)), murid:id_murid(*), pengumuman:id_pengumuman(*)')
          .eq('id_murid', idMurid)
          .order('date', ascending: false);
          
      // Fetch verified access records (processed on DB side, read via query relations)
      List<Map<String, dynamic>> accessResponse = [];

      // Fetch approved leave requests
      List<Map<String, dynamic>> leaveResponse = [];
      if (idMurid.isNotEmpty) {
        try {
          final res = await _supabase
              .from('leave_request')
              .select('*')
              .eq('id_murid', idMurid)
              .eq('verif', true);
          leaveResponse = List<Map<String, dynamic>>.from(res);
        } catch (_) {}
      }

      final Map<String, Map<String, dynamic>> consolidatedLeave = {};
      for (var req in leaveResponse) {
        final startStr = req['tanggal_mulai']?.toString();
        final endStr = req['tanggal_selesai']?.toString();
        if (startStr == null || endStr == null) continue;
        try {
          final start = DateTime.parse(startStr);
          final end = DateTime.parse(endStr);
          for (int d = 0; d <= end.difference(start).inDays; d++) {
            final currentDate = start.add(Duration(days: d));
            final dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
            consolidatedLeave[dateKey] = {
              'id_tabel': req['id_tabel']?.toString(),
              'ket_opsi': req['ket_opsi']?.toString() ?? 'izin',
            };
          }
        } catch (_) {}
      }

      final Map<String, Map<String, dynamic>> consolidatedAccess = {};

      for (var row in accessResponse) {
        if (row['created_at'] == null) continue;
        
        DateTime? parsedDate;
        try {
          parsedDate = DateTime.parse(row['created_at'].toString()).toLocal();
        } catch (_) {}
        if (parsedDate == null) continue;
        
        final dateKey = DateFormat('yyyy-MM-dd').format(parsedDate);
        
        final rawMasuk = row['data_masuk'];
        
        final formattedMasuk = _formatTime(rawMasuk) ?? '07:00';

        if (!consolidatedAccess.containsKey(dateKey)) {
          consolidatedAccess[dateKey] = {
            'date': dateKey,
            'id_tabel': row['id_tabel']?.toString(),
            'id_murid': idMurid,
            'id_alat': row['id_alat']?.toString(),
            'user_id': row['user_id'],
            'masuk': formattedMasuk,
            'keluar': null,
            'output_alat': row['output_alat'],
          };
        } else {
          final existing = consolidatedAccess[dateKey]!;
          if (existing['masuk'] == null) {
            existing['masuk'] = formattedMasuk;
          }
        }
      }

      final Map<String, dynamic> studentMuridMap = {
        'id_tabel': idMurid,
        'user_id': userId,
        'nis': studentNis,
        'nama': studentName,
      };

      return _mergeAbsenWithAccess(response, consolidatedAccess, idMurid, studentMuridMap, consolidatedLeave);
    } catch (e) {
      throw Exception('Gagal memuat data absensi: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAbsensiByMonth(List<String> listNis, String yearMonth) async {
    if (listNis.isEmpty) return [];
    try {
      final muridRes = await _supabase
          .from('murid')
          .select('id_tabel, user_id, nis, nama')
          .inFilter('nis', listNis);
      
      final listIdMurid = muridRes.map((m) => m['id_tabel'].toString()).toList();
      final listUserIds = muridRes.map((m) => m['user_id']?.toString()).whereType<String>().toList();
      if (listIdMurid.isEmpty) return [];

      // Parse year and month to construct date range filtering
      final parts = yearMonth.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final startDate = '$yearMonth-01';
      final lastDay = DateTime(year, month + 1, 0).day;
      final lastDayStr = lastDay < 10 ? '0$lastDay' : '$lastDay';
      final endDate = '$year-${parts[1]}-$lastDayStr';

      final response = await _supabase
          .from('absen')
          .select('*, leave_request:id_izin(*), access_bridge:id_access(*, output_alat(*)), murid:id_murid(*), pengumuman:id_pengumuman(*)')
          .inFilter('id_murid', listIdMurid)
          .gte('date', startDate)
          .lte('date', endDate)
          .order('date', ascending: true);

      final Map<String, Map<String, dynamic>> muridMapById = {};
      final Map<String, String> studentNamesById = {};
      for (var m in muridRes) {
        final id = m['id_tabel'].toString();
        muridMapById[id] = Map<String, dynamic>.from(m);
        studentNamesById[id] = m['nama']?.toString() ?? '';
      }

      // Fetch verified access records directly from access_bridge (synced/processed on DB side)
      List<Map<String, dynamic>> accessResponse = [];
      try {
        final res = await _supabase
            .from('access_bridge')
            .select('*, output_alat(*)')
            .inFilter('id_murid', listIdMurid);
        accessResponse = List<Map<String, dynamic>>.from(res);
      } catch (_) {}

      // Fetch approved leave requests
      List<Map<String, dynamic>> leaveResponse = [];
      try {
        final res = await _supabase
            .from('leave_request')
            .select('*')
            .inFilter('id_murid', listIdMurid)
            .eq('verif', true);
        leaveResponse = List<Map<String, dynamic>>.from(res);
      } catch (_) {}

      final Map<String, Map<String, dynamic>> consolidatedLeave = {};
      for (var req in leaveResponse) {
        final studentId = req['id_murid']?.toString();
        final startStr = req['tanggal_mulai']?.toString();
        final endStr = req['tanggal_selesai']?.toString();
        if (studentId == null || startStr == null || endStr == null) continue;
        
        try {
          final start = DateTime.parse(startStr);
          final end = DateTime.parse(endStr);
          for (int d = 0; d <= end.difference(start).inDays; d++) {
            final currentDate = start.add(Duration(days: d));
            final dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
            final compositeKey = '${studentId}_$dateKey';
            consolidatedLeave[compositeKey] = {
              'id_tabel': req['id_tabel']?.toString(),
              'ket_opsi': req['ket_opsi']?.toString() ?? 'izin',
            };
          }
        } catch (_) {}
      }

      // Group access logs by student (NIS) and date
      final Map<String, Map<String, dynamic>> consolidatedAccess = {};
      for (var row in accessResponse) {
        if (row['created_at'] == null) continue;
        
        DateTime? parsedDate;
        try {
          parsedDate = DateTime.parse(row['created_at'].toString()).toLocal();
        } catch (_) {}
        if (parsedDate == null) continue;
        
        final matchedStudentId = row['id_murid']?.toString();
        if (matchedStudentId == null) continue;

        final dateKey = DateFormat('yyyy-MM-dd').format(parsedDate);
        final compositeKey = '${matchedStudentId}_$dateKey';
        
        final rawMasuk = row['data_masuk'];
        
        final formattedMasuk = _formatTime(rawMasuk) ?? '07:00';

        if (!consolidatedAccess.containsKey(compositeKey)) {
          consolidatedAccess[compositeKey] = {
            'date': dateKey,
            'id_tabel': row['id_tabel']?.toString(),
            'id_murid': matchedStudentId,
            'id_alat': row['id_alat']?.toString(),
            'user_id': row['user_id'],
            'masuk': formattedMasuk,
            'keluar': null,
            'output_alat': row['output_alat'],
          };
        } else {
          final existing = consolidatedAccess[compositeKey]!;
          if (existing['masuk'] == null) {
            existing['masuk'] = formattedMasuk;
          }
        }
      }

      // Merge absen with consolidatedAccess & consolidatedLeave
      final List<Map<String, dynamic>> mergedList = [];
      final Set<String> processedCompositeKeys = {};

      for (var item in response) {
        final row = Map<String, dynamic>.from(item);
        final dateKey = row['date']?.toString();
        final studentId = row['id_murid']?.toString();
        
        if (dateKey != null && studentId != null) {
          final compositeKey = '${studentId}_$dateKey';
          processedCompositeKeys.add(compositeKey);
          
          if (consolidatedAccess.containsKey(compositeKey)) {
            final access = consolidatedAccess[compositeKey]!;
            row['masuk'] = access['masuk'] ?? row['masuk'];
            row['keluar'] = access['keluar'] ?? row['keluar'];
            row['access_bridge'] = {
              'id_tabel': access['id_tabel'] ?? '',
              'id_alat': access['id_alat'],
              'id_murid': access['id_murid'],
              'user_id': access['user_id'],
              'data_masuk': access['masuk'],
              'data_keluar': access['keluar'],
              'output_alat': access['output_alat'],
            };
          } else if (row['access_bridge'] != null) {
            final accessBridge = row['access_bridge'] as Map<dynamic, dynamic>;
            final rawMasuk = accessBridge['data_masuk'] ?? accessBridge['masuk'];
            final rawKeluar = accessBridge['data_keluar'] ?? accessBridge['keluar'];
            
            final formattedMasuk = _formatTime(rawMasuk) ?? '07:00';
            final formattedKeluar = _formatTime(rawKeluar);
            
            row['masuk'] = formattedMasuk;
            if (formattedKeluar != null) row['keluar'] = formattedKeluar;
          }

          if (row['leave_request'] == null && consolidatedLeave.containsKey(compositeKey)) {
            final leave = consolidatedLeave[compositeKey]!;
            row['leave_request'] = {
              'id_tabel': leave['id_tabel'],
              'ket_opsi': leave['ket_opsi'],
              'verif': true,
            };
          }
        }
        mergedList.add(row);
      }

      // Add synthesized ones from consolidatedAccess
      consolidatedAccess.forEach((compositeKey, access) {
        if (!processedCompositeKeys.contains(compositeKey)) {
          processedCompositeKeys.add(compositeKey);
          final studentId = access['id_murid']?.toString();

          Map<String, dynamic>? leaveRequestData;
          if (consolidatedLeave.containsKey(compositeKey)) {
            final leave = consolidatedLeave[compositeKey]!;
            leaveRequestData = {
              'id_tabel': leave['id_tabel'],
              'ket_opsi': leave['ket_opsi'],
              'verif': true,
            };
          }

          final synthRow = {
            'date': access['date'],
            'id_murid': studentId,
            'masuk': access['masuk'],
            'keluar': access['keluar'],
            'access_bridge': {
              'id_tabel': access['id_tabel'] ?? '',
              'id_alat': access['id_alat'],
              'id_murid': access['id_murid'],
              'user_id': access['user_id'],
              'data_masuk': access['masuk'],
              'data_keluar': access['keluar'],
              'output_alat': access['output_alat'],
            },
            'murid': studentId != null ? muridMapById[studentId] : null,
            'leave_request': leaveRequestData,
            'pengumuman': null,
          };
          mergedList.add(synthRow);
        }
      });

      // Add synthesized ones from consolidatedLeave
      consolidatedLeave.forEach((compositeKey, leave) {
        if (!processedCompositeKeys.contains(compositeKey)) {
          processedCompositeKeys.add(compositeKey);
          final parts = compositeKey.split('_');
          final studentId = parts.first;
          final dateKey = parts.last;

          final synthRow = {
            'date': dateKey,
            'id_murid': studentId,
            'masuk': null,
            'keluar': null,
            'access_bridge': null,
            'murid': muridMapById[studentId],
            'leave_request': {
              'id_tabel': leave['id_tabel'],
              'ket_opsi': leave['ket_opsi'],
              'verif': true,
            },
            'pengumuman': null,
          };
          mergedList.add(synthRow);
        }
      });

      // Sort by date ascending
      mergedList.sort((a, b) {
        final dateA = a['date']?.toString() ?? '';
        final dateB = b['date']?.toString() ?? '';
        return dateA.compareTo(dateB);
      });

      return mergedList;
    } catch (e) {
      throw Exception('Gagal memuat data absensi kelas: $e');
    }
  }

  List<Map<String, dynamic>> _mergeAbsenWithAccess(
      List<dynamic> absenResponse,
      Map<String, Map<String, dynamic>> consolidatedAccess,
      String idMurid,
      Map<String, dynamic> studentMuridMap,
      Map<String, Map<String, dynamic>> consolidatedLeave) {
      
    final List<Map<String, dynamic>> mergedList = [];
    final Set<String> processedDates = {};

    for (var item in absenResponse) {
      final row = Map<String, dynamic>.from(item);
      final dateKey = row['date']?.toString();
      
      if (dateKey != null) {
        processedDates.add(dateKey);
        
        if (consolidatedAccess.containsKey(dateKey)) {
          final access = consolidatedAccess[dateKey]!;
          
          row['masuk'] = access['masuk'] ?? row['masuk'];
          row['keluar'] = access['keluar'] ?? row['keluar'];
          
          row['access_bridge'] = {
            'id_tabel': access['id_tabel'] ?? '',
            'id_alat': access['id_alat'],
            'id_murid': access['id_murid'],
            'user_id': access['user_id'],
            'data_masuk': access['masuk'],
            'data_keluar': access['keluar'],
            'output_alat': access['output_alat'],
          };
        } else if (row['access_bridge'] != null) {
          final accessBridge = row['access_bridge'] as Map<dynamic, dynamic>;
          final rawMasuk = accessBridge['data_masuk'] ?? accessBridge['masuk'];
          final rawKeluar = accessBridge['data_keluar'] ?? accessBridge['keluar'];
          
          final formattedMasuk = _formatTime(rawMasuk) ?? '07:00';
          final formattedKeluar = _formatTime(rawKeluar);
          
          row['masuk'] = formattedMasuk;
          if (formattedKeluar != null) row['keluar'] = formattedKeluar;
        }
        
        if (row['leave_request'] == null && consolidatedLeave.containsKey(dateKey)) {
          final leave = consolidatedLeave[dateKey]!;
          row['leave_request'] = {
            'id_tabel': leave['id_tabel'],
            'ket_opsi': leave['ket_opsi'],
            'verif': true,
          };
        }
      }
      mergedList.add(row);
    }

    consolidatedAccess.forEach((dateKey, access) {
      if (!processedDates.contains(dateKey)) {
        processedDates.add(dateKey);
        
        Map<String, dynamic>? leaveRequestData;
        if (consolidatedLeave.containsKey(dateKey)) {
          final leave = consolidatedLeave[dateKey]!;
          leaveRequestData = {
            'id_tabel': leave['id_tabel'],
            'ket_opsi': leave['ket_opsi'],
            'verif': true,
          };
        }

        final synthRow = {
          'date': dateKey,
          'id_murid': idMurid,
          'masuk': access['masuk'],
          'keluar': access['keluar'],
          'access_bridge': {
            'id_tabel': access['id_tabel'] ?? '',
            'id_alat': access['id_alat'],
            'id_murid': access['id_murid'],
            'user_id': access['user_id'],
            'data_masuk': access['masuk'],
            'data_keluar': access['keluar'],
            'output_alat': access['output_alat'],
          },
          'murid': studentMuridMap,
          'leave_request': leaveRequestData,
          'pengumuman': null,
        };
        mergedList.add(synthRow);
      }
    });

    consolidatedLeave.forEach((dateKey, leave) {
      if (!processedDates.contains(dateKey)) {
        processedDates.add(dateKey);
        final synthRow = {
          'date': dateKey,
          'id_murid': idMurid,
          'masuk': null,
          'keluar': null,
          'access_bridge': null,
          'murid': studentMuridMap,
          'leave_request': {
            'id_tabel': leave['id_tabel'],
            'ket_opsi': leave['ket_opsi'],
            'verif': true,
          },
          'pengumuman': null,
        };
        mergedList.add(synthRow);
      }
    });

    mergedList.sort((a, b) {
      final dateA = a['date']?.toString() ?? '';
      final dateB = b['date']?.toString() ?? '';
      return dateB.compareTo(dateA);
    });

    return mergedList;
  }

  static String? _formatTime(dynamic timeVal) {
    if (timeVal == null) return null;
    final str = timeVal.toString().trim();
    if (str.isEmpty) return null;
    
    // Check if it is a full ISO8601 DateTime string
    final parsed = DateTime.tryParse(str);
    if (parsed != null) {
      return DateFormat('HH:mm').format(parsed.toLocal());
    }

    final parts = str.split(':');
    if (parts.length >= 2) {
      var hour = parts[0];
      if (hour.contains('T')) {
        hour = hour.split('T').last;
      }
      hour = hour.padLeft(2, '0');
      var minute = parts[1];
      if (minute.length > 2) {
        minute = minute.substring(0, 2);
      }
      minute = minute.padLeft(2, '0');
      return "$hour:$minute";
    }
    return str;
  }

  static String getStatus(Map<String, dynamic> row) {
    // 0. Cek MANUAL override terlebih dahulu agar memiliki prioritas tertinggi
    if (row['Null_data']?.toString() == 'Belum Absen') return 'Belum Absen';
    if (row['ket_sakit']?.toString().startsWith('MANUAL_') ?? false) return 'Sakit';
    if (row['ket_izin']?.toString().startsWith('MANUAL_') ?? false) return 'Izin';
    if (row['ket_libur']?.toString().startsWith('MANUAL_') ?? false) return 'Libur';
    if (row['ket_alpha']?.toString().startsWith('MANUAL_') ?? false) return 'Alpha';
    if (row['ket_hadir']?.toString().startsWith('MANUAL_') ?? false) {
      final kh = row['ket_hadir'].toString();
      if (kh.toLowerCase().contains('terlambat')) return 'Terlambat';
      return 'Hadir';
    }

    // 1. Izin dan Sakit dari foreign key id_izin (leave_request) yang verify true
    if (row['leave_request'] != null && row['leave_request']['verif'] == true) {
      final ketOpsi = (row['leave_request']['ket_opsi'] ?? '').toString().toLowerCase();
      if (ketOpsi == 'sakit') {
        return 'Sakit';
      }
      if (ketOpsi == 'izin') {
        return 'Izin';
      }
      
      // Fallback ke keterangan jika ket_opsi kosong/null
      final ket = (row['leave_request']['keterangan'] ?? '').toString().toLowerCase();
      if (ket.contains('sakit')) {
        return 'Sakit';
      }
      return 'Izin';
    }

    // Fallback izin/sakit langsung dari tabel absen jika ada data manual
    if (row['ket_sakit'] != null && row['ket_sakit'].toString().isNotEmpty) return 'Sakit';
    if (row['ket_izin'] != null && row['ket_izin'].toString().isNotEmpty) return 'Izin';

    // 2. Libur diambil dari date hari minggu dan foreign key id_pengumuman dengan keterangan libur
    final dateStr = row['date']?.toString() ?? '';
    bool isSundayOrHoliday = false;
    if (dateStr.isNotEmpty) {
      try {
        final date = DateTime.parse(dateStr);
        if (date.weekday == DateTime.sunday || HolidayService.isHoliday(date)) {
          isSundayOrHoliday = true;
        }
      } catch (_) {}
    }

    bool isPengumumanLibur = false;
    if (row['pengumuman'] != null) {
      final title = (row['pengumuman']['title'] ?? '').toString().toLowerCase();
      final keterangan = (row['pengumuman']['keterangan'] ?? '').toString().toLowerCase();
      if (title.contains('libur') || keterangan.contains('libur')) {
        isPengumumanLibur = true;
      }
    }

    if (isSundayOrHoliday || isPengumumanLibur) {
      return 'Libur';
    }
    if (row['ket_libur'] != null && row['ket_libur'].toString().isNotEmpty) return 'Libur';

    // 3. Hadir / Terlambat diambil dari foreign key id_access (access_bridge)
    if (row['access_bridge'] != null) {
      final accessBridge = row['access_bridge'];
      
      // Perform security check: match nama_user (from output_alat) with murid.nama
      final outputAlat = accessBridge['output_alat'];
      final namaUser = outputAlat != null ? outputAlat['nama_user']?.toString() : null;
      final studentName = row['murid'] != null ? row['murid']['nama']?.toString() : null;
      
      bool nameMatches = true;
      if (studentName != null && namaUser != null) {
        if (namaUser.trim().toLowerCase() != studentName.trim().toLowerCase()) {
          nameMatches = false;
        }
      }

      if (nameMatches) {
        final rawMasuk = accessBridge['data_masuk'];
        final formattedMasuk = _formatTime(rawMasuk) ?? '07:00';
        
        // Hanya dianggap hadir jika ada data masuk (absen sekali)
        if (formattedMasuk.trim().isNotEmpty) {
          final parts = formattedMasuk.split(':');
          if (parts.length >= 2) {
            final hour = int.tryParse(parts[0]) ?? 0;
            final minute = int.tryParse(parts[1]) ?? 0;
            if (hour > 7 || (hour == 7 && minute > 0)) {
              return 'Terlambat';
            }
          }
          return 'Hadir';
        }
      }
    }

    // Fallback ket_hadir / masuk / terlambat dari tabel absen langsung
    if (row['ket_hadir'] != null && row['ket_hadir'].toString().isNotEmpty) {
      final kh = row['ket_hadir'].toString();
      if (kh.toLowerCase().contains('terlambat')) return 'Terlambat';
      return 'Hadir';
    }
    if (row['terlambat'] != null && row['terlambat'].toString().isNotEmpty) return 'Terlambat';
    if (row['masuk'] != null && row['masuk'].toString().isNotEmpty) return 'Hadir';

    // 4. Alpha
    if (row['ket_alpha'] != null && row['ket_alpha'].toString().isNotEmpty) return 'Alpha';

    return 'Belum Absen';
  }

  // === MONTHLY REKAP METHODS ===

  /// Generate rekap bulanan: buat row di tabel absen untuk semua murid × semua hari
  /// dengan absensi_baru = 'REKAP_{yearMonth}'.
  /// Menerima [students] langsung agar tidak fetch ulang & filter per kelas benar.
  /// Hanya insert baris yang belum ada (per-murid check).
  Future<void> generateMonthlyRekap(
    String yearMonth,
    List<Map<String, dynamic>> students,
  ) async {
    if (students.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id_admin');
    if (userId == null) throw Exception('Sesi tidak valid.');

    final rekapKey = 'REKAP_$yearMonth';

    // Parse year & month
    final parts = yearMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // Kumpulkan id_murid yang akan diproses
    final listIdMurid = students
        .map((m) => m['id_tabel']?.toString())
        .where((id) => id != null)
        .cast<String>()
        .toList();
    if (listIdMurid.isEmpty) return;

    // Cek murid mana yang sudah punya baris rekap untuk bulan ini
    final existingRows = await _supabase
        .from('absen')
        .select('id_murid')
        .eq('absensi_baru', rekapKey)
        .inFilter('id_murid', listIdMurid);

    final existingMuridIds = existingRows
        .map((r) => r['id_murid']?.toString())
        .whereType<String>()
        .toSet();

    // Hanya insert untuk murid yang belum punya rekap
    final studentsToInsert = students
        .where((m) => !existingMuridIds.contains(m['id_tabel']?.toString()))
        .toList();

    if (studentsToInsert.isEmpty) return;

    // Generate rows: 1 row per murid per hari
    final List<Map<String, dynamic>> rowsToInsert = [];
    for (var murid in studentsToInsert) {
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        final formattedDate = DateFormat('yyyy-MM-dd').format(date);
        final isSundayOrHoliday =
            date.weekday == DateTime.sunday || HolidayService.isHoliday(date);

        rowsToInsert.add({
          'date': formattedDate,
          'user_id': userId,
          'id_murid': murid['id_tabel'],
          'absensi_baru': rekapKey,
          if (isSundayOrHoliday) 'ket_libur': 'Libur',
        });
      }
    }

    // Batch insert
    if (rowsToInsert.isNotEmpty) {
      await _supabase.from('absen').insert(rowsToInsert);
    }
  }

  /// Sync data rekap bulanan dengan access_bridge & leave_request.
  /// Memperbarui row yang sudah ada di tabel absen.
  /// Menerima [listIdMurid] agar hanya sync murid dari kelas yang sedang dilihat.
  Future<void> syncMonthlyRekap(
    String yearMonth,
    List<String> listIdMurid,
  ) async {
    if (listIdMurid.isEmpty) return;

    final rekapKey = 'REKAP_$yearMonth';
    final parts = yearMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    // 1. Ambil semua row rekap bulan ini, difilter per murid kelas ini
    final rekapRows = await _supabase
        .from('absen')
        .select('id_tabel, date, id_murid, ket_libur, ket_hadir, ket_izin, ket_sakit, ket_alpha, Null_data')
        .eq('absensi_baru', rekapKey)
        .inFilter('id_murid', listIdMurid);

    if (rekapRows.isEmpty) return;

    // Build lookup: compositeKey (id_murid_date) -> row
    final Map<String, Map<String, dynamic>> rekapLookup = {};
    for (var row in rekapRows) {
      final idMurid = row['id_murid']?.toString();
      final date = row['date']?.toString();
      if (idMurid == null || date == null) continue;
      rekapLookup['${idMurid}_$date'] = Map<String, dynamic>.from(row);
    }

    if (listIdMurid.isEmpty) return;

    // 2. Ambil info murid (untuk nama, untuk matching access)
    final muridRes = await _supabase
        .from('murid')
        .select('id_tabel, user_id, nis, nama')
        .inFilter('id_tabel', listIdMurid);

    final Map<String, String> studentNamesById = {};
    final List<String> listUserIds = [];
    for (var m in muridRes) {
      final id = m['id_tabel'].toString();
      studentNamesById[id] = m['nama']?.toString() ?? '';
      final uid = m['user_id']?.toString();
      if (uid != null) listUserIds.add(uid);
    }

    // 3. Sync dari access_bridge (kehadiran via scan alat)
    List<Map<String, dynamic>> accessResponse = [];
    try {
      final res = await _supabase
          .from('access_bridge')
          .select('*, output_alat(*)')
          .inFilter('id_murid', listIdMurid);
      accessResponse = List<Map<String, dynamic>>.from(res);
    } catch (_) {}

    // Build access lookup: compositeKey -> access data (hanya untuk bulan ini)
    final Map<String, Map<String, dynamic>> accessLookup = {};
    for (var row in accessResponse) {
      if (row['created_at'] == null) continue;
      DateTime? parsedDate;
      try {
        parsedDate = DateTime.parse(row['created_at'].toString()).toLocal();
      } catch (_) {}
      if (parsedDate == null) continue;
      // Filter hanya bulan ini
      if (parsedDate.year != year || parsedDate.month != month) continue;

      final idMurid = row['id_murid']?.toString();
      if (idMurid == null) continue;
      final dateKey = DateFormat('yyyy-MM-dd').format(parsedDate);
      final compositeKey = '${idMurid}_$dateKey';

      if (!accessLookup.containsKey(compositeKey)) {
        accessLookup[compositeKey] = row;
      }
    }

    // 4. Sync dari leave_request (izin/sakit yang verified)
    List<Map<String, dynamic>> leaveResponse = [];
    try {
      final res = await _supabase
          .from('leave_request')
          .select('*')
          .inFilter('id_murid', listIdMurid)
          .eq('verif', true);
      leaveResponse = List<Map<String, dynamic>>.from(res);
    } catch (_) {}

    // Build leave lookup: compositeKey -> leave data (hanya untuk bulan ini)
    final Map<String, Map<String, dynamic>> leaveLookup = {};
    for (var req in leaveResponse) {
      final studentId = req['id_murid']?.toString();
      final startStr = req['tanggal_mulai']?.toString();
      final endStr = req['tanggal_selesai']?.toString();
      if (studentId == null || startStr == null || endStr == null) continue;
      try {
        final start = DateTime.parse(startStr);
        final end = DateTime.parse(endStr);
        for (int d = 0; d <= end.difference(start).inDays; d++) {
          final currentDate = start.add(Duration(days: d));
          // Filter hanya bulan ini
          if (currentDate.year != year || currentDate.month != month) continue;
          final dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
          final compositeKey = '${studentId}_$dateKey';
          leaveLookup[compositeKey] = req;
        }
      } catch (_) {}
    }

    // 5. Muat set id_tabel yang sudah di-override manual
    final Set<String> manualOverrideIds = await _getManualOverrideIds();

    // 6. Update setiap row rekap berdasarkan data access & leave
    final now = DateTime.now();
    final List<Future<dynamic>> updates = [];

    for (var entry in rekapLookup.entries) {
      final compositeKey = entry.key;
      final row = entry.value;
      final idTabel = row['id_tabel'].toString();
      final isLibur = row['ket_libur'] != null && row['ket_libur'].toString().isNotEmpty;

      // Skip hari libur
      if (isLibur) continue;

      // Skip row yang sudah di-override manual oleh guru (tersimpan di SharedPreferences atau berawalan MANUAL_ / Belum Absen di DB)
      final isManualDb = 
          (row['Null_data']?.toString() == 'Belum Absen') ||
          (row['ket_hadir']?.toString().startsWith('MANUAL_') ?? false) ||
          (row['ket_izin']?.toString().startsWith('MANUAL_') ?? false) ||
          (row['ket_sakit']?.toString().startsWith('MANUAL_') ?? false) ||
          (row['ket_alpha']?.toString().startsWith('MANUAL_') ?? false) ||
          (row['ket_libur']?.toString().startsWith('MANUAL_') ?? false);
      final isManualOverride = manualOverrideIds.contains(idTabel);
      if (isManualOverride || isManualDb) continue;

      final Map<String, dynamic> updateData = {
        'ket_hadir': null,
        'ket_izin': null,
        'ket_sakit': null,
        'ket_alpha': null,
      };

      // Prioritas: leave_request > access_bridge > alpha (jika tanggal sudah lewat)
      if (leaveLookup.containsKey(compositeKey)) {
        final leave = leaveLookup[compositeKey]!;
        final ketOpsi = (leave['ket_opsi'] ?? 'izin').toString().toLowerCase();
        if (ketOpsi == 'sakit') {
          updateData['ket_sakit'] = 'Sakit';
        } else {
          updateData['ket_izin'] = 'Izin';
        }
      } else if (accessLookup.containsKey(compositeKey)) {
        final access = accessLookup[compositeKey]!;
        final rawMasuk = access['data_masuk'];
        final formattedMasuk = _formatTime(rawMasuk) ?? '07:00';
        final timeParts = formattedMasuk.split(':');
        if (timeParts.length >= 2) {
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = int.tryParse(timeParts[1]) ?? 0;
          if (hour > 7 || (hour == 7 && minute > 0)) {
            updateData['ket_hadir'] = 'Terlambat';
          } else {
            updateData['ket_hadir'] = 'Hadir';
          }
        } else {
          updateData['ket_hadir'] = 'Hadir';
        }
      } else {
        // Cek apakah tanggal sudah lewat → Alpha
        try {
          final rowDate = DateTime.parse(row['date'].toString());
          if (rowDate.isBefore(DateTime(now.year, now.month, now.day))) {
            updateData['ket_alpha'] = 'Alpha';
          }
        } catch (_) {}
      }

      // Bandingkan dengan data lama di row. Jika sama persis, tidak perlu update ke database.
      if (row['ket_hadir'] == updateData['ket_hadir'] &&
          row['ket_izin'] == updateData['ket_izin'] &&
          row['ket_sakit'] == updateData['ket_sakit'] &&
          row['ket_alpha'] == updateData['ket_alpha']) {
        continue;
      }

      final futureUpdate = _supabase
          .from('absen')
          .update(updateData)
          .eq('id_tabel', idTabel);
      updates.add(futureUpdate);
    }

    // Jalankan update secara paralel dalam chunk berukuran 15
    const int chunkSize = 15;
    for (int i = 0; i < updates.length; i += chunkSize) {
      final end = (i + chunkSize > updates.length) ? updates.length : i + chunkSize;
      final chunk = updates.sublist(i, end);
      await Future.wait(chunk);
    }
  }

  // === HELPER: Manual Override via SharedPreferences ===

  static const String _manualOverrideKey = 'absen_manual_override_ids';

  Future<Set<String>> _getManualOverrideIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_manualOverrideKey) ?? [];
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _setManualOverride(String idTabel, bool isManual) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = (prefs.getStringList(_manualOverrideKey) ?? []).toSet();
      if (isManual) {
        current.add(idTabel);
      } else {
        current.remove(idTabel);
      }
      await prefs.setStringList(_manualOverrideKey, current.toList());
    } catch (_) {}
  }

  /// Ambil data rekap bulanan — query dari tabel absen difilter per murid.
  /// Menerima [listIdMurid] agar tidak campur data dengan kelas lain.
  Future<List<Map<String, dynamic>>> getMonthlyRekapData(
    String yearMonth,
    List<String> listIdMurid,
  ) async {
    if (listIdMurid.isEmpty) return [];

    final rekapKey = 'REKAP_$yearMonth';

    final response = await _supabase
        .from('absen')
        .select('*, murid:id_murid(*)')
        .eq('absensi_baru', rekapKey)
        .inFilter('id_murid', listIdMurid)
        .order('date', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  // === CUSTOM SESSIONS METHODS ===

  Future<void> createNewSession(String judul, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id_admin');
    if (userId == null) {
      throw Exception('Sesi tidak valid.');
    }

    // Check if session already exists
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final existing = await _supabase
        .from('absen')
        .select('id_tabel')
        .eq('user_id', userId)
        .eq('absensi_baru', judul)
        .eq('date', formattedDate)
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      throw Exception('Sesi absensi dengan judul dan tanggal tersebut sudah ada.');
    }

    // Fetch murid list
    final dbKelas = DbKelas();
    final students = await dbKelas.getMuridForGuru();
    if (students.isEmpty) {
      throw Exception('Tidak ada murid di kelas Anda.');
    }

    // Prepare insert rows
    final List<Map<String, dynamic>> rowsToInsert = students.map((murid) {
      return {
        'date': formattedDate,
        'user_id': userId,
        'id_murid': murid['id_tabel'],
        'absensi_baru': judul,
      };
    }).toList();

    // Insert into absen table
    await _supabase.from('absen').insert(rowsToInsert);
  }

  Future<List<Map<String, dynamic>>> getCustomSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id_admin');
    if (userId == null) {
      throw Exception('Sesi tidak valid.');
    }

    final response = await _supabase
        .from('absen')
        .select('absensi_baru, date')
        .eq('user_id', userId)
        .not('absensi_baru', 'is', null)
        .not('absensi_baru', 'like', 'REKAP_%');

    final List<Map<String, dynamic>> sessions = [];
    final Set<String> uniqueKeys = {};
    for (var item in response) {
      final judul = item['absensi_baru'] as String?;
      final date = item['date'] as String?;
      if (judul == null || date == null) continue;
      final key = '$judul|$date';
      if (!uniqueKeys.contains(key)) {
        uniqueKeys.add(key);
        sessions.add({
          'judul': judul,
          'date': date,
        });
      }
    }

    // sort by date descending
    sessions.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));
    return sessions;
  }

  Future<List<Map<String, dynamic>>> getSessionStudents(String judul, String date) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id_admin');
    if (userId == null) {
      throw Exception('Sesi tidak valid.');
    }

    final response = await _supabase
        .from('absen')
        .select('*, murid:id_murid(*)')
        .eq('user_id', userId)
        .eq('absensi_baru', judul)
        .eq('date', date);

    final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(response);
    list.sort((a, b) {
      final nameA = a['murid']?['nama']?.toString() ?? '';
      final nameB = b['murid']?['nama']?.toString() ?? '';
      return nameA.compareTo(nameB);
    });
    return list;
  }

  Future<void> updateStudentSessionStatus({
    required String idTabel,
    required String? selectedStatus, // 'hadir', 'izin', 'sakit', 'alpha', 'libur', or null
  }) async {
    try {
      // 1. Ambil data murid, tanggal, dan user_id dari baris absen
      final response = await _supabase
          .from('absen')
          .select('id_murid, date, user_id')
          .eq('id_tabel', idTabel)
          .maybeSingle();

      if (response != null) {
        final idMurid = response['id_murid']?.toString();
        final dateStr = response['date']?.toString();
        var userId = response['user_id']?.toString();

        if (idMurid != null && dateStr != null) {
          final startOfDay = '${dateStr}T00:00:00';
          final endOfDay = '${dateStr}T23:59:59';

          if (selectedStatus == 'hadir') {
            // Cek apakah data access_bridge sudah ada untuk hari ini
            final existingAccess = await _supabase
                .from('access_bridge')
                .select('id_tabel')
                .eq('id_murid', idMurid)
                .gte('created_at', startOfDay)
                .lte('created_at', endOfDay);

            if (existingAccess.isEmpty) {
              if (userId == null || userId.isEmpty) {
                userId = _supabase.auth.currentUser?.id ?? '';
              }
              await _supabase.from('access_bridge').insert({
                'id_murid': idMurid,
                'user_id': userId,
                'data_masuk': '${dateStr}T07:00:00',
                'created_at': '${dateStr}T07:00:00',
              });
            }
          } else {
            // Jika status manual diubah selain Hadir (seperti Sakit/Izin/Alpha/Libur/Belum Absen),
            // hapus record access_bridge hari ini agar tidak bentrok
            await _supabase
                .from('access_bridge')
                .delete()
                .eq('id_murid', idMurid)
                .gte('created_at', startOfDay)
                .lte('created_at', endOfDay);
          }
        }
      }
    } catch (_) {}

    final Map<String, dynamic> updateData = {
      'ket_hadir': selectedStatus == 'hadir' ? 'MANUAL_Hadir' : null,
      'ket_izin': selectedStatus == 'izin' ? 'MANUAL_Izin' : null,
      'ket_sakit': selectedStatus == 'sakit' ? 'MANUAL_Sakit' : null,
      'ket_alpha': selectedStatus == 'alpha' ? 'MANUAL_Alpha' : null,
      'ket_libur': selectedStatus == 'libur' ? 'MANUAL_Libur' : null,
      'Null_data': (selectedStatus == null || selectedStatus == 'belum_absen') ? 'Belum Absen' : null,
    };

    await _supabase
        .from('absen')
        .update(updateData)
        .eq('id_tabel', idTabel);

    // Tandai sebagai manual override di SharedPreferences.
    // selectedStatus == null (belum absen) → hapus flag agar auto-sync bisa berjalan lagi.
    await _setManualOverride(idTabel, selectedStatus != null);
  }


  Future<void> deleteSession(String judul, String date) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id_admin');
    if (userId == null) {
      throw Exception('Sesi tidak valid.');
    }

    await _supabase
        .from('absen')
        .delete()
        .eq('user_id', userId)
        .eq('absensi_baru', judul)
        .eq('date', date);
  }
}

