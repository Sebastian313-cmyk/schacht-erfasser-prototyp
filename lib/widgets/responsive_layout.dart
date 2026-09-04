import 'package:flutter/material.dart';

class ResponsiveLayout {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;

  static bool isMobile(BuildContext context) => 
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  static double contentPadding(BuildContext context) =>
      isMobile(context) ? 12 : 16;

  static double cardPadding(BuildContext context) =>
      isMobile(context) ? 12 : 16;

  static double buttonPadding(BuildContext context) =>
      isMobile(context) ? 12 : 16;

  static int gridColumns(BuildContext context, {int mobile = 1, int tablet = 2, int desktop = 3}) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  static EdgeInsets scaffoldPadding(BuildContext context) =>
      EdgeInsets.all(contentPadding(context));

  static double iconSize(BuildContext context) =>
      isMobile(context) ? 20 : 24;

  static TextStyle? buttonTextStyle(BuildContext context) =>
      isMobile(context) ? const TextStyle(fontSize: 14) : null;
}

class ResponsiveScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;

  const ResponsiveScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: ResponsiveLayout.scaffoldPadding(context),
          child: body,
        ),
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      drawer: drawer,
      endDrawer: endDrawer,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

class ResponsiveButtonBar extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment alignment;

  const ResponsiveButtonBar({
    super.key,
    required this.children,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveLayout.isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children.map((child) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: child,
        )).toList(),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: children,
    );
  }
}
