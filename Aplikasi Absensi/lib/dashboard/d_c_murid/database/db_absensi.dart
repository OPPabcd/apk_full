import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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

      // Query absen tanpa join access_bridge (tidak dipakai lagi)
      final response = await _supabase
          .from('absen')
          .select('*, leave_request:id_izin(*), output_alat:id_output_alat(*), murid:id_murid(*), pengumuman:id_pengumuman(*)')
          .eq('id_murid', idMurid)
          .order('date', ascending: false);

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

      final Map<String, dynamic> studentMuridMap = {
        'id_tabel': idMurid,
        'user_id': userId,
        'nis': studentNis,
        'nama': studentName,
      };

      return _mergeAbsenData(response, idMurid, studentMuridMap, consolidatedLeave);
    } catch (e) {
      throw Exception('Gagal memuat data absensi: $e');
    }
  }

  List<Map<String, dynamic>> _mergeAbsenData(
      List<dynamic> absenResponse,
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

        // Ambil jam masuk dari output_alat.created_at
        final outputAlat = row['output_alat'];
        if (outputAlat != null && outputAlat['created_at'] != null) {
          final formattedMasuk = _formatTime(outputAlat['created_at']);
          if (formattedMasuk != null) {
            row['masuk'] = formattedMasuk;
          }
        }

        // Inject leave_request jika belum ada dari FK
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

    // Tambahkan record izin yang tidak punya row absen
    consolidatedLeave.forEach((dateKey, leave) {
      if (!processedDates.contains(dateKey)) {
        processedDates.add(dateKey);
        mergedList.add({
          'date': dateKey,
          'id_murid': idMurid,
          'masuk': null,
          'keluar': null,
          'output_alat': null,
          'murid': studentMuridMap,
          'leave_request': {
            'id_tabel': leave['id_tabel'],
            'ket_opsi': leave['ket_opsi'],
            'verif': true,
          },
          'pengumuman': null,
        });
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

    final parsed = DateTime.tryParse(str);
    if (parsed != null) {
      return DateFormat('HH:mm').format(parsed.toLocal());
    }

    final parts = str.split(':');
    if (parts.length >= 2) {
      var hour = parts[0];
      if (hour.contains('T')) hour = hour.split('T').last;
      hour = hour.padLeft(2, '0');
      var minute = parts[1];
      if (minute.length > 2) minute = minute.substring(0, 2);
      minute = minute.padLeft(2, '0');
      return '$hour:$minute';
    }
    return str;
  }

  static String getStatus(Map<String, dynamic> row) {
    // 0. Manual override (prioritas tertinggi)
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

    // 1. Izin dan Sakit dari leave_request yang terverifikasi
    if (row['leave_request'] != null && row['leave_request']['verif'] == true) {
      final ketOpsi = (row['leave_request']['ket_opsi'] ?? '').toString().toLowerCase();
      if (ketOpsi == 'sakit') return 'Sakit';
      if (ketOpsi == 'izin') return 'Izin';
      final ket = (row['leave_request']['keterangan'] ?? '').toString().toLowerCase();
      if (ket.contains('sakit')) return 'Sakit';
      return 'Izin';
    }

    if (row['ket_sakit'] != null && row['ket_sakit'].toString().isNotEmpty) return 'Sakit';
    if (row['ket_izin'] != null && row['ket_izin'].toString().isNotEmpty) return 'Izin';

    // 2. Libur dari hari Minggu / pengumuman / tabel absen
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

    if (isSundayOrHoliday || isPengumumanLibur) return 'Libur';
    if (row['ket_libur'] != null && row['ket_libur'].toString().isNotEmpty) return 'Libur';

    // 3. Hadir / Terlambat dari output_alat.created_at
    final outputAlat = row['output_alat'];
    if (outputAlat != null && outputAlat['created_at'] != null) {
      final formattedMasuk = _formatTime(outputAlat['created_at']) ?? '07:00';
      if (formattedMasuk.trim().isNotEmpty) {
        final parts = formattedMasuk.split(':');
        if (parts.length >= 2) {
          final hour = int.tryParse(parts[0]) ?? 0;
          final minute = int.tryParse(parts[1]) ?? 0;
          if (hour > 7 || (hour == 7 && minute > 0)) return 'Terlambat';
        }
        return 'Hadir';
      }
    }

    // Fallback dari kolom absen langsung
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
}
