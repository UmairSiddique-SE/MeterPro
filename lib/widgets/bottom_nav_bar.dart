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
    const bg = Colors.white;
    const border = AppColors.primary;

    return Container(
      decoration: const BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 2)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A2563EB),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: currentIndex == 0 ? _items[0].activeIcon : _items[0].icon,
                  label: _items[0].label,
                  selected: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: currentIndex == 1 ? _items[1].activeIcon : _items[1].icon,
                  label: _items[1].label,
                  selected: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
              ),
              // Center gap for FloatingActionButton
              const SizedBox(width: 60),
              Expanded(
                child: _NavItem(
                  icon: currentIndex == 2 ? _items[2].activeIcon : _items[2].icon,
                  label: _items[2].label,
                  selected: currentIndex == 2,
                  onTap: () => onTap(2),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: currentIndex == 3 ? _items[3].activeIcon : _items[3].icon,
                  label: _items[3].label,
                  selected: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
              ),
            ],
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

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Colors.white;
    const activeBgColor = AppColors.primary; // Shining Blue Pill
    const inactiveColor = AppColors.navy700; // Rich navy for clear visibility

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: selected ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        builder: (context, animValue, child) {
          return Transform.translate(
            offset: Offset(0, -4.0 * animValue),
            child: child,
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: selected ? activeBgColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: activeBgColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? activeColor : inactiveColor,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? AppColors.primary : inactiveColor,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
