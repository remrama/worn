import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'screens/devices_screen.dart';
import 'screens/events_screen.dart';
import 'screens/history_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WornApp());
}

class WornApp extends StatelessWidget {
  const WornApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Worn',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final _screens = const [
    DevicesScreen(),
    EventsScreen(),
    HistoryScreen(),
  ];

  void _openGitHub() {
    launchUrl(Uri.parse('https://github.com/remrama/worn/issues'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.code),
            onPressed: _openGitHub,
            tooltip: 'GitHub',
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.watch), label: 'Devices'),
          NavigationDestination(icon: Icon(Icons.event), label: 'Events'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}
