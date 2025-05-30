import 'package:flutter/material.dart';
import 'pages/record_page.dart';
import 'pages/recordings_list_page.dart';
import 'pages/text_library_page.dart';
import 'pages/settings_page.dart';

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
  State<MainTabPage> createState() => MainTabPageState();
}

class MainTabPageState extends State<MainTabPage> {
  int currentIndex = 0;
  final _pages = [
    RecordPage(),
    RecordingsListPage(),
    TextLibraryPage(),
    SettingsPage(),
  ];
  final _titles = ['录制', '录音列表', '文本库', '设置'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[currentIndex])),
      body: SafeArea(child: _pages[currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
        unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
        selectedIconTheme: IconThemeData(size: 24),
        unselectedIconTheme: IconThemeData(size: 24),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: '录制'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '录音列表'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: '文本库'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
        onTap: (index) => setState(() => currentIndex = index),
      ),
    );
  }
}