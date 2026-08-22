import 'package:flutter/material.dart';

import '../theme/ratnex_theme.dart';
import '../utils/haptics.dart';

/// Search box used by every list screen.
class RatnexSearchField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onScan;
  final FocusNode? focusNode;

  const RatnexSearchField({
    super.key,
    required this.hint,
    required this.controller,
    this.onChanged,
    this.onScan,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: RatnexColors.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RatnexColors.hairline),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: RatnexColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  textInputAction: TextInputAction.search,
                  style: RatnexTheme.label(
                    size: 13,
                    color: RatnexColors.ink,
                    weight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: RatnexTheme.label(size: 13),
                  ),
                ),
              ),
              if (value.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    controller.clear();
                    onChanged?.call('');
                    Haptics.tap();
                  },
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: RatnexColors.muted,
                  ),
                ),
              if (onScan != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Haptics.tap();
                    onScan!();
                  },
                  child: Icon(
                    Icons.qr_code_scanner,
                    size: 19,
                    color: RatnexColors.gold,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Horizontally scrolling filter row.
class RatnexFilterChips extends StatelessWidget {
  final List<({String value, String label, int? count})> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const RatnexFilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final o = options[i];
          final active = o.value == selected;
          return GestureDetector(
            onTap: () {
              Haptics.tap();
              onSelected(o.value);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? RatnexColors.ink : RatnexColors.panel,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: active ? RatnexColors.ink : RatnexColors.hairline,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    o.label,
                    style: RatnexTheme.label(
                      size: 12,
                      weight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? Colors.white : RatnexColors.muted,
                    ),
                  ),
                  if (o.count != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white.withValues(alpha: 0.18)
                            : RatnexColors.goldSoft,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '${o.count}',
                        style: RatnexTheme.label(
                          size: 10,
                          weight: FontWeight.w700,
                          color: active ? Colors.white : RatnexColors.gold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Empty state with a call to action, instead of a blank screen.
class RatnexEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  const RatnexEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: RatnexColors.goldSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 27, color: RatnexColors.gold),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: RatnexTheme.label(
              size: 15,
              weight: FontWeight.w700,
              color: RatnexColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: RatnexTheme.label(size: 12.5),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Haptics.tap();
                onAction!();
              },
              style: FilledButton.styleFrom(
                backgroundColor: RatnexColors.ink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: Text(
                actionLabel!,
                style: RatnexTheme.label(
                  size: 13,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shimmering placeholder shown while a stream delivers its first snapshot.
class RatnexSkeleton extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;

  const RatnexSkeleton({
    super.key,
    this.height = 14,
    this.width,
    this.radius = 6,
  });

  @override
  State<RatnexSkeleton> createState() => _RatnexSkeletonState();
}

class _RatnexSkeletonState extends State<RatnexSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: Color.lerp(
              RatnexColors.hairline.withValues(alpha: 0.55),
              RatnexColors.hairline.withValues(alpha: 0.18),
              _controller.value,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// A few skeleton rows shaped like a list card.
class RatnexListSkeleton extends StatelessWidget {
  final int rows;

  const RatnexListSkeleton({super.key, this.rows = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(rows, (i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: RatnexColors.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RatnexColors.hairline),
          ),
          child: Row(
            children: [
              const RatnexSkeleton(height: 38, width: 38, radius: 19),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    RatnexSkeleton(height: 13, width: 140),
                    SizedBox(height: 8),
                    RatnexSkeleton(height: 11, width: 90),
                  ],
                ),
              ),
              const RatnexSkeleton(height: 16, width: 60),
            ],
          ),
        );
      }),
    );
  }
}

/// Compact metric tile used across dashboards and module headers.
class RatnexStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final Color? accent;
  final VoidCallback? onTap;

  const RatnexStatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? RatnexColors.gold;
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              Haptics.tap();
              onTap!();
            },
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: RatnexColors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: RatnexColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RatnexTheme.label(
                      size: 10,
                      weight: FontWeight.w600,
                    ).copyWith(letterSpacing: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: RatnexTheme.money(size: 19)),
            ),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RatnexTheme.label(size: 10.5, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Status pill.
class RatnexBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool solid;

  const RatnexBadge({
    super.key,
    required this.label,
    required this.color,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: solid ? null : Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: RatnexTheme.label(
          size: 10.5,
          weight: FontWeight.w700,
          color: solid ? Colors.white : color,
        ),
      ),
    );
  }
}

/// Circle with the customer's initials — cheaper than storing avatars.
class RatnexAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const RatnexAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.color,
  });

  static const _palette = <Color>[
    Color(0xFF9A7B2F),
    Color(0xFF1F5FBF),
    Color(0xFF1B7A4E),
    Color(0xFF6B3FBF),
    Color(0xFFB4531B),
    Color(0xFF0F7C8A),
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final seed = trimmed.isEmpty ? 0 : trimmed.codeUnitAt(0);
    final base = color ?? _palette[seed % _palette.length];
    final parts = trimmed.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
            ? parts.first.substring(0, 1).toUpperCase()
            : '${parts.first.substring(0, 1)}${parts.elementAt(1).substring(0, 1)}'
                .toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.13),
        shape: BoxShape.circle,
        border: Border.all(color: base.withValues(alpha: 0.28)),
      ),
      child: Text(
        initials,
        style: RatnexTheme.label(
          size: size * 0.34,
          weight: FontWeight.w700,
          color: base,
        ),
      ),
    );
  }
}

/// Card wrapper with a consistent tap target and border.
class RatnexCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsets padding;
  final Color? borderColor;

  const RatnexCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(14),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RatnexColors.panel,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                Haptics.tap();
                onTap!();
              },
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor ?? RatnexColors.hairline),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Inline banner for warnings such as 269ST or a missing PAN.
class RatnexNotice extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const RatnexNotice({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    required this.color,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: RatnexTheme.label(
                size: 12,
                color: RatnexColors.ink,
                weight: FontWeight.w500,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: RatnexTheme.label(
                  size: 12,
                  weight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Snackbars with a consistent look, including the undo affordance that
/// replaces "are you sure?" dialogs on delete.
class RatnexSnack {
  RatnexSnack._();

  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static void success(BuildContext context, String message) {
    Haptics.success();
    show(context, message);
  }

  static void error(BuildContext context, String message) {
    Haptics.warning();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: RatnexColors.down,
        ),
      );
  }

  /// Shows [message] with an Undo action. [onUndo] runs if the user taps it,
  /// [onCommit] runs when the snackbar closes without an undo.
  static void undoable(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    VoidCallback? onCommit,
    Duration duration = const Duration(seconds: 5),
  }) {
    var undone = false;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              undone = true;
              Haptics.tap();
              onUndo();
            },
          ),
        ),
      ).closed.then((_) {
        if (!undone) onCommit?.call();
      });
  }
}
