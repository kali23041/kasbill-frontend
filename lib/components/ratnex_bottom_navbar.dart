import 'package:flutter/material.dart';
import '../theme/ratnex_theme.dart';

class RatnexBottomNavbar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const RatnexBottomNavbar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  static const _items = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Bills'),
    (Icons.account_balance_outlined, Icons.account_balance, 'Girvi'),
    (Icons.inventory_2_outlined, Icons.inventory_2, 'Stock'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RatnexColors.panel,
        border: Border(
          top: BorderSide(color: RatnexColors.hairline, width: 1),
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? item.$2 : item.$1,
                          size: 22,
                          color: selected
                              ? RatnexColors.ink
                              : RatnexColors.muted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.$3,
                          style: RatnexTheme.label(
                            size: 10,
                            weight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? RatnexColors.ink
                                : RatnexColors.muted,
                          ),
                        ),
                      ],
                    ),
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
