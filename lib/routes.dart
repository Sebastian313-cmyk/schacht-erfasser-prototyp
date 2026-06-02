
import 'screens/sinkkasten_screen.dart';
import 'screens/schieber_screen.dart';
import 'screens/lueftung_screen.dart';
import 'screens/gruben_screen.dart';
import 'screens/kanal_screen.dart';
import 'package:flutter/material.dart';

import 'screens/start_screen.dart';
import 'screens/bericht_screen.dart';
import 'screens/einsteig_screen.dart';
import 'screens/sonstiges_screen.dart';
import 'screens/legende_screen.dart';

class Routes {
  static const legende = '/legende';
  static const div = '/div';

  static const ssk = '/ssk';
  static const sk = '/schieber';
  static const kanal = '/kanal';
  static const l = '/lueftung';
  static const g = '/gruben';
  static const start = '/';
  static const bericht = '/bericht';
  static const es = '/es';

  static Map<String, WidgetBuilder> get map => {
        start: (_) => const StartBildschirm(),
        bericht: (_) => const BerichtScreen(),
        es: (_) => const EinsteigScreen(),
        ssk: (_) => const SinkkastenScreen(),
        l: (_) => const LueftungScreen(),
        g: (_) => const GrubenScreen(),
        sk: (_) => const SchieberScreen(),
        kanal: (_) => const KanalScreen(),
  div: (_) => const SonstigesScreen(),
  legende: (_) => const LegendeScreen(),
    };
}
