import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/checkout_service.dart';
import '../services/shop_plan_service.dart';
import '../theme/ratnex_theme.dart';

class PlansPage extends StatefulWidget {
  const PlansPage({super.key});

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  final _service = ShopPlanService();
  PlanBilling? _opening;

  Future<void> _openCheckout(PlanBilling billing) async {
    setState(() => _opening = billing);
    try {
      await CheckoutService.openCheckout(billing);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete checkout in the browser, then return here.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open checkout: $e')),
      );
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  String _statusLine(ShopPlan current) {
    final parts = <String>[current.statusLabel];
    if (current.expiresOn != null) {
      final fmt = DateFormat('d MMM yyyy').format(current.expiresOn!);
      parts.add(current.isEntitled ? 'till $fmt' : 'ended $fmt');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RatnexColors.surface,
      body: SafeArea(
        child: StreamBuilder<ShopPlan>(
          stream: _service.watchPlan(),
          builder: (context, snap) {
            final current = snap.data ?? ShopPlan.missing;
            final busy = _opening != null;
            final onTrial = current.isEntitled &&
                (current.planStatus == 'trial' ||
                    current.billing == PlanBilling.free);
            final onMonthly = current.isEntitled &&
                current.billing == PlanBilling.monthly &&
                current.planStatus == 'active';
            final onYearly = current.isEntitled &&
                current.billing == PlanBilling.yearly &&
                current.planStatus == 'active';
            final canStartTrial = current.canStartFreeTrial;
            final trialBlocked = current.trialUsedOrExpired || onTrial;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 14, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        color: RatnexColors.ink,
                      ),
                      Expanded(
                        child: Text(
                          'Plans',
                          style: RatnexTheme.brand(size: 28),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      Text(
                        'Choose what fits your shop',
                        style: RatnexTheme.label(
                          size: 15,
                          weight: FontWeight.w600,
                          color: RatnexColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${current.title} · ${_statusLine(current)}',
                        style: RatnexTheme.label(size: 12),
                      ),
                      const SizedBox(height: 18),
                      _PlanCard(
                        title: 'Free trial',
                        price: '₹0',
                        period: '/ 7 days only',
                        badge: canStartTrial ? 'Start here' : 'One-time',
                        subtitle: trialBlocked && !onTrial
                            ? 'Trial already used — choose Monthly or Yearly'
                            : 'Not a permanent free plan',
                        features: const [
                          'Full access for 7 days only',
                          'Bills, girvi, mod & stock',
                          'Ends automatically — then upgrade',
                        ],
                        highlighted: false,
                        selected: onTrial,
                        loading: _opening == PlanBilling.free,
                        enabled: !busy && canStartTrial,
                        onTap: () => _openCheckout(PlanBilling.free),
                        cta: onTrial
                            ? 'Current trial'
                            : trialBlocked
                                ? 'Trial used'
                                : 'Start 7-day trial',
                      ),
                      const SizedBox(height: 12),
                      _PlanCard(
                        title: 'Monthly',
                        price: '₹399',
                        period: '/ month',
                        badge: 'Flexible',
                        features: const [
                          'Unlimited bills, girvi & mod',
                          'Stock, metals & GST tools',
                          'Print & share receipts',
                          'Cancel anytime',
                        ],
                        highlighted: false,
                        selected: onMonthly,
                        loading: _opening == PlanBilling.monthly,
                        enabled: !busy && !onMonthly,
                        onTap: () => _openCheckout(PlanBilling.monthly),
                        cta: onMonthly ? 'Current plan' : 'Choose monthly',
                      ),
                      const SizedBox(height: 12),
                      _PlanCard(
                        title: 'Yearly',
                        price: '₹3,999',
                        period: '/ year',
                        badge: 'Best value',
                        subtitle: 'Save vs monthly — ~₹333/mo',
                        features: const [
                          'Everything in Monthly',
                          '2 months free equivalent',
                          'Priority support',
                          'Best for growing shops',
                        ],
                        highlighted: true,
                        selected: onYearly,
                        loading: _opening == PlanBilling.yearly,
                        enabled: !busy && !onYearly,
                        onTap: () => _openCheckout(PlanBilling.yearly),
                        cta: onYearly ? 'Current plan' : 'Choose yearly',
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Checkout opens in your browser. After payment, you return to Ratnex and your plan updates automatically.',
                        style: RatnexTheme.label(size: 11),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String? badge;
  final String? subtitle;
  final List<String> features;
  final bool highlighted;
  final bool selected;
  final bool loading;
  final bool enabled;
  final String cta;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.badge,
    this.subtitle,
    required this.features,
    required this.highlighted,
    required this.selected,
    required this.loading,
    required this.enabled,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: highlighted ? RatnexColors.ink : RatnexColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? RatnexColors.gold
              : highlighted
                  ? RatnexColors.ink
                  : RatnexColors.hairline,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: RatnexTheme.label(
                  size: 16,
                  weight: FontWeight.w700,
                  color: highlighted ? Colors.white : RatnexColors.ink,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: highlighted
                        ? RatnexColors.gold
                        : RatnexColors.goldSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    style: RatnexTheme.label(
                      size: 10,
                      weight: FontWeight.w700,
                      color: highlighted ? RatnexColors.ink : RatnexColors.gold,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (selected)
                Icon(
                  Icons.check_circle,
                  size: 20,
                  color: highlighted ? RatnexColors.gold : RatnexColors.up,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: RatnexTheme.money(
                  size: 32,
                  color: highlighted ? Colors.white : RatnexColors.ink,
                ),
              ),
              if (period.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    period,
                    style: RatnexTheme.label(
                      size: 13,
                      color: highlighted
                          ? Colors.white70
                          : RatnexColors.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: RatnexTheme.label(
                size: 12,
                color: highlighted ? Colors.white70 : RatnexColors.muted,
              ),
            ),
          ],
          const SizedBox(height: 14),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.check,
                    size: 16,
                    color: highlighted ? RatnexColors.gold : RatnexColors.up,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: RatnexTheme.label(
                        size: 13,
                        color: highlighted ? Colors.white : RatnexColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: (!enabled || selected) ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    highlighted ? RatnexColors.gold : RatnexColors.ink,
                foregroundColor:
                    highlighted ? RatnexColors.ink : Colors.white,
                disabledBackgroundColor: highlighted
                    ? RatnexColors.gold.withValues(alpha: 0.45)
                    : RatnexColors.ink.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: highlighted ? RatnexColors.ink : Colors.white,
                      ),
                    )
                  : Text(
                      cta,
                      style: RatnexTheme.label(
                        size: 14,
                        weight: FontWeight.w700,
                        color: highlighted ? RatnexColors.ink : Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
