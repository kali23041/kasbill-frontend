import 'package:flutter/material.dart';

import '../pages/plans_page.dart';
import '../theme/ratnex_theme.dart';

/// Shown when plan trial/subscription is missing or expired.
class PlanLockedPanel extends StatelessWidget {
  final String featureLabel;

  const PlanLockedPanel({super.key, this.featureLabel = 'this feature'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 40,
              color: RatnexColors.gold,
            ),
            const SizedBox(height: 14),
            Text(
              'Trial ended',
              style: RatnexTheme.label(
                size: 18,
                weight: FontWeight.w700,
                color: RatnexColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your 7-day free trial has ended or your plan expired. Upgrade to Monthly or Yearly to use $featureLabel.',
              style: RatnexTheme.label(size: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlansPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: RatnexColors.ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Upgrade plan',
                  style: RatnexTheme.label(
                    size: 14,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps a page: shows [child] when entitled, otherwise lock panel.
class PlanGate extends StatelessWidget {
  final bool entitled;
  final Widget child;
  final String featureLabel;

  const PlanGate({
    super.key,
    required this.entitled,
    required this.child,
    this.featureLabel = 'this feature',
  });

  @override
  Widget build(BuildContext context) {
    if (entitled) return child;
    return PlanLockedPanel(featureLabel: featureLabel);
  }
}
