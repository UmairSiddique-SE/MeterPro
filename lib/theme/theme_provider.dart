import 'package:flutter/material.dart';

/// Global theme state — call ThemeProvider.of(context).toggle() to switch modes.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light; // default: light

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  void toggle() {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setDark() {
    if (!isDark) {
      _mode = ThemeMode.dark;
      notifyListeners();
    }
  }

  void setLight() {
    if (isDark) {
      _mode = ThemeMode.light;
      notifyListeners();
    }
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
