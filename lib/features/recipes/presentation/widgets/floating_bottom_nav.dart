import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Destination model for the floating bottom bar.
class FloatingNavItem {
  const FloatingNavItem({
    required this.label,
    required this.icon,
    this.filledIcon,
  });

  final String label;
  final IconData icon;
  final IconData? filledIcon;
}

class FloatingBottomNav extends StatelessWidget {
  const FloatingBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<FloatingNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff11130d),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(
            items.length,
            (index) => _NavItem(
              label: items[index].label,
              icon: index == currentIndex
                  ? (items[index].filledIcon ?? items[index].icon)
                  : items[index].icon,
              selected: index == currentIndex,
              onTap: () => onTap(index),
            ),
          ),
        ),
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.selected,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    selected: selected,
    button: true,
    child: InkResponse(
      onTap: onTap,
      radius: 28,
      child: Tooltip(
        message: label,
        triggerMode: TooltipTriggerMode.longPress,
        child: SizedBox.square(
          key: Key('nav-$label'),
          dimension: 46,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? AppColors.lime : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: selected ? AppColors.olive : AppColors.white,
            ),
          ),
        ),
      ),
    ),
  );
}
