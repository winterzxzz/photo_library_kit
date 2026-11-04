import 'package:flutter_test/flutter_test.dart';
import 'package:photo_library_kit_example/main.dart';

void main() {
  testWidgets('home lists the demos', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('WeChat picker'), findsOneWidget);
    expect(find.text('Instagram new post'), findsOneWidget);
    expect(find.text('API gallery'), findsOneWidget);
  });
}
