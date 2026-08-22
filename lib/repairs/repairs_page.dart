import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_repairs_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/ratnex_ui.dart';
import 'create_repair_page.dart';
import 'view_repair_page.dart';

/// Job cards for repair and custom-order work — the daily counter task that
/// otherwise lives on paper slips.
class RepairsPage extends StatefulWidget {
  const RepairsPage({super.key});

  @override
  State<RepairsPage> createState() => _RepairsPageState();
}

class _RepairsPageState extends State<RepairsPage> {
  final _service = ShopRepairsService();
  final _search = TextEditingController();

  String _query = '';
  String _filter = 'open';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RepairJob>>(
      stream: _service.watchJobs(),
      builder: (context, snap) {
        final all = snap.data ?? const <RepairJob>[];
        final loading = !snap.hasData && !snap.hasError;

        final open = all.where((j) => j.isOpen).toList();
        final ready = all
            .where((j) => j.status == RepairStatus.ready)
            .toList();
        final late = all.where((j) => j.isLate).toList();
        final delivered = all
            .where((j) => j.status == RepairStatus.delivered)
            .toList();

        var visible = switch (_filter) {
          'ready' => ready,
          'late' => late,
          'delivered' => delivered,
          'all' => all,
          _ => open,
        };

        final q = _query.trim().toLowerCase();
        if (q.isNotEmpty) {
          final digits = q.replaceAll(RegExp(r'\D'), '');
          visible = visible.where((j) {
            return j.jobNo.toLowerCase().contains(q) ||
                j.customerName.toLowerCase().contains(q) ||
                (digits.isNotEmpty &&
                    (j.customerPhone ?? '').contains(digits)) ||
                j.items.any((i) => i.name.toLowerCase().contains(q));
          }).toList();
        }

        final advance = ShopRepairsService.advanceHeld(all);

        return RatnexPageScaffold(
          title: 'Repairs',
          subtitle: open.isEmpty
              ? 'Job cards for repair and custom work'
              : '${open.length} jobs in hand',
          showBack: true,
          trailing: IconButton(
            tooltip: 'New job card',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateRepairPage()),
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
                      label: 'In hand',
                      value: '${open.length}',
                      caption: '${ready.length} ready to give',
                      icon: Icons.build_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RatnexStatTile(
                      label: 'Late',
                      value: '${late.length}',
                      caption: late.isEmpty ? 'All on time' : 'Past promised date',
                      icon: Icons.running_with_errors_outlined,
                      accent:
                          late.isEmpty ? RatnexColors.up : RatnexColors.down,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RatnexStatTile(
                      label: 'Advance held',
                      value: RatnexFormat.compact(advance),
                      caption: 'on open jobs',
                      icon: Icons.savings_outlined,
                      accent: RatnexColors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              RatnexSearchField(
                hint: 'Search token, customer or item',
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 10),
              RatnexFilterChips(
                selected: _filter,
                options: [
                  (value: 'open', label: 'Open', count: open.length),
                  (value: 'ready', label: 'Ready', count: ready.length),
                  (value: 'late', label: 'Late', count: late.length),
                  (
                    value: 'delivered',
                    label: 'Delivered',
                    count: delivered.length
                  ),
                  (value: 'all', label: 'All', count: all.length),
                ],
                onSelected: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 14),
              if (loading)
                const RatnexListSkeleton()
              else if (all.isEmpty)
                RatnexEmptyState(
                  icon: Icons.build_outlined,
                  title: 'No job cards yet',
                  message:
                      'When a customer leaves jewellery for repair, resizing or a custom order, make a job card with a token number, a photo and a promised date.',
                  actionLabel: 'Create a job card',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateRepairPage()),
                  ),
                )
              else if (visible.isEmpty)
                RatnexEmptyState(
                  icon: _filter == 'late'
                      ? Icons.check_circle_outline
                      : Icons.search_off,
                  title: _filter == 'late'
                      ? 'Nothing is late'
                      : 'Nothing matches',
                  message: _filter == 'late'
                      ? 'Every open job is still inside its promised date.'
                      : 'Try a different token, name or filter.',
                )
              else
                ...visible.map(
                  (j) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _JobCard(
                      job: j,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ViewRepairPage(jobNo: j.jobNo),
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

Color repairStatusColor(String status) {
  switch (status) {
    case RepairStatus.ready:
      return RatnexColors.up;
    case RepairStatus.inProgress:
      return RatnexColors.info;
    case RepairStatus.delivered:
      return RatnexColors.muted;
    case RepairStatus.cancelled:
      return RatnexColors.down;
    default:
      return RatnexColors.warn;
  }
}

class _JobCard extends StatelessWidget {
  final RepairJob job;
  final VoidCallback onTap;

  const _JobCard({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = repairStatusColor(job.status);

    return RatnexCard(
      onTap: onTap,
      borderColor: job.isLate ? RatnexColors.down.withValues(alpha: 0.3) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: RatnexColors.goldSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  job.jobNo,
                  style: RatnexTheme.money(
                    size: 12,
                    color: RatnexColors.gold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RatnexTheme.label(
                        size: 14,
                        weight: FontWeight.w700,
                        color: RatnexColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${RepairJobType.label(job.type)} · ${job.items.length} item${job.items.length == 1 ? '' : 's'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RatnexTheme.label(size: 11.5),
                    ),
                  ],
                ),
              ),
              RatnexBadge(
                label: job.isLate
                    ? '${job.daysLate}d late'
                    : RepairStatus.label(job.status),
                color: job.isLate ? RatnexColors.down : color,
              ),
            ],
          ),
          const SizedBox(height: 11),
          Divider(height: 1, color: RatnexColors.hairline),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.event_outlined,
                size: 14,
                color: job.isLate ? RatnexColors.down : RatnexColors.muted,
              ),
              const SizedBox(width: 5),
              Text(
                job.promisedAt == null
                    ? 'No promised date'
                    : 'Promised ${RatnexFormat.date(job.promisedAt)}',
                style: RatnexTheme.label(
                  size: 11.5,
                  color: job.isLate ? RatnexColors.down : null,
                ),
              ),
              const Spacer(),
              if (job.advance > 0)
                Text(
                  '${RatnexFormat.money(job.advance)} advance',
                  style: RatnexTheme.label(size: 11.5, color: RatnexColors.up),
                ),
              if (job.balance > 0.5) ...[
                const SizedBox(width: 10),
                Text(
                  '${RatnexFormat.money(job.balance)} due',
                  style: RatnexTheme.money(size: 12.5),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
