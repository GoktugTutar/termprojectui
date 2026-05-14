import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:termprojectui/main.dart';

void main() {
  testWidgets('app splash renders', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
