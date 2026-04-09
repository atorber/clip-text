import 'package:flutter/material.dart';
import 'dart:ui';
import 'pages/record_page.dart';
import 'pages/recordings_list_page.dart';
import 'pages/text_library_page.dart';
import 'pages/settings_page.dart';
import 'utils/colors.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sonic Editorial',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          error: AppColors.error,
          onPrimary: AppColors.onPrimary,
          onSecondary: AppColors.onSecondary,
          onSurface: AppColors.onSurface,
          onError: AppColors.onError,
        ),
        scaffoldBackgroundColor: AppColors.surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: AppColors.primary),
          titleTextStyle: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        fontFamily: 'Inter',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800),
          displayMedium: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800),
          displaySmall: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800),
          headlineLarge: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700),
          headlineSmall: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700),
          titleLarge: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
          titleSmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400),
          bodySmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400),
          labelLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
          labelMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
          labelSmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
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
    TextLibraryPage(), // 存档 (Archive)
    RecordingsListPage(), // AI Chat / Recordings list replacement? We will keep this as RecordingsList for now, or maybe AI Chat
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Allow body to flow under the bottom nav bar
      body: _pages[currentIndex],
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.white.withAlpha(204),
            padding: const EdgeInsets.only(top: 12, bottom: 24, left: 16, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.mic, '录音'),
                _buildNavItem(1, Icons.inventory_2, '存档'),
                _buildNavItem(2, Icons.auto_awesome, 'AI 聊天'),
                _buildNavItem(3, Icons.settings, '设置'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          currentIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: isSelected
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 4)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant.withAlpha(153),
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant.withAlpha(153),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}