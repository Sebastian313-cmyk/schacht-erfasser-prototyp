import 'dart:convert';

import 'package:erfasser_app/routes.dart';
import 'package:erfasser_app/screens/bericht_screen.dart';
import 'package:erfasser_app/services/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Bearbeiten öffnet den passenden Editor mit Datensatz-Sitzung', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues({
      'start_session_v1': jsonEncode({
        'evnr': 'E100',
        'strasse': 'Alte Strasse',
        'erfasser': 'Tester',
        'wetter': 'klar',
        'zeitIso': '2026-06-14T10:00:00.000',
        'temperatur': '20',
      }),
      'obj_E100_Neue Strasse_14_ES': jsonEncode({
        'typ': 'ES',
        'evnr': 'E100',
        'strasse': 'Neue Strasse',
        'erfasser': 'Tester',
        'wetter': 'klar',
        'zeitIso': '2026-06-14T10:00:00.000',
        'posNr': '14',
        'idNr': 'ES-14',
        'einsteigart': 'Leiter',
        'verfuegbarkeit': <String>[],
        'statusVorOrt': <String>[],
        'schaeden': <String>[],
        'abteilungen': <String>[],
        'mediaFotos': <String>[],
        'mediaVideos': <String>[],
        'mediaAudios': <String>[],
        'mediaPdfs': <String>[],
      }),
    });

    final observer = _RecordingNavigatorObserver();
    await tester.pumpWidget(
      MaterialApp(navigatorObservers: [observer], home: const BerichtScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.scrollUntilVisible(
      find.byTooltip('Bearbeiten'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byTooltip('Bearbeiten'), findsOneWidget);
    await tester.tap(find.byTooltip('Bearbeiten'));
    await tester.pump();
    expect(find.text('Objektart zum Bearbeiten auswählen'), findsOneWidget);
    expect(find.text('Einstiegschacht'), findsOneWidget);
    expect(find.text('Sickergrube / Versitzgrube'), findsOneWidget);
    expect(find.text('Straßensinkkasten'), findsOneWidget);
    expect(find.text('Lüftung'), findsOneWidget);
    expect(find.text('Schieberkappe'), findsOneWidget);
    expect(find.text('Kanal'), findsOneWidget);
    expect(find.text('Sonstiges'), findsOneWidget);

    await tester.tap(find.text('Einstiegschacht'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Einsteigschacht (ES)'), findsOneWidget);
    expect(observer.lastPushedName, Routes.es);
    final formFields = tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    );
    expect(formFields.any((field) => field.controller?.text == '14'), isTrue);

    final session = await SessionStore.load();
    expect(session?.evnr, 'E100');
    expect(session?.strasse, 'Neue Strasse');
  });

  testWidgets('Bearbeiten kann in ein anderes Modul wechseln', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues({
      'start_session_v1': jsonEncode({
        'evnr': 'E200',
        'strasse': 'Modulstrasse',
        'erfasser': 'Tester',
        'wetter': 'klar',
        'zeitIso': '2026-06-14T10:00:00.000',
      }),
      'obj_E200_Modulstrasse_3_ES': jsonEncode({
        'typ': 'ES',
        'evnr': 'E200',
        'strasse': 'Modulstrasse',
        'posNr': '3',
      }),
    });

    final observer = _RecordingNavigatorObserver();
    await tester.pumpWidget(
      MaterialApp(navigatorObservers: [observer], home: const BerichtScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.scrollUntilVisible(
      find.byTooltip('Bearbeiten'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Bearbeiten'));
    await tester.pump();
    await tester.tap(find.text('Sickergrube / Versitzgrube'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Grube (VG)'), findsOneWidget);
    expect(observer.lastPushedName, Routes.g);
  });

  testWidgets('Medienanzahl steht in Bemerkung und Umlaute bleiben erhalten', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues({
      'start_session_v1': jsonEncode({
        'evnr': 'E300',
        'strasse': 'Prüfstraße',
        'erfasser': 'Jürgen Müller',
        'wetter': 'bewölkt',
        'zeitIso': '2026-06-14T10:00:00.000',
      }),
      'obj_E300_Prüfstraße_1_DIV': jsonEncode({
        'typ': 'DIV',
        'evnr': 'E300',
        'strasse': 'Prüfstraße',
        'posNr': '1',
        'beschreibung': 'Übergabeschacht',
        'bemerkung': 'Öffnung überprüft',
        'mediaFotos': ['data:image/jpeg;base64,AQID'],
        'mediaVideos': <String>[],
        'mediaAudios': <String>[],
        'mediaPdfs': <String>[],
      }),
    });

    await tester.pumpWidget(const MaterialApp(home: BerichtScreen()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.text('Beschreibung: Übergabeschacht', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(
        'Bemerkung: Öffnung überprüft | Medien / Dateien: 1 Foto',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Beschreibung: Übergabeschacht | Medien / Dateien: 1 Foto',
        findRichText: true,
      ),
      findsNothing,
    );
  });
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  String? lastPushedName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    lastPushedName = route.settings.name;
  }
}
