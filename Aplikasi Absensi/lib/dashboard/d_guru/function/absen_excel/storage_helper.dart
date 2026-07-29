import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageHelper {
  /// Mendapatkan path direktori Download publik di Android atau Documents di iOS/desktop.
  static Future<String> getDownloadDirectoryPath() async {
    if (Platform.isAndroid) {
      const path = '/storage/emulated/0/Download';
      final dir = Directory(path);
      if (await dir.exists()) {
        return path;
      }
      // Fallback 1: external storage directory
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        return externalDir.path;
      }
      // Fallback 2: cache / temporary directory
      final tempDir = await getTemporaryDirectory();
      return tempDir.path;
    } else {
      final appDocDir = await getApplicationDocumentsDirectory();
      return appDocDir.path;
    }
  }

  /// Mendapatkan path file unik dengan menambahkan suffix (1), (2), dst. jika file sudah ada.
  static String getUniqueFilePath(String dirPath, String baseName, String extension) {
    final cleanExt = extension.startsWith('.') ? extension.substring(1) : extension;
    String targetPath = '$dirPath/$baseName.$cleanExt';
    File file = File(targetPath);
    if (!file.existsSync()) {
      return targetPath;
    }

    int index = 1;
    while (true) {
      targetPath = '$dirPath/$baseName ($index).$cleanExt';
      file = File(targetPath);
      if (!file.existsSync()) {
        return targetPath;
      }
      index++;
    }
  }
}

