import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/rate_board.dart';
import '../ledger/udhaar_page.dart';
import '../main_shell.dart';
import '../pages/analytics_page.dart';
import '../pages/create_bill_page.dart';
import '../pages/mod_page.dart';
import '../pages/plans_page.dart';
import '../pages/reminders_page.dart';
import '../pages/reports_page.dart';
import '../pages/view_bill_page.dart';
import '../repairs/repairs_page.dart';
import '../schemes/schemes_page.dart';
import '../services/ibja_rates_service.dart';
import '../services/notifications_service.dart';
import '../services/shop_bills_service.dart';
import '../services/shop_cash_service.dart';
import '../services/shop_rates_service.dart';
import '../theme/ratnex_theme.dart';
import '../widgets/daily_cash_prompt.dart';
import '../widgets/rate_delta_strip.dart';
import '../widgets/ratnex_ui.dart';

class GoldDashboardPage extends StatefulWidget {
  const GoldDashboardPage({super.key});

  @override
  State<GoldDashboardPage> createState() => _GoldDashboardPageState();
}

class _GoldDashboardPageState extends State<GoldDashboardPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  final _ratesService = IbjaRatesService();
  final _shopRates = ShopRatesService();
  final _billsService = ShopBillsService();
  IbjaRates? _rates;
  bool _rateSnapshotsQueued = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
    _entrance.forward();
    _loadRates();
  }

  Future<void> _loadRates() async {
    try {
      final rates = await _ratesService.fetchLatest();
      if (!mounted) return;
      setState(() => _rates = rates);
    } catch (_) {
      // Shop metals still show; live subtitle just stays on saved live rates.
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  bool _isToday(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _requireEntitled(BuildContext context) {
    final entitled = MainShellScope.of(context)?.entitled ?? false;
    if (entitled) return true;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlansPage()),
    );
    return false;
  }

  void _openNewBill(BuildContext context) {
    if (!_requireEntitled(context)) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateBillPage()),
    );
  }

  void _openMod(BuildContext context) {
    if (!_requireEntitled(context)) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ModPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('d MMM yyyy').format(DateTime.now());
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
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
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: StreamBuilder<List<ShopBill>>(
                  stream: _billsService.watchBills(),
                  builder: (context, billsSnap) {
                    final allBills = billsSnap.data ?? const <ShopBill>[];
                    final todayBills = allBills
                        .where((b) => _isToday(b.billedAt ?? b.createdAt))
                        .toList();
                    final todaySales = todayBills.fold<double>(
                      0,
                      (s, b) => s + b.totals.grandTotal,
                    );
                    final todayCustomers = todayBills
                        .map((b) => b.customer.phone ?? b.customer.name)
                        .where((s) => s.trim().isNotEmpty)
                        .toSet()
                        .length;
                    final recent = allBills.take(5).toList();

                    return RefreshIndicator(
                      color: RatnexColors.gold,
                      onRefresh: _loadRates,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Header(today: today),
                                  const SizedBox(height: 12),
                                  const _ReminderBanner(),
                                  const SizedBox(height: 2),
                                  StreamBuilder<List<ShopMetalRate>>(
                                    stream: _shopRates.watchMetals(),
                                    builder: (context, snap) {
                                      final waiting =
                                          snap.connectionState ==
                                              ConnectionState.waiting &&
                                          !snap.hasData;
                                      final metals = snap.data;
                                      if (!_rateSnapshotsQueued &&
                                          metals != null &&
                                          metals.isNotEmpty) {
                                        _rateSnapshotsQueued = true;
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          _shopRates
                                              .recordSnapshotsForMetals(metals);
                                        });
                                      }
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          RatnexRateBoard.fromShopMetals(
                                            loading: waiting,
                                            error: snap.hasError
                                                ? 'Could not load shop metals'
                                                : null,
                                            metals: metals,
                                            currency: currency,
                                            onRetry: _loadRates,
                                            liveRates: _rates,
                                            context: context,
                                          ),
                                          if (metals != null &&
                                              metals.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            RateDeltaStrip(metals: metals),
                                          ],
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _TodayPerformance(
                                    sales: currency.format(todaySales.round()),
                                    bills: todayBills.length,
                                    customers: todayCustomers,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AnalyticsPage(),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  const _CashTodayCard(),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Quick actions',
                                    style: RatnexTheme.label(
                                      size: 11,
                                      weight: FontWeight.w600,
                                      color: RatnexColors.muted,
                                    ).copyWith(letterSpacing: 0.4),
                                  ),
                                  const SizedBox(height: 8),
                                  _QuickActions(
                                    onNewBill: () => _openNewBill(context),
                                    onGirvi: () => MainShellScope.of(context)
                                        ?.selectTab(2),
                                    onMod: () => _openMod(context),
                                    onInventory: () =>
                                        MainShellScope.of(context)
                                            ?.selectTab(3),
                                  ),
                                  const SizedBox(height: 6),
                                  const _SecondaryActions(),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Recent bills',
                                        style: RatnexTheme.label(
                                          size: 11,
                                          weight: FontWeight.w600,
                                          color: RatnexColors.muted,
                                        ).copyWith(letterSpacing: 0.4),
                                      ),
                                      InkWell(
                                        onTap: () => MainShellScope.of(context)
                                            ?.selectTab(1),
                                        child: Text(
                                          'View all',
                                          style: RatnexTheme.label(
                                            size: 12,
                                            weight: FontWeight.w600,
                                            color: RatnexColors.gold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                            sliver: SliverToBoxAdapter(
                              child: _BillsPanel(
                                loading: billsSnap.connectionState ==
                                        ConnectionState.waiting &&
                                    !billsSnap.hasData,
                                error: billsSnap.hasError
                                    ? 'Could not load bills'
                                    : null,
                                bills: recent,
                                currency: currency,
                                onOpen: (bill) {
                                  if (!_requireEntitled(context)) return;
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ViewBillPage(bill: bill),
                                    ),
                                  );
                                },
                                onNewBill: () => _openNewBill(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String today;

  const _Header({required this.today});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ratnex', style: RatnexTheme.brand(size: 28)),
              const SizedBox(height: 2),
              Text(
                today,
                style: RatnexTheme.label(size: 13, color: RatnexColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CashTodayCard extends StatefulWidget {
  const _CashTodayCard();

  @override
  State<_CashTodayCard> createState() => _CashTodayCardState();
}

class _CashTodayCardState extends State<_CashTodayCard> {
  final _cash = ShopCashService();
  late final Stream<CashDay> _stream = _cash.watchToday();
  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  void _openSheet(BuildContext cardContext, CashDay day) {
    showModalBottomSheet<void>(
      context: cardContext,
      backgroundColor: RatnexColors.panel,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final outs = day.entries
            .where((e) => e.type == 'mod_out' || e.type == 'girvi_out')
            .toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cash today',
                  style: RatnexTheme.label(
                    size: 16,
                    weight: FontWeight.w700,
                    color: RatnexColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                _cashLine(
                  'Opening',
                  _currency.format(day.openingCash.round()),
                ),
                _cashLine(
                  'Cash out',
                  _currency.format(day.outsTotal.round()),
                ),
                Divider(color: RatnexColors.hairline),
                _cashLine(
                  'Balance',
                  _currency.format(day.balance.round()),
                  bold: true,
                ),
                if (outs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Outflows',
                    style: RatnexTheme.label(
                      size: 11,
                      weight: FontWeight.w700,
                      color: RatnexColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final e in outs.take(8))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.note ?? e.refId ?? e.type,
                              style: RatnexTheme.label(size: 12),
                            ),
                          ),
                          Text(
                            '- ${_currency.format(e.amount.round())}',
                            style: RatnexTheme.label(
                              size: 12,
                              weight: FontWeight.w600,
                              color: RatnexColors.down,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      // Use card context — sheet context is invalid after pop.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!cardContext.mounted) return;
                        showDailyCashPrompt(cardContext);
                      });
                    },
                    child: const Text('Update opening cash'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cashLine(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: RatnexTheme.label(
                size: 13,
                weight: bold ? FontWeight.w700 : FontWeight.w500,
                color: RatnexColors.ink,
              ),
            ),
          ),
          Text(
            value,
            style: bold
                ? RatnexTheme.money(size: 16, color: RatnexColors.gold)
                : RatnexTheme.label(
                    size: 13,
                    weight: FontWeight.w600,
                    color: RatnexColors.ink,
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CashDay>(
      stream: _stream,
      builder: (context, snap) {
        final day = snap.data ??
            CashDay.emptyFor(
              ShopCashService.dayId(),
              ShopCashService.dayStart(),
            );
        final low = day.balance < 0;

        return Material(
          color: RatnexColors.panel,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openSheet(context, day),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: RatnexColors.hairline),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: RatnexColors.goldSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.payments_outlined,
                      color: RatnexColors.gold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cash today',
                          style: RatnexTheme.label(
                            size: 11,
                            weight: FontWeight.w600,
                            color: RatnexColors.muted,
                          ),
                        ),
                        Text(
                          _currency.format(day.balance.round()),
                          style: RatnexTheme.money(
                            size: 18,
                            color: low ? RatnexColors.down : RatnexColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Open ${_currency.format(day.openingCash.round())}',
                    style: RatnexTheme.label(size: 11),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: RatnexColors.muted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TodayPerformance extends StatelessWidget {
  final String sales;
  final int bills;
  final int customers;
  final VoidCallback? onTap;

  const _TodayPerformance({
    required this.sales,
    required this.bills,
    required this.customers,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RatnexColors.panel,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RatnexColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "TODAY'S SALES",
                      style: RatnexTheme.label(
                        size: 10,
                        weight: FontWeight.w700,
                      ).copyWith(letterSpacing: 0.7),
                    ),
                  ),
                  Text(
                    'Analytics',
                    style: RatnexTheme.label(
                      size: 11,
                      weight: FontWeight.w600,
                      color: RatnexColors.gold,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: RatnexColors.gold,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(sales, style: RatnexTheme.money(size: 32)),
              const SizedBox(height: 12),
              Container(height: 1, color: RatnexColors.hairline),
              const SizedBox(height: 10),
              Row(
                children: [
                  _InlineMetric(label: 'Bills', value: '$bills'),
                  Container(
                    width: 1,
                    height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: RatnexColors.hairline,
                  ),
                  _InlineMetric(label: 'Customers', value: '$customers'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  final String label;
  final String value;

  const _InlineMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(value, style: RatnexTheme.money(size: 18)),
        const SizedBox(width: 8),
        Text(label, style: RatnexTheme.label(size: 12)),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onNewBill;
  final VoidCallback onGirvi;
  final VoidCallback onMod;
  final VoidCallback onInventory;

  const _QuickActions({
    required this.onNewBill,
    required this.onGirvi,
    required this.onMod,
    required this.onInventory,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _ActionButton(
              label: 'New Bill',
              icon: Icons.add,
              primary: true,
              onTap: onNewBill,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: _ActionButton(
              label: 'Girvi',
              icon: Icons.account_balance_outlined,
              onTap: onGirvi,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: _ActionButton(
              label: 'Mod',
              icon: Icons.handshake_outlined,
              onTap: onMod,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: _ActionButton(
              label: 'Stock',
              icon: Icons.inventory_2_outlined,
              onTap: onInventory,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    this.primary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? RatnexColors.ink : RatnexColors.panel,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:
                primary ? null : Border.all(color: RatnexColors.hairline),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: primary ? Colors.white : RatnexColors.ink,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: RatnexTheme.label(
                  size: 11,
                  weight: FontWeight.w700,
                  color: primary ? Colors.white : RatnexColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillsPanel extends StatelessWidget {
  final List<ShopBill> bills;
  final NumberFormat currency;
  final bool loading;
  final String? error;
  final ValueChanged<ShopBill> onOpen;
  final VoidCallback onNewBill;

  const _BillsPanel({
    required this.bills,
    required this.currency,
    required this.loading,
    required this.error,
    required this.onOpen,
    required this.onNewBill,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return RatnexColors.up;
      case 'partial':
        return RatnexColors.gold;
      case 'cancelled':
        return RatnexColors.muted;
      default:
        return RatnexColors.down;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RatnexColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RatnexColors.hairline),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'INVOICE',
                    style: RatnexTheme.label(size: 10, weight: FontWeight.w700)
                        .copyWith(letterSpacing: 0.5),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'CUSTOMER',
                    style: RatnexTheme.label(size: 10, weight: FontWeight.w700)
                        .copyWith(letterSpacing: 0.5),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'STATUS',
                    style: RatnexTheme.label(size: 10, weight: FontWeight.w700)
                        .copyWith(letterSpacing: 0.5),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'AMOUNT',
                    style: RatnexTheme.label(size: 10, weight: FontWeight.w700)
                        .copyWith(letterSpacing: 0.5),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: RatnexColors.hairline),
          if (loading)
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: RatnexColors.gold),
              ),
            )
          else if (error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error!, style: RatnexTheme.label(size: 13)),
            )
          else if (bills.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                children: [
                  Text(
                    'No bills yet',
                    style: RatnexTheme.label(
                      size: 14,
                      weight: FontWeight.w700,
                      color: RatnexColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create your first invoice from New Bill.',
                    style: RatnexTheme.label(size: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: onNewBill,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Bill'),
                    style: TextButton.styleFrom(
                      foregroundColor: RatnexColors.gold,
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(bills.length, (index) {
              final bill = bills[index];
              final time = bill.billedAt ?? bill.createdAt;
              final timeStr =
                  time == null ? '—' : DateFormat('h:mm a').format(time);
              final itemHint = bill.items.isEmpty
                  ? null
                  : bill.items.length == 1
                      ? bill.items.first.name
                      : '${bill.items.length} items';

              return Column(
                children: [
                  InkWell(
                    onTap: () => onOpen(bill),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bill.billNo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RatnexTheme.label(
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: RatnexColors.ink,
                                  ),
                                ),
                                Text(
                                  timeStr,
                                  style: RatnexTheme.label(size: 10),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bill.customer.name,
                                  style: RatnexTheme.label(
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color: RatnexColors.ink,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (itemHint != null)
                                  Text(
                                    itemHint,
                                    style: RatnexTheme.label(size: 10),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              bill.statusLabel,
                              style: RatnexTheme.label(
                                size: 11,
                                weight: FontWeight.w700,
                                color: _statusColor(bill.paymentStatus),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              currency.format(bill.totals.grandTotal.round()),
                              style: RatnexTheme.money(size: 13),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (index != bills.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 12,
                      endIndent: 12,
                      color: RatnexColors.hairline,
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

/// Shows what needs chasing today, straight on the home screen.
class _ReminderBanner extends StatelessWidget {
  const _ReminderBanner();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ShopReminder>>(
      stream: NotificationsService.instance.watchReminders(),
      builder: (context, snap) {
        final all = snap.data ?? const <ShopReminder>[];
        final unread = all.where((r) => !r.read).toList();
        if (unread.isEmpty) return const SizedBox.shrink();

        final first = unread.first;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: RatnexCard(
            borderColor: RatnexColors.gold.withValues(alpha: 0.35),
            padding: const EdgeInsets.all(12),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RemindersPage()),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: RatnexColors.goldSoft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.notifications_active_outlined,
                    size: 17,
                    color: RatnexColors.gold,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        first.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RatnexTheme.label(
                          size: 13,
                          weight: FontWeight.w700,
                          color: RatnexColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        unread.length == 1
                            ? first.body
                            : '${unread.length - 1} more need chasing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RatnexTheme.label(size: 11.5),
                      ),
                    ],
                  ),
                ),
                RatnexBadge(
                  label: '${unread.length}',
                  color: RatnexColors.gold,
                  solid: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The modules that do not have a bottom-nav tab of their own.
class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: 'Udhaar',
              icon: Icons.account_balance_wallet_outlined,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UdhaarPage()),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ActionButton(
              label: 'Repairs',
              icon: Icons.build_outlined,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RepairsPage()),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ActionButton(
              label: 'Schemes',
              icon: Icons.savings_outlined,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SchemesPage()),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ActionButton(
              label: 'Reports',
              icon: Icons.insights_outlined,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportsPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
