import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/main.dart';

void main() {
  testWidgets('App launches and shows setup screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: WorkoutApp()));
    expect(find.text('セット設定'), findsOneWidget);
  });
}
