import 'dart:async';

import 'package:flutter/material.dart';

import 'components/ratnex_bottom_navbar.dart';
import 'dashboard/gold_dashboard_page.dart';
import 'pages/bills_page.dart';
import 'pages/girvi_page.dart';
import 'pages/plans_page.dart';
import 'pages/profile_page.dart';
import 'pages/stock_page.dart';
import 'services/checkout_service.dart';
import 'services/deep_link_service.dart';
import 'services/shop_cash_service.dart';
import 'services/shop_plan_service.dart';
import 'theme/ratnex_theme.dart';
import 'widgets/daily_cash_prompt.dart';
import 'widgets/plan_gate.dart';

class MainShellScope extends InheritedWidget {
  final int selectedIndex;
  final ValueChanged<int> selectTab;
  final bool entitled;

  const MainShellScope({
    super.key,
    required this.selectedIndex,
    required this.selectTab,
    required this.entitled,
    required super.child,
  });

  static MainShellScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainShellScope>();
  }

  @override
  bool updateShouldNotify(MainShellScope oldWidget) =>
      selectedIndex != oldWidget.selectedIndex ||
      entitled != oldWidget.entitled;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final _planService = ShopPlanService();
  final _cashService = ShopCashService();
  StreamSubscription<Uri>? _deepLinkSub;
  bool _trialCheckoutStarted = false;
  bool _handlingDeepLink = false;
  bool _cashPromptShown = false;

  @override
  void initState() {
    super.initState();
    _startDeepLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptCash();
    });
  }

  Future<void> _startDeepLinks() async {
    await DeepLinkService.instance.start();
    _deepLinkSub = DeepLinkService.instance.links.listen(_onDeepLink);
  }

  Future<void> _onDeepLink(Uri uri) async {
    if (_handlingDeepLink) return;
    final success = DeepLinkService.isPaymentSuccess(uri);
    final cancel = DeepLinkService.isPaymentCancel(uri);
    if (!success && !cancel) return;

    _handlingDeepLink = true;
    try {
      await _planService.getPlan();
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment complete. Refreshing your plan…'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checkout cancelled.')),
        );
      }

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PlansPage()),
      );
    } finally {
      _handlingDeepLink = false;
    }
  }

  Future<void> _maybeStartTrial(ShopPlan plan) async {
    if (_trialCheckoutStarted) return;
    if (!plan.canStartFreeTrial) return;
    _trialCheckoutStarted = true;
    try {
      await CheckoutService.openCheckout(PlanBilling.free);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start your 7-day free trial in the browser.'),
        ),
      );
    } catch (e) {
      debugPrint('First trial checkout: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Open Plans to start your free trial. ($e)'),
          action: SnackBarAction(
            label: 'Plans',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlansPage()),
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> _maybePromptCash() async {
    if (_cashPromptShown || !mounted) return;
    _cashPromptShown = true;
    try {
      final today = await _cashService.getToday();
      if (!mounted) return;
      if (today.prompted) return;
      // Defer one more frame so Scaffold/Navigator are fully mounted.
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      await showDailyCashPrompt(context);
    } catch (e) {
      debugPrint('Daily cash prompt: $e');
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ShopPlan>(
      stream: _planService.watchPlan(),
      builder: (context, snap) {
        final plan = snap.data ?? ShopPlan.missing;
        final entitled = plan.isEntitled;

        if (snap.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybeStartTrial(plan);
          });
        }

        return MainShellScope(
          selectedIndex: _selectedIndex,
          selectTab: _onItemTapped,
          entitled: entitled,
          child: Scaffold(
            backgroundColor: RatnexColors.surface,
            body: RepaintBoundary(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  const _KeepAlive(child: GoldDashboardPage()),
                  _KeepAlive(
                    child: PlanGate(
                      entitled: entitled,
                      featureLabel: 'bills',
                      child: const BillsPage(),
                    ),
                  ),
                  _KeepAlive(
                    child: PlanGate(
                      entitled: entitled,
                      featureLabel: 'girvi',
                      child: const GirviPage(),
                    ),
                  ),
                  _KeepAlive(
                    child: PlanGate(
                      entitled: entitled,
                      featureLabel: 'stock',
                      child: const StockPage(),
                    ),
                  ),
                  const _KeepAlive(child: ProfilePage()),
                ],
              ),
            ),
            bottomNavigationBar: RepaintBoundary(
              child: RatnexBottomNavbar(
                selectedIndex: _selectedIndex,
                onItemTapped: _onItemTapped,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;

  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
