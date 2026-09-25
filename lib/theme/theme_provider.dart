import 'package:flutter/material.dart';

/// Global theme state — call ThemeProvider.of(context).toggle() to switch modes.
class ThemeProvider extends ChangeNotifier {
  ThemeMode get mode => ThemeMode.light;
  bool get isDark => false;

  void toggle() {
    // Light mode only
    notifyListeners();
  }

  void setDark() {
    // Light mode only
  }

  void setLight() {
    // Light mode only
  }

  static ThemeProvider of(BuildContext context) {
    return context
        .findAncestorStateOfType<_ThemeProviderWidgetState>()!
        .provider;
  }
}

class ThemeProviderWidget extends StatefulWidget {
  final Widget child;
  const ThemeProviderWidget({super.key, required this.child});

  @override
  State<ThemeProviderWidget> createState() => _ThemeProviderWidgetState();
}

class _ThemeProviderWidgetState extends State<ThemeProviderWidget> {
  final provider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    provider.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
