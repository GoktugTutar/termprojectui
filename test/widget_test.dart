import 'package:flutter_test/flutter_test.dart';
import 'package:termprojectui/main.dart';

void main() {
  testWidgets('app splash renders', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    expect(find.text('Ders Takip'), findsOneWidget);
  });
}
