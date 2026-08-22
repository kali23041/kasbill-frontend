import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_schemes_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/ratnex_ui.dart';
import 'create_scheme_page.dart';
import 'scheme_detail_page.dart';

/// Monthly gold savings plans — the "11 + 1" every jeweller runs on paper.
class SchemesPage extends StatefulWidget {
  const SchemesPage({super.key});

  @override
  State<SchemesPage> createState() => _SchemesPageState();
}

class _SchemesPageState extends State<SchemesPage> {
  final _service = ShopSchemesService();
  String _filter = 'active';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SavingsScheme>>(
      stream: _service.watchSchemes(),
      builder: (context, snap) {
        final all = snap.data ?? const <SavingsScheme>[];
        final loading = !snap.hasData && !snap.hasError;
        final active = all.where((s) => s.isActive).toList();
        final closed = all.where((s) => !s.isActive).toList();

        final visible = switch (_filter) {
          'closed' => closed,
          'all' => all,
          _ => active,
        };

        final collected = all.fold<double>(0, (s, e) => s + e.collected);
        final members = all.fold<int>(0, (s, e) => s + e.memberCount);

        return RatnexPageScaffold(
          title: 'Schemes',
          subtitle: members == 0
              ? 'Monthly gold savings plans'
              : '$members members saving with you',
          showBack: true,
          trailing: IconButton(
            tooltip: 'New scheme',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateSchemePage()),
            ),
            icon: Icon(Icons.add_circle_outline, color: RatnexColors.ink),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RatnexStatTile(
                      label: 'Collected',
                      value: RatnexFormat.compact(collected),
                      caption: 'across all plans',
                      icon: Icons.savings_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RatnexStatTile(
                      label: 'Members',
                      value: '$members',
                      caption: '${active.length} active plans',
                      icon: Icons.groups_outlined,
                      accent: RatnexColors.info,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RatnexStatTile(
                      label: 'Plans',
                      value: '${all.length}',
                      caption: '${closed.length} closed',
                      icon: Icons.event_repeat_outlined,
                      accent: RatnexColors.violet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              RatnexFilterChips(
                selected: _filter,
                options: [
                  (value: 'active', label: 'Active', count: active.length),
                  (value: 'closed', label: 'Closed', count: closed.length),
                  (value: 'all', label: 'All', count: all.length),
                ],
                onSelected: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 14),
              if (loading)
                const RatnexListSkeleton(rows: 3)
              else if (all.isEmpty)
                RatnexEmptyState(
                  icon: Icons.savings_outlined,
                  title: 'No schemes yet',
                  message:
                      'Run an 11 + 1 monthly plan: the customer pays eleven installments, you pay the twelfth. Every installment and every gram is tracked here.',
                  actionLabel: 'Create a scheme',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateSchemePage()),
                  ),
                )
              else if (visible.isEmpty)
                RatnexEmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'Nothing in this filter',
                  message: 'Switch the filter above to see your other plans.',
                )
              else
                ...visible.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SchemeCard(
                      scheme: s,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SchemeDetailPage(schemeId: s.id),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SchemeCard extends StatelessWidget {
  final SavingsScheme scheme;
  final VoidCallback onTap;

  const _SchemeCard({required this.scheme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return RatnexCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: RatnexColors.goldSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  scheme.planLabel,
                  style: RatnexTheme.label(
                    size: 11,
                    weight: FontWeight.w700,
                    color: RatnexColors.gold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scheme.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RatnexTheme.label(
                        size: 14.5,
                        weight: FontWeight.w700,
                        color: RatnexColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${RatnexFormat.money(scheme.monthlyAmount)}/month · ${SchemeAccrual.label(scheme.accrual)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RatnexTheme.label(size: 11.5),
                    ),
                  ],
                ),
              ),
              RatnexBadge(
                label: scheme.isActive ? 'Active' : 'Closed',
                color: scheme.isActive ? RatnexColors.up : RatnexColors.muted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: RatnexColors.hairline),
          const SizedBox(height: 11),
          Row(
            children: [
              _MiniStat(
                label: 'Members',
                value: '${scheme.memberCount}',
              ),
              _MiniStat(
                label: 'Collected',
                value: RatnexFormat.compact(scheme.collected),
              ),
              _MiniStat(
                label: 'Bonus',
                value: SchemeBonusType.label(scheme.bonusType)
                    .split(' ')
                    .first,
              ),
              _MiniStat(
                label: 'Started',
                value: RatnexFormat.shortDate(scheme.startedAt),
                last: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool last;

  const _MiniStat({
    required this.label,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment:
            last ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: RatnexTheme.label(size: 9.5, weight: FontWeight.w600)
                .copyWith(letterSpacing: 0.4),
          ),
          const SizedBox(height: 4),
          Text(value, style: RatnexTheme.money(size: 13)),
        ],
      ),
    );
  }
}
