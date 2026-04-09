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
    // There should be a text "录音" in the custom bottom navigation bar
    expect(find.text('录音'), findsOneWidget);
    
    // Verify that the custom bottom navigation bar is present (Row inside ClipRRect > BackdropFilter)
    expect(find.byType(ClipRRect), findsWidgets);
    
    // Verify all tab labels are present
    expect(find.text('存档'), findsOneWidget);
    expect(find.text('AI 聊天'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
