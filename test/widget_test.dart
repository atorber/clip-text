// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clip_text/main.dart';

void main() {
  testWidgets('App starts and shows main tabs', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // Verify that the app starts with the record page
    // There should be exactly 2 "录制" texts: one in AppBar title and one in BottomNavigationBar
    expect(find.text('录制'), findsNWidgets(2));
    
    // Verify that bottom navigation bar is present
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    
    // Verify all tab labels are present
    expect(find.text('录音列表'), findsOneWidget);
    expect(find.text('文本库'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    
    // Verify that AppBar is present with correct title
    expect(find.byType(AppBar), findsOneWidget);
  });
}
