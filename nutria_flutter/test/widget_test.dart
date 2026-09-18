import 'package:flutter_test/flutter_test.dart';
import 'package:nutria_flutter/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const NutriaApp());
    expect(find.byType(NutriaApp), findsOneWidget);
  });
}
