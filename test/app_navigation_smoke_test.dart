import 'package:erfasser_app/main.dart';
import 'package:erfasser_app/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App starts on Startbildschirm', (tester) async {
    await tester.pumpWidget(const ErfasserApp(disableUpdateChecker: true));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Erfasserdaten'), findsOneWidget);
  });

  testWidgets('Named route navigation reaches Gruben and ES screens', (tester) async {
    await tester.pumpWidget(const ErfasserApp(disableUpdateChecker: true));
    await tester.pump(const Duration(seconds: 1));

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);

    navigator.pushNamed(Routes.g);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Grube (VS)'), findsOneWidget);

    navigator.pushNamed(Routes.es);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Einsteigschacht (ES)'), findsOneWidget);
  });
}
