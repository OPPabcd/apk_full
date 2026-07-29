import 'package:intl/intl.dart';

class TimeHelper {
  static DateTime now() {
    return DateTime.now();
  }

  static String getTime() {
    return DateFormat('HH:mm').format(DateTime.now());
  }

  static String getDate() {
    return DateFormat('dd-MM-yyyy').format(DateTime.now());
  }

  static String getDateTime() {
    return DateFormat('dd MMM yyyy, HH:mm:ss').format(DateTime.now());
  }
}