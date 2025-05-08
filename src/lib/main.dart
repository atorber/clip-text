import 'package:flutter/material.dart';
import 'pages/record_page.dart';
import 'pages/recordings_list_page.dart';
import 'pages/text_library_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '系统音频录制工具',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      home: MainTabPage(),
    );
  }
}

class MainTabPage extends StatefulWidget {
  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _currentIndex = 0;
  final _pages = [
    RecordPage(),
    RecordingsListPage(),
    TextLibraryPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: '录制'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '录音列表'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: '文本库'),
        ],
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}