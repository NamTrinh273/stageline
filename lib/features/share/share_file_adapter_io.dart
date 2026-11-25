import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [bytes] into a temporary `.concert` file for native share sheets.
Future<XFile> createExportXFile({
  required String fileName,
  required List<int> bytes,
}) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return XFile(file.path, name: fileName);
}

/// Reads bytes from a native file system [path] as a fallback when picker bytes are absent.
Future<List<int>?> readFallbackFileBytes(String? path) async {
  if (path == null || path.isEmpty) return null;
  return File(path).readAsBytes();
}
