import 'package:flutter/material.dart';
import 'package:kaji_tower/screens/chore_logging_screen.dart';
import 'package:kaji_tower/screens/apartment_screen.dart';
import 'package:kaji_tower/screens/settings_screen.dart';

void main() {
  runApp(const KajiTowerApp());
}

class KajiTowerApp extends StatelessWidget {
  const KajiTowerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '家事タワー',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const ChoreLoggingScreen(),
    const ApartmentScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('家事タワー'),
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: '家事記録',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apartment),
            label: 'マンション',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}