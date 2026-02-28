import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Native implementation of file download.
///
/// Saves [content] as a file named [filename] to the platform's downloads
/// directory (Windows/macOS/Linux) or the app's documents directory
/// (Android/iOS) using `path_provider` + `dart:io`.
///
/// Returns the full path of the saved file.
Future<void> downloadFile(String content, String filename) async {
  // Try downloads directory first (available on desktop),
  // fall back to documents directory (works on all native platforms).
  final dir =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$filename');
  await file.writeAsString(content);
}
