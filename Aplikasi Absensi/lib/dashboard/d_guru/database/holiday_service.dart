import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HolidayService {
  static const String _cacheKey = 'holiday_cache_2026';
  
  // Set of formatted dates "yyyy-MM-dd"
  static Set<String> _holidays = {};

  // Fallback major 2026 Indonesian holidays
  static const List<String> _fallbackHolidays = [
    '2026-01-01', // Tahun Baru Masehi
    '2026-01-27', // Isra Mikraj Nabi Muhammad SAW
    '2026-02-17', // Tahun Baru Imlek
    '2026-03-20', // Hari Suci Nyepi
    '2026-04-03', // Wafat Yesus Kristus
    '2026-04-05', // Kebangkitan Yesus Kristus
    '2026-05-01', // Hari Buruh Internasional
    '2026-05-14', // Kenaikan Yesus Kristus
    '2026-05-27', // Hari Raya Idul Adha
    '2026-06-01', // Hari Lahir Pancasila
    '2026-06-16', // Tahun Baru Islam
    '2026-08-17', // Hari Kemerdekaan RI
    '2026-08-25', // Maulid Nabi Muhammad SAW
    '2026-12-25', // Hari Raya Natal
  ];

  /// Initialize the holiday service. Loads cached values if available,
  /// otherwise uses fallback values, and tries to fetch the latest values from API.
  static Future<void> init() async {
    // 1. Try to load from local cache first
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        _holidays = decoded.cast<String>().toSet();
      }
    } catch (_) {
      // Ignore cache load error
    }

    // If cache is empty, load fallback initially
    if (_holidays.isEmpty) {
      _holidays = _fallbackHolidays.toSet();
    }

    // 2. Fetch from API with a 5-second timeout
    try {
      final apiUrl = dotenv.env['HOLIDAY_API_URL'];
      if (apiUrl != null && apiUrl.isNotEmpty) {
        final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final Set<String> fetchedHolidays = {};
          for (var item in data) {
            if (item is Map && item.containsKey('date')) {
              fetchedHolidays.add(item['date'].toString());
            }
          }
          if (fetchedHolidays.isNotEmpty) {
            _holidays = fetchedHolidays;
            // Save to cache
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_cacheKey, jsonEncode(_holidays.toList()));
          }
        }
      }
    } catch (_) {
      // Failed to fetch or parse, fallback/cache will be used
    }
  }

  /// Check if a date is a public holiday
  static bool isHoliday(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return _holidays.contains(dateStr);
  }
}
