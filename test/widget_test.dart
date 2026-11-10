import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_list/main.dart';

void main() {
  testWidgets('App renders correctly smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ToDoListApp());
    expect(find.text('Tasks'), findsOneWidget);
  });
}
