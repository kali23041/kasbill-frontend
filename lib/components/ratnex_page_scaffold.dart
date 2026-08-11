import 'package:flutter/material.dart';
import '../theme/ratnex_theme.dart';

/// Shared chrome matching the home dashboard look.
class RatnexPageScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget body;
  final Future<void> Function()? onRefresh;
  final bool showBack;

  const RatnexPageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    this.trailing,
    this.onRefresh,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(showBack ? 4 : 14, 10, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showBack)
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    color: RatnexColors.ink,
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: RatnexTheme.brand(size: 34)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: RatnexTheme.label(size: 12)),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
          sliver: SliverToBoxAdapter(child: body),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: RatnexColors.surface,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            left: -40,
            right: -40,
            height: 260,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 0.95,
                    colors: [
                      RatnexColors.goldSoft.withValues(alpha: 0.55),
                      RatnexColors.surface.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: onRefresh != null
                ? RefreshIndicator(
                    color: RatnexColors.gold,
                    onRefresh: onRefresh!,
                    child: content,
                  )
                : content,
          ),
        ],
      ),
    );
  }
}

class RatnexSectionLabel extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const RatnexSectionLabel({
    super.key,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          text,
          style: RatnexTheme.label(
            size: 11,
            weight: FontWeight.w600,
            color: RatnexColors.muted,
          ).copyWith(letterSpacing: 0.4),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: RatnexTheme.label(
                size: 12,
                weight: FontWeight.w600,
                color: RatnexColors.gold,
              ),
            ),
          ),
      ],
    );
  }
}

class RatnexHeaderChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;

  const RatnexHeaderChip({
    super.key,
    required this.label,
    this.color = RatnexColors.up,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 5),
            ] else ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: RatnexTheme.label(
                size: 11,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RatnexPanel extends StatelessWidget {
  final Widget child;

  const RatnexPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: RatnexColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RatnexColors.hairline),
      ),
      child: child,
    );
  }
}

class RatnexPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const RatnexPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RatnexColors.ink,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          height: 48,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: RatnexColors.rateAccent),
              const SizedBox(width: 8),
              Text(
                label,
                style: RatnexTheme.label(
                  size: 13,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
