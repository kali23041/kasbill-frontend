import 'package:flutter/material.dart';

import '../admin_theme.dart';

class AdminBottomNavbar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const AdminBottomNavbar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  static const _items = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Home'),
    (Icons.people_outline, Icons.people, 'Users'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AdminColors.panel,
        border: Border(
          top: BorderSide(color: AdminColors.hairline, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final selected = selectedIndex == index;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onItemTapped(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? item.$2 : item.$1,
                        size: 22,
                        color: selected ? AdminColors.gold : AdminColors.muted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$3,
                        style: AdminTheme.label(
                          size: 10,
                          weight: selected ? FontWeight.w700 : FontWeight.w500,
                          color:
                              selected ? AdminColors.gold : AdminColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
