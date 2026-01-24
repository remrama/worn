import 'package:share_plus/share_plus.dart';

/// Stub implementation for web - file sharing not supported
Future<void> shareLogAsFile(String content) async {
  // On web, fall back to text sharing
  await Share.share(content, subject: 'Worn Log Export');
}

/// Returns true if file sharing is supported on this platform
bool get isFileShareSupported => false;
