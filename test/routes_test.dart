import 'package:erfasser_app/routes.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Routes.map contains all expected app routes', () {
    final map = Routes.map;

    expect(map[Routes.start], isA<WidgetBuilder>());
    expect(map[Routes.bericht], isA<WidgetBuilder>());
    expect(map[Routes.es], isA<WidgetBuilder>());
    expect(map[Routes.ssk], isA<WidgetBuilder>());
    expect(map[Routes.l], isA<WidgetBuilder>());
    expect(map[Routes.g], isA<WidgetBuilder>());
    expect(map[Routes.sk], isA<WidgetBuilder>());
    expect(map[Routes.kanal], isA<WidgetBuilder>());
    expect(map[Routes.div], isA<WidgetBuilder>());
    expect(map[Routes.legende], isA<WidgetBuilder>());
  });
}
