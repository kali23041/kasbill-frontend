import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_bills_service.dart';
import '../services/shop_customers_service.dart';
import '../services/shop_girvi_service.dart';
import '../services/shop_ledger_service.dart';
import '../services/shop_mod_service.dart';
import '../services/shop_profile_service.dart';
import '../services/shop_repairs_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/ratnex_ui.dart';
import '../ledger/udhaar_detail_page.dart';
import 'view_bill_page.dart';
import 'view_girvi_page.dart';
import 'view_mod_page.dart';

/// A single customer's whole history in one scroll: bills, girvi, old-gold
/// sales, job cards and their khata.
class CustomerDetailPage extends StatefulWidget {
  final ShopCustomer customer;

  const CustomerDetailPage({super.key, required this.customer});

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _TimelineEvent {
  final DateTime at;
  final String kind;
  final String title;
  final String subtitle;
  final double amount;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _TimelineEvent({
    required this.at,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.color,
    required this.icon,
    this.onTap,
  });
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  final _bills = ShopBillsService();
  final _girvi = ShopGirviService();
  final _mod = ShopModService();
  final _repairs = ShopRepairsService();
  final _ledger = ShopLedgerService();
  final _profile = ShopProfileService();

  String _filter = 'all';
  ShopProfile? _shop;

  String get _phoneId => widget.customer.phoneId;

  @override
  void initState() {
    super.initState();
    _profile.watchProfile().first.then((p) {
      if (mounted) setState(() => _shop = p);
    }).catchError((_) {});
  }

  bool _isMine(String? phone) =>
      customerPhoneDocId(phone) == _phoneId;

  Future<void> _whatsapp(String message) async {
    final ok = await WhatsAppService.send(widget.customer.phone, message);
    if (!mounted) return;
    if (!ok) {
      RatnexSnack.error(
        context,
        'Could not open WhatsApp for this number',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;

    return StreamBuilder<List<ShopBill>>(
      stream: _bills.watchBills(),
      builder: (context, billSnap) {
        return StreamBuilder<List<ShopGirvi>>(
          stream: _girvi.watchGirvi(),
          builder: (context, girviSnap) {
            return StreamBuilder<List<ShopMod>>(
              stream: _mod.watchMod(),
              builder: (context, modSnap) {
                return StreamBuilder<List<RepairJob>>(
                  stream: _repairs.watchJobs(),
                  builder: (context, repairSnap) {
                    return StreamBuilder<UdhaarAccount?>(
                      stream: _ledger.watchAccount(_phoneId),
                      builder: (context, accountSnap) {
                        final bills = (billSnap.data ?? const <ShopBill>[])
                            .where((b) => _isMine(b.customer.phone))
                            .toList();
                        final girvis = (girviSnap.data ?? const <ShopGirvi>[])
                            .where((g) => _isMine(g.customer.phone))
                            .toList();
                        final mods = (modSnap.data ?? const <ShopMod>[])
                            .where((m) => _isMine(m.customer.phone))
                            .toList();
                        final jobs = (repairSnap.data ?? const <RepairJob>[])
                            .where((j) => _isMine(j.customerPhone))
                            .toList();
                        final account = accountSnap.data;

                        final spend = bills
                            .where((b) => b.paymentStatus != 'cancelled')
                            .fold<double>(
                                0, (s, b) => s + b.totals.grandTotal);
                        final grams = bills.fold<double>(
                          0,
                          (s, b) => s +
                              b.items.fold<double>(
                                0,
                                (t, i) => t + i.netWeight * i.qty,
                              ),
                        );
                        final events = _buildTimeline(bills, girvis, mods, jobs);
                        final visible = _filter == 'all'
                            ? events
                            : events.where((e) => e.kind == _filter).toList();

                        return RatnexPageScaffold(
                          title: c.name.isEmpty ? 'Customer' : c.name,
                          subtitle:
                              '${c.phone}${c.gstin != null && c.gstin!.isNotEmpty ? ' · ${c.gstin}' : ''}',
                          showBack: true,
                          body: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _actions(spend, account),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: RatnexStatTile(
                                      label: 'Lifetime value',
                                      value: RatnexFormat.compact(spend),
                                      caption: '${bills.length} bills',
                                      icon: Icons.payments_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: RatnexStatTile(
                                      label: 'Gold bought',
                                      value: RatnexFormat.grams(grams),
                                      caption: 'net weight',
                                      icon: Icons.scale_outlined,
                                      accent: RatnexColors.gold,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: RatnexStatTile(
                                      label: 'Outstanding',
                                      value: RatnexFormat.compact(
                                        account?.outstanding ?? 0,
                                      ),
                                      caption: account == null ||
                                              account.isSettled
                                          ? 'All clear'
                                          : account.isOverdue
                                              ? '${account.daysOverdue}d overdue'
                                              : 'Not yet due',
                                      icon: Icons
                                          .account_balance_wallet_outlined,
                                      accent: (account?.outstanding ?? 0) > 0.5
                                          ? RatnexColors.down
                                          : RatnexColors.up,
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => UdhaarDetailPage(
                                            phoneId: _phoneId,
                                            name: c.name,
                                            phone: c.phone,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (c.address != null &&
                                  c.address!.trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                RatnexCard(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.place_outlined,
                                        size: 16,
                                        color: RatnexColors.muted,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          c.address!,
                                          style: RatnexTheme.label(
                                            size: 12.5,
                                            color: RatnexColors.ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              const RatnexSectionLabel(text: 'TIMELINE'),
                              const SizedBox(height: 10),
                              RatnexFilterChips(
                                selected: _filter,
                                options: [
                                  (
                                    value: 'all',
                                    label: 'All',
                                    count: events.length
                                  ),
                                  (
                                    value: 'bill',
                                    label: 'Bills',
                                    count: bills.length
                                  ),
                                  (
                                    value: 'girvi',
                                    label: 'Girvi',
                                    count: girvis.length
                                  ),
                                  (
                                    value: 'mod',
                                    label: 'Old gold',
                                    count: mods.length
                                  ),
                                  (
                                    value: 'repair',
                                    label: 'Jobs',
                                    count: jobs.length
                                  ),
                                ],
                                onSelected: (v) => setState(() => _filter = v),
                              ),
                              const SizedBox(height: 12),
                              if (visible.isEmpty)
                                RatnexEmptyState(
                                  icon: Icons.history,
                                  title: 'Nothing here yet',
                                  message:
                                      'Bills, girvi, old-gold purchases and job cards for this customer all appear on this timeline.',
                                )
                              else
                                ...visible.map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _TimelineTile(event: e),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _actions(double spend, UdhaarAccount? account) {
    final shopName = _shop?.shopName ?? 'our shop';
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.call_outlined,
            label: 'Call',
            onTap: () => WhatsAppService.call(widget.customer.phone),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.chat_outlined,
            label: 'WhatsApp',
            color: const Color(0xFF25D366),
            onTap: () => _whatsapp(
              (account != null && !account.isSettled)
                  ? WhatsAppService.udhaarReminder(
                      shopName: shopName,
                      customerName: widget.customer.name,
                      outstanding: account.outstanding,
                      daysOverdue: account.daysOverdue,
                      upiId: _shop?.upiId,
                    )
                  : 'Namaste ${widget.customer.name} 🙏\n\nThank you for shopping at $shopName.',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Khata',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UdhaarDetailPage(
                  phoneId: _phoneId,
                  name: widget.customer.name,
                  phone: widget.customer.phone,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<_TimelineEvent> _buildTimeline(
    List<ShopBill> bills,
    List<ShopGirvi> girvis,
    List<ShopMod> mods,
    List<RepairJob> jobs,
  ) {
    final events = <_TimelineEvent>[];

    for (final b in bills) {
      events.add(
        _TimelineEvent(
          at: b.billedAt ?? b.createdAt ?? DateTime(2000),
          kind: 'bill',
          title: 'Bill ${b.billNo}',
          subtitle:
              '${b.items.length} item${b.items.length == 1 ? '' : 's'} · ${b.statusLabel}',
          amount: b.totals.grandTotal,
          color: RatnexColors.gold,
          icon: Icons.receipt_long_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ViewBillPage(bill: b)),
          ),
        ),
      );
    }
    for (final g in girvis) {
      events.add(
        _TimelineEvent(
          at: g.startedAt,
          kind: 'girvi',
          title: 'Girvi ${g.girviNo}',
          subtitle:
              '${g.items.length} item${g.items.length == 1 ? '' : 's'} · due ${RatnexFormat.shortDate(g.dueDate)}',
          amount: g.loanAmount,
          color: RatnexColors.violet,
          icon: Icons.account_balance_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ViewGirviPage(girvi: g)),
          ),
        ),
      );
    }
    for (final m in mods) {
      events.add(
        _TimelineEvent(
          at: m.paidAt,
          kind: 'mod',
          title: 'Old gold ${m.modNo}',
          subtitle: 'Sold to shop · ${m.paymentModeLabel}',
          amount: m.totals.purchaseAmount,
          color: RatnexColors.info,
          icon: Icons.swap_horiz,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ViewModPage(mod: m)),
          ),
        ),
      );
    }
    for (final j in jobs) {
      events.add(
        _TimelineEvent(
          at: j.receivedAt ?? j.createdAt ?? DateTime(2000),
          kind: 'repair',
          title: 'Token ${j.jobNo}',
          subtitle:
              '${RepairJobType.label(j.type)} · ${RepairStatus.label(j.status)}',
          amount: j.chargeable,
          color: RatnexColors.warn,
          icon: Icons.build_outlined,
        ),
      );
    }

    events.sort((a, b) => b.at.compareTo(a.at));
    return events;
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? RatnexColors.ink;
    return Material(
      color: RatnexColors.panel,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: RatnexColors.hairline),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: c),
              const SizedBox(width: 6),
              Text(
                label,
                style: RatnexTheme.label(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: RatnexColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final _TimelineEvent event;

  const _TimelineTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return RatnexCard(
      onTap: event.onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: event.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(event.icon, size: 17, color: event.color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: RatnexTheme.label(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: RatnexColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${event.subtitle} · ${RatnexFormat.date(event.at)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RatnexTheme.label(size: 11),
                ),
              ],
            ),
          ),
          Text(
            RatnexFormat.money(event.amount),
            style: RatnexTheme.money(size: 13.5),
          ),
          if (event.onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 17,
              color: RatnexColors.muted,
            ),
          ],
        ],
      ),
    );
  }
}
