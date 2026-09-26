import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class MWBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const MWBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    (icon: Icons.home_rounded, activeIcon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, label: 'Usage'),
    (icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'Bills'),
    (icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'Services'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_items.length, (i) {
              final selected = i == currentIndex;
              final item = _items[i];
              // Skip center gap (for FAB)
              if (i == 2) {
                return Expanded(
                  child: Row(
                    children: [
                      // Gap for FAB
                      const SizedBox(width: 32),
                      Expanded(child: _NavItem(
                        icon: selected ? item.activeIcon : item.icon,
                        label: item.label,
                        selected: selected,
                        onTap: () => onTap(i),
                        isDark: isDark,
                      )),
                    ],
                  ),
                );
              }
              return Expanded(
                child: _NavItem(
                  icon: selected ? item.activeIcon : item.icon,
                  label: item.label,
                  selected: selected,
                  onTap: () => onTap(i),
                  isDark: isDark,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.primary;
    final inactiveColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected ? activeColor : inactiveColor,
              ),
            ),
          ),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? activeColor : inactiveColor,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
