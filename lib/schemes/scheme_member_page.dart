import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_schemes_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/ratnex_ui.dart';

/// A member's passbook: every installment, grams accrued and what they can
/// redeem at maturity.
class SchemeMemberPage extends StatefulWidget {
  final String schemeId;
  final String memberId;

  const SchemeMemberPage({
    super.key,
    required this.schemeId,
    required this.memberId,
  });

  @override
  State<SchemeMemberPage> createState() => _SchemeMemberPageState();
}

class _SchemeMemberPageState extends State<SchemeMemberPage> {
  final _service = ShopSchemesService();

  Future<void> _redeem(SavingsScheme scheme, SchemeMember member) async {
    final controller = TextEditingController();
    final billNo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Redeem maturity', style: RatnexTheme.brand(size: 19)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${member.name} can redeem ${RatnexFormat.money(ShopSchemesService.maturityValue(scheme, member))}'
              '${member.gramsAccrued > 0 ? ' or ${RatnexFormat.grams(member.gramsAccrued)}' : ''}.',
              style: RatnexTheme.label(size: 13, color: RatnexColors.ink),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              style: RatnexTheme.label(size: 13.5, color: RatnexColors.ink),
              decoration: InputDecoration(
                labelText: 'Bill number it was redeemed against',
                labelStyle: RatnexTheme.label(size: 12),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: RatnexTheme.label(size: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(
              'Mark redeemed',
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
    if (billNo == null || billNo.isEmpty || !mounted) return;
    await _service.redeemMember(
      schemeId: scheme.id,
      member: member,
      billNo: billNo,
    );
    if (mounted) RatnexSnack.success(context, 'Marked redeemed');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SavingsScheme?>(
      stream: _service.watchScheme(widget.schemeId),
      builder: (context, schemeSnap) {
        final scheme = schemeSnap.data;
        return StreamBuilder<List<SchemeMember>>(
          stream: _service.watchMembers(widget.schemeId),
          builder: (context, memberSnap) {
            SchemeMember? member;
            for (final m in memberSnap.data ?? const <SchemeMember>[]) {
              if (m.id == widget.memberId) member = m;
            }

            if (scheme == null || member == null) {
              return RatnexPageScaffold(
                title: 'Member',
                subtitle: memberSnap.hasData ? 'Not found' : 'Loading…',
                showBack: true,
                body: memberSnap.hasData && schemeSnap.hasData
                    ? RatnexEmptyState(
                        icon: Icons.help_outline,
                        title: 'Member not found',
                        message: 'They may have been removed from this scheme.',
                      )
                    : const RatnexListSkeleton(rows: 3),
              );
            }

            final m = member;
            final maturity = ShopSchemesService.maturityValue(scheme, m);
            final bonus = scheme.bonusAmountFor(m.paidAmount, m.paidCount);
            final remaining =
                (scheme.durationMonths - m.paidCount).clamp(0, 999);

            return RatnexPageScaffold(
              title: m.name,
              subtitle: '${m.memberNo} · ${scheme.name}',
              showBack: true,
              trailing: IconButton(
                tooltip: 'WhatsApp statement',
                onPressed: () async {
                  final message = [
                    'Namaste ${m.name} 🙏',
                    '',
                    '${scheme.name} passbook',
                    'Member no: ${m.memberNo}',
                    'Paid: ${m.paidCount} of ${scheme.durationMonths} installments',
                    'Total paid: ${RatnexFormat.money(m.paidAmount)}',
                    if (m.gramsAccrued > 0)
                      'Gold accrued: ${RatnexFormat.grams(m.gramsAccrued)}',
                    'Value at maturity: ${RatnexFormat.money(maturity)}',
                    if (m.maturesAt != null)
                      'Matures on: ${RatnexFormat.date(m.maturesAt)}',
                  ].join('\n');
                  final ok = await WhatsAppService.send(m.phone, message);
                  if (!ok && context.mounted) {
                    await WhatsAppService.copy(message);
                    if (context.mounted) {
                      RatnexSnack.show(context, 'Statement copied');
                    }
                  }
                },
                icon: const Icon(
                  Icons.chat_outlined,
                  color: Color(0xFF25D366),
                  size: 21,
                ),
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: RatnexColors.rateBoard,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VALUE AT MATURITY',
                          style: RatnexTheme.label(
                            size: 10.5,
                            weight: FontWeight.w700,
                            color: RatnexColors.rateAccent,
                          ).copyWith(letterSpacing: 0.6),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          RatnexFormat.money(maturity),
                          style: RatnexTheme.money(
                            size: 32,
                            color: RatnexColors.onRateBoard,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${RatnexFormat.money(m.paidAmount)} paid + ${RatnexFormat.money(bonus)} bonus'
                          '${m.gramsAccrued > 0 ? ' · ${RatnexFormat.grams(m.gramsAccrued)} accrued' : ''}',
                          style: RatnexTheme.label(
                            size: 12,
                            color: RatnexColors.rateAccent,
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
                          label: 'Installments',
                          value: '${m.paidCount}/${scheme.durationMonths}',
                          caption: remaining == 0
                              ? 'Complete'
                              : '$remaining left',
                          icon: Icons.event_available_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RatnexStatTile(
                          label: 'Next due',
                          value: m.nextDueAt == null
                              ? '—'
                              : RatnexFormat.shortDate(m.nextDueAt),
                          caption: m.isDue
                              ? '${m.daysOverdue}d overdue'
                              : 'On track',
                          icon: Icons.schedule,
                          accent:
                              m.isDue ? RatnexColors.down : RatnexColors.up,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RatnexStatTile(
                          label: 'Matures',
                          value: RatnexFormat.shortDate(m.maturesAt),
                          caption: m.status == 'redeemed'
                              ? 'Redeemed'
                              : m.status == 'matured'
                                  ? 'Ready'
                                  : 'Saving',
                          icon: Icons.flag_outlined,
                          accent: RatnexColors.violet,
                        ),
                      ),
                    ],
                  ),
                  if (m.status == 'matured') ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => _redeem(scheme, m),
                      icon: const Icon(Icons.redeem, size: 18),
                      label: const Text('Redeem against a bill'),
                      style: FilledButton.styleFrom(
                        backgroundColor: RatnexColors.up,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                  if (m.status == 'redeemed' && m.redeemedBillNo != null) ...[
                    const SizedBox(height: 14),
                    RatnexNotice(
                      message:
                          'Redeemed on ${RatnexFormat.date(m.redeemedAt)} against bill ${m.redeemedBillNo}.',
                      color: RatnexColors.up,
                      icon: Icons.check_circle_outline,
                    ),
                  ],
                  const SizedBox(height: 18),
                  const RatnexSectionLabel(text: 'PASSBOOK'),
                  const SizedBox(height: 10),
                  StreamBuilder<List<SchemeInstallment>>(
                    stream: _service.watchInstallments(scheme.id, m.id),
                    builder: (context, instSnap) {
                      final installments =
                          instSnap.data ?? const <SchemeInstallment>[];
                      if (!instSnap.hasData) {
                        return const RatnexListSkeleton(rows: 3);
                      }
                      if (installments.isEmpty) {
                        return RatnexEmptyState(
                          icon: Icons.receipt_outlined,
                          title: 'No installments yet',
                          message:
                              'Collect the first installment from the scheme screen.',
                        );
                      }
                      return Column(
                        children: installments
                            .map(
                              (i) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _InstallmentTile(
                                  installment: i,
                                  total: scheme.durationMonths,
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
      },
    );
  }
}

class _InstallmentTile extends StatelessWidget {
  final SchemeInstallment installment;
  final int total;

  const _InstallmentTile({required this.installment, required this.total});

  @override
  Widget build(BuildContext context) {
    return RatnexCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: RatnexColors.goldSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${installment.monthIndex}',
              style: RatnexTheme.money(size: 14, color: RatnexColors.gold),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Installment ${installment.monthIndex} of $total',
                  style: RatnexTheme.label(
                    size: 13,
                    weight: FontWeight.w700,
                    color: RatnexColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    RatnexFormat.date(installment.paidAt),
                    installment.mode.toUpperCase(),
                    if (installment.ratePerGram != null &&
                        installment.ratePerGram! > 0)
                      '@ ${RatnexFormat.money(installment.ratePerGram!)}/g',
                  ].join(' · '),
                  style: RatnexTheme.label(size: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                RatnexFormat.money(installment.amount),
                style: RatnexTheme.money(size: 14),
              ),
              if (installment.grams > 0) ...[
                const SizedBox(height: 3),
                Text(
                  RatnexFormat.grams(installment.grams),
                  style: RatnexTheme.label(size: 10.5, color: RatnexColors.gold),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
