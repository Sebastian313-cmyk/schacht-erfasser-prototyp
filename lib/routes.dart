import 'package:flutter/material.dart';

import 'screens/start_screen.dart';
import 'screens/bericht_screen.dart' deferred as bericht_screen;
import 'screens/einsteig_screen.dart' deferred as einsteig_screen;
import 'screens/gruben_screen.dart' deferred as gruben_screen;
import 'screens/kanal_screen.dart' deferred as kanal_screen;
import 'screens/legende_screen.dart' deferred as legende_screen;
import 'screens/lueftung_screen.dart' deferred as lueftung_screen;
import 'screens/schieber_screen.dart' deferred as schieber_screen;
import 'screens/schnittstellen_screen.dart' deferred as schnittstellen_screen;
import 'screens/sinkkasten_screen.dart' deferred as sinkkasten_screen;
import 'screens/sonstiges_screen.dart' deferred as sonstiges_screen;

class Routes {
  static const legende = '/legende';
  static const schnittstellen = '/schnittstellen';
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
    bericht: (_) => _deferredRoute(
      'Bericht',
      bericht_screen.loadLibrary,
      () => bericht_screen.BerichtScreen(),
    ),
    es: (_) => _deferredRoute(
      'Einsteigschacht',
      einsteig_screen.loadLibrary,
      () => einsteig_screen.EinsteigScreen(),
    ),
    ssk: (_) => _deferredRoute(
      'Straßensinkkasten',
      sinkkasten_screen.loadLibrary,
      () => sinkkasten_screen.SinkkastenScreen(),
    ),
    l: (_) => _deferredRoute(
      'Lüftung',
      lueftung_screen.loadLibrary,
      () => lueftung_screen.LueftungScreen(),
    ),
    g: (_) => _deferredRoute(
      'Gruben',
      gruben_screen.loadLibrary,
      () => gruben_screen.GrubenScreen(),
    ),
    sk: (_) => _deferredRoute(
      'Schieber',
      schieber_screen.loadLibrary,
      () => schieber_screen.SchieberScreen(),
    ),
    kanal: (_) => _deferredRoute(
      'Kanal',
      kanal_screen.loadLibrary,
      () => kanal_screen.KanalScreen(),
    ),
    div: (_) => _deferredRoute(
      'Sonstiges',
      sonstiges_screen.loadLibrary,
      () => sonstiges_screen.SonstigesScreen(),
    ),
    legende: (_) => _deferredRoute(
      'Legende',
      legende_screen.loadLibrary,
      () => legende_screen.LegendeScreen(),
    ),
    schnittstellen: (_) => _deferredRoute(
      'Schnittstellen',
      schnittstellen_screen.loadLibrary,
      () => schnittstellen_screen.SchnittstellenScreen(),
    ),
  };

  static Widget _deferredRoute(
    String title,
    Future<void> Function() loadLibrary,
    Widget Function() builder,
  ) {
    return _DeferredRoutePage(
      title: title,
      loadLibrary: loadLibrary,
      builder: builder,
    );
  }
}

class _DeferredRoutePage extends StatefulWidget {
  final String title;
  final Future<void> Function() loadLibrary;
  final Widget Function() builder;

  const _DeferredRoutePage({
    required this.title,
    required this.loadLibrary,
    required this.builder,
  });

  @override
  State<_DeferredRoutePage> createState() => _DeferredRoutePageState();
}

class _DeferredRoutePageState extends State<_DeferredRoutePage> {
  late final Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.loadLibrary();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.title)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Seite konnte nicht geladen werden: ${snapshot.error}',
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.done) {
          return widget.builder();
        }

        return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
