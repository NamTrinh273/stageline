import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Creates an in-memory [XFile] for Web Share API / browser file download.
Future<XFile> createExportXFile({
  required String fileName,
  required List<int> bytes,
}) async {
  return XFile.fromData(
    Uint8List.fromList(bytes),
    name: fileName,
    mimeType: 'application/json',
  );
}

/// Web file pickers always supply in-memory bytes; local path reads are unavailable.
Future<List<int>?> readFallbackFileBytes(String? path) async => null;
