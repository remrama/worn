import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/file_sharer.dart';
import '../services/log_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<String> _lines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lines = await LogService.instance.getLogLines();
    setState(() {
      _lines = lines;
      _loading = false;
    });
  }

  Future<void> _shareLogAsText() async {
    try {
      final content = await LogService.instance.getLogContent();
      await Share.share(
        content,
        subject: 'Worn Log Export',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share log: $e')),
        );
      }
    }
  }

  Future<void> _shareLogAsFile() async {
    try {
      final content = await LogService.instance.getLogContent();
      await shareLogAsFile(content);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share log: $e')),
        );
      }
    }
  }

  Future<void> _wipeAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wipe All Data'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WARNING',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This will permanently delete ALL data including:\n\n'
              '• All devices\n'
              '• All active events\n'
              '• Complete log history\n'
              '• Tracking state\n\n'
              'This action CANNOT be undone.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE ALL DATA'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('worn_devices');
      await prefs.remove('worn_events');
      await prefs.remove('worn_log');
      await prefs.remove('worn_tracking');

      if (mounted) {
        setState(() {
          _lines = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data wiped successfully')),
        );
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restart Recommended'),
            content: const Text(
              'All data has been deleted.\n\n'
              'To ensure any cached information is fully cleared, '
              'it is recommended to restart the app.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.share),
            tooltip: 'Share log',
            onSelected: (value) {
              if (value == 'text') {
                _shareLogAsText();
              } else if (value == 'file') {
                _shareLogAsFile();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'text',
                child: Row(
                  children: [
                    Icon(Icons.text_fields),
                    SizedBox(width: 8),
                    Text('Share as text'),
                  ],
                ),
              ),
              if (isFileShareSupported)
                const PopupMenuItem(
                  value: 'file',
                  child: Row(
                    children: [
                      Icon(Icons.insert_drive_file),
                      SizedBox(width: 8),
                      Text('Share as file'),
                    ],
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'wipe') {
                _wipeAllData();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'wipe',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Wipe All Data', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lines.isEmpty
              ? const Center(child: Text('No log entries yet.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _lines.length,
                    itemBuilder: (ctx, i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Text(
                          _lines[i],
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
