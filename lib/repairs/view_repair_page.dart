import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_profile_service.dart';
import '../services/shop_repairs_service.dart';
import '../services/stock_image_helper.dart';
import '../services/whatsapp_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/calc_text_field.dart';
import '../widgets/ratnex_ui.dart';
import 'create_repair_page.dart';
import 'repairs_page.dart';

class ViewRepairPage extends StatefulWidget {
  final String jobNo;

  const ViewRepairPage({super.key, required this.jobNo});

  @override
  State<ViewRepairPage> createState() => _ViewRepairPageState();
}

class _ViewRepairPageState extends State<ViewRepairPage> {
  final _service = ShopRepairsService();
  final _profile = ShopProfileService();
  ShopProfile? _shop;

  @override
  void initState() {
    super.initState();
    _profile.watchProfile().first.then((p) {
      if (mounted) setState(() => _shop = p);
    }).catchError((_) {});
  }

  Future<void> _advance(RepairJob job) async {
    final next = switch (job.status) {
      RepairStatus.received => RepairStatus.inProgress,
      RepairStatus.inProgress => RepairStatus.ready,
      RepairStatus.ready => RepairStatus.delivered,
      _ => null,
    };
    if (next == null) return;

    if (next == RepairStatus.delivered) {
      await _deliver(job);
      return;
    }

    await _service.setStatus(job.jobNo, next);
    if (!mounted) return;
    RatnexSnack.success(context, 'Moved to ${RepairStatus.label(next)}');

    if (next == RepairStatus.ready) {
      await _notifyReady(job);
    }
  }

  Future<void> _notifyReady(RepairJob job) async {
    final message = WhatsAppService.repairReadyMessage(
      shopName: _shop?.shopName ?? 'our shop',
      customerName: job.customerName,
      jobNo: job.jobNo,
      balance: job.balance,
    );
    final ok = await WhatsAppService.send(job.customerPhone, message);
    if (!ok && mounted) {
      await WhatsAppService.copy(message);
      if (mounted) RatnexSnack.show(context, 'Message copied to clipboard');
    }
  }

  Future<void> _deliver(RepairJob job) async {
    final finalAmount = TextEditingController(
      text: job.chargeable == 0 ? '' : job.chargeable.toStringAsFixed(0),
    );
    final billNo = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Deliver ${job.jobNo}', style: RatnexTheme.brand(size: 19)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CalcTextField(
              controller: finalAmount,
              label: 'Final charge',
              prefix: '₹ ',
              allowDecimal: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: billNo,
              style: RatnexTheme.label(size: 13.5, color: RatnexColors.ink),
              decoration: InputDecoration(
                labelText: 'Bill number (optional)',
                labelStyle: RatnexTheme.label(size: 12),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Advance already taken: ${RatnexFormat.money(job.advance)}',
              style: RatnexTheme.label(size: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: RatnexTheme.label(size: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Mark delivered',
              style: RatnexTheme.label(
                size: 13,
                weight: FontWeight.w700,
                color: RatnexColors.up,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _service.setStatus(
      job.jobNo,
      RepairStatus.delivered,
      finalAmount: parseAmount(finalAmount.text, fallback: job.chargeable),
      billNo: billNo.text.trim().isEmpty ? null : billNo.text.trim(),
      note: 'Handed to customer',
    );
    if (mounted) RatnexSnack.success(context, 'Delivered');
  }

  Future<void> _cancel(RepairJob job) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Cancel this job?', style: RatnexTheme.brand(size: 19)),
        content: Text(
          'The job card stays on record but moves out of your open list.',
          style: RatnexTheme.label(size: 13, color: RatnexColors.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep it', style: RatnexTheme.label(size: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Cancel job',
              style: RatnexTheme.label(
                size: 13,
                weight: FontWeight.w700,
                color: RatnexColors.down,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _service.setStatus(job.jobNo, RepairStatus.cancelled);
    if (mounted) RatnexSnack.show(context, 'Job cancelled');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RepairJob?>(
      stream: _service.watchJob(widget.jobNo),
      builder: (context, snap) {
        final job = snap.data;
        if (job == null) {
          return RatnexPageScaffold(
            title: 'Job card',
            subtitle: snap.hasData ? 'Not found' : 'Loading…',
            showBack: true,
            body: snap.hasData
                ? RatnexEmptyState(
                    icon: Icons.help_outline,
                    title: 'Job card not found',
                    message: 'It may have been deleted from another device.',
                  )
                : const RatnexListSkeleton(rows: 3),
          );
        }

        final color = repairStatusColor(job.status);
        final nextLabel = switch (job.status) {
          RepairStatus.received => 'Start work',
          RepairStatus.inProgress => 'Mark ready',
          RepairStatus.ready => 'Deliver',
          _ => null,
        };

        return RatnexPageScaffold(
          title: job.jobNo,
          subtitle:
              '${RepairJobType.label(job.type)} · ${job.customerName}',
          showBack: true,
          trailing: PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: RatnexColors.ink),
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateRepairPage(existing: job),
                    ),
                  );
                case 'whatsapp':
                  _notifyReady(job);
                case 'cancel':
                  _cancel(job);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit job card')),
              const PopupMenuItem(
                value: 'whatsapp',
                child: Text('Send WhatsApp update'),
              ),
              if (job.isOpen)
                const PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancel job'),
                ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            RepairStatus.label(job.status).toUpperCase(),
                            style: RatnexTheme.label(
                              size: 10.5,
                              weight: FontWeight.w700,
                              color: color,
                            ).copyWith(letterSpacing: 0.6),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            job.promisedAt == null
                                ? 'No promised date'
                                : job.isLate
                                    ? '${job.daysLate} days past ${RatnexFormat.date(job.promisedAt)}'
                                    : 'Promised ${RatnexFormat.date(job.promisedAt)}',
                            style: RatnexTheme.label(
                              size: 13,
                              weight: FontWeight.w600,
                              color: RatnexColors.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Received ${RatnexFormat.date(job.receivedAt)}'
                            '${job.karigarName != null ? ' · with ${job.karigarName}' : ''}',
                            style: RatnexTheme.label(size: 11.5),
                          ),
                        ],
                      ),
                    ),
                    if (nextLabel != null)
                      FilledButton(
                        onPressed: () => _advance(job),
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: Text(
                          nextLabel,
                          style: RatnexTheme.label(
                            size: 12.5,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: RatnexStatTile(
                      label: 'Estimate',
                      value: RatnexFormat.money(job.estimate),
                      icon: Icons.request_quote_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RatnexStatTile(
                      label: 'Advance',
                      value: RatnexFormat.money(job.advance),
                      icon: Icons.savings_outlined,
                      accent: RatnexColors.up,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RatnexStatTile(
                      label: 'Balance',
                      value: RatnexFormat.money(job.balance),
                      icon: Icons.account_balance_wallet_outlined,
                      accent: job.balance > 0.5
                          ? RatnexColors.down
                          : RatnexColors.up,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          WhatsAppService.call(job.customerPhone),
                      icon: const Icon(Icons.call_outlined, size: 16),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: RatnexColors.ink,
                        side: BorderSide(color: RatnexColors.hairline),
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _notifyReady(job),
                      icon: const Icon(Icons.chat_outlined, size: 16),
                      label: const Text('WhatsApp'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF25D366),
                        side: BorderSide(color: RatnexColors.hairline),
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const RatnexSectionLabel(text: 'ITEMS'),
              const SizedBox(height: 10),
              ...job.items.map(
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ItemTile(item: i),
                ),
              ),
              if (job.description != null &&
                  job.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                const RatnexSectionLabel(text: 'WORK TO BE DONE'),
                const SizedBox(height: 8),
                RatnexCard(
                  padding: const EdgeInsets.all(13),
                  child: Text(
                    job.description!,
                    style: RatnexTheme.label(
                      size: 13,
                      color: RatnexColors.ink,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const RatnexSectionLabel(text: 'HISTORY'),
              const SizedBox(height: 10),
              StreamBuilder<List<RepairUpdate>>(
                stream: _service.watchUpdates(job.jobNo),
                builder: (context, updateSnap) {
                  final updates = updateSnap.data ?? const <RepairUpdate>[];
                  if (updates.isEmpty) {
                    return Text(
                      'No status changes yet.',
                      style: RatnexTheme.label(size: 12.5),
                    );
                  }
                  return Column(
                    children: updates
                        .map(
                          (u) => Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: repairStatusColor(u.status),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${RepairStatus.label(u.status)}${u.note == null ? '' : ' — ${u.note}'}',
                                    style: RatnexTheme.label(
                                      size: 12.5,
                                      color: RatnexColors.ink,
                                    ),
                                  ),
                                ),
                                Text(
                                  RatnexFormat.shortDate(u.at),
                                  style: RatnexTheme.label(size: 11),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ItemTile extends StatelessWidget {
  final RepairItem item;

  const _ItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final bytes = StockImageHelper.decodeBase64(item.imageBase64);
    return RatnexCard(
      padding: const EdgeInsets.all(11),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: RatnexColors.surface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: RatnexColors.hairline),
            ),
            child: bytes == null
                ? Icon(
                    Icons.diamond_outlined,
                    size: 20,
                    color: RatnexColors.muted,
                  )
                : Image.memory(bytes, fit: BoxFit.cover),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: RatnexTheme.label(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: RatnexColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (item.grossWeight > 0)
                      RatnexFormat.grams(item.grossWeight),
                    if (item.quantity > 1) '${item.quantity} pcs',
                    if (item.condition != null && item.condition!.isNotEmpty)
                      item.condition!,
                  ].join(' · '),
                  style: RatnexTheme.label(size: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
