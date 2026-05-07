import 'package:flutter_test/flutter_test.dart';

import 'package:teach_to_reach/main.dart';

void main() {
  testWidgets('app builds with firebase setup screen when not configured',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TeachToReachApp(firebaseReady: false));
    await tester.pump();

    expect(find.text('Firebase setup needed'), findsOneWidget);
  });

  testWidgets('app builds with phase 0 home when firebase is ready',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TeachToReachApp(firebaseReady: true));
    await tester.pump();

    expect(find.text('Teach to Reach'), findsOneWidget);
  });
}
