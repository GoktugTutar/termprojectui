// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:termprojectui/main.dart';

void main() {
  testWidgets('Single page renders expected text', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SinglePageApp());

    expect(find.text('Ana Sayfa'), findsOneWidget);
    expect(find.text('Tek sayfalik basit Flutter uygulamasi'), findsOneWidget);
  });
}
