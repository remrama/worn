import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Future<void> _copyToClipboard() async {
    final content = await LogService.instance.getLogContent();
    await Clipboard.setData(ClipboardData(text: content));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy log to clipboard',
            onPressed: _copyToClipboard,
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
