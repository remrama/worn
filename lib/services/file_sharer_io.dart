import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// IO implementation for mobile/desktop - creates temp file and shares
Future<void> shareLogAsFile(String content) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/worn_log.txt');
  await file.writeAsString(content);
  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'Worn Log Export',
  );
}

/// Returns true if file sharing is supported on this platform
bool get isFileShareSupported => true;
