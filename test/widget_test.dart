import 'package:flutter_test/flutter_test.dart';

import 'package:fishpond_edge/main.dart';

void main() {
  testWidgets('app renders pond classifier screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Pond Health AI'), findsOneWidget);
    expect(find.text('Select Image'), findsOneWidget);
  });
}
