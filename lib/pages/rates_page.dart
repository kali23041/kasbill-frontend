import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/ratnex_page_scaffold.dart';
import '../services/ibja_rates_service.dart';
import '../theme/ratnex_theme.dart';

class RatesPage extends StatefulWidget {
  const RatesPage({super.key});

  @override
  State<RatesPage> createState() => _RatesPageState();
}

class _RatesPageState extends State<RatesPage> {
  final _service = IbjaRatesService();
  IbjaRates? _rates;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rates = await _service.fetchLatest();
      if (!mounted) return;
      setState(() {
        _rates = rates;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load IBJA rates';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final dateLabel = _rates == null
        ? DateFormat('d MMM yyyy').format(DateTime.now())
        : DateFormat('d MMM yyyy').format(_rates!.date);

    return RatnexPageScaffold(
      title: 'Rates',
      subtitle: 'IBJA benchmark  ·  $dateLabel',
      onRefresh: _load,
      trailing: RatnexHeaderChip(
        label: _loading ? '...' : (_rates?.session ?? '—'),
        color: RatnexColors.up,
        onTap: _loading ? null : _load,
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: CircularProgressIndicator(color: RatnexColors.gold),
              ),
            )
          : _error != null || _rates == null
              ? Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    children: [
                      Text(
                        _error ?? 'Rates unavailable',
                        style: RatnexTheme.label(size: 13),
                      ),
                      const SizedBox(height: 12),
                      RatnexPrimaryButton(
                        label: 'Retry',
                        icon: Icons.refresh,
                        onTap: _load,
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Same dark rate board language as home
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                      decoration: BoxDecoration(
                        color: RatnexColors.rateBoard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _BoardCol(
                              label: '22K Gold',
                              value: currency
                                  .format(_rates!.gold22kPerGram.round()),
                              delta: _rates!.delta22kPct,
                            ),
                          ),
                          Container(width: 1, height: 48, color: Colors.white12),
                          Expanded(
                            child: _BoardCol(
                              label: '24K Gold',
                              value: currency
                                  .format(_rates!.gold24kPerGram.round()),
                              delta: _rates!.delta24kPct,
                            ),
                          ),
                          Container(width: 1, height: 48, color: Colors.white12),
                          Expanded(
                            child: _BoardCol(
                              label: 'Silver',
                              value: currency
                                  .format(_rates!.silverPerGram.round()),
                              delta: _rates!.deltaSilverPct,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const RatnexSectionLabel(text: 'Rate details'),
                    const SizedBox(height: 8),
                    RatnexPanel(
                      child: Column(
                        children: [
                          _DetailRow(
                            title: '22K Gold (916)',
                            value: currency
                                .format(_rates!.gold22kPerGram.round()),
                            note: 'Jewellery standard',
                          ),
                          const Divider(
                            height: 1,
                            indent: 12,
                            endIndent: 12,
                            color: RatnexColors.hairline,
                          ),
                          _DetailRow(
                            title: '24K Gold (999)',
                            value: currency
                                .format(_rates!.gold24kPerGram.round()),
                            note: 'Investment grade',
                          ),
                          const Divider(
                            height: 1,
                            indent: 12,
                            endIndent: 12,
                            color: RatnexColors.hairline,
                          ),
                          _DetailRow(
                            title: 'Silver (999)',
                            value:
                                currency.format(_rates!.silverPerGram.round()),
                            note: 'Converted from IBJA per kg',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Source: IBJA India. Shop selling rates may differ from benchmark.',
                      style: RatnexTheme.label(size: 11),
                    ),
                    const SizedBox(height: 12),
                    RatnexPrimaryButton(
                      label: 'Refresh rates',
                      icon: Icons.refresh,
                      onTap: _load,
                    ),
                  ],
                ),
    );
  }
}

class _BoardCol extends StatelessWidget {
  final String label;
  final String value;
  final double? delta;

  const _BoardCol({
    required this.label,
    required this.value,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final up = (delta ?? 0) >= 0;
    final deltaColor = up ? const Color(0xFF6FCF97) : const Color(0xFFFF8A80);

    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: RatnexTheme.label(
            size: 10,
            weight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.55),
          ).copyWith(letterSpacing: 0.6),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: RatnexTheme.money(
                  size: 16,
                  color: RatnexColors.rateAccent,
                ),
              ),
              TextSpan(
                text: '/g',
                style: RatnexTheme.label(
                  size: 11,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
        if (delta != null) ...[
          const SizedBox(height: 4),
          Text(
            '${up ? '+' : ''}${delta!.toStringAsFixed(2)}%',
            style: RatnexTheme.label(
              size: 11,
              weight: FontWeight.w600,
              color: deltaColor,
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String title;
  final String value;
  final String note;

  const _DetailRow({
    required this.title,
    required this.value,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: RatnexTheme.label(
                    size: 13,
                    weight: FontWeight.w600,
                    color: RatnexColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(note, style: RatnexTheme.label(size: 11)),
              ],
            ),
          ),
          Text('$value/g', style: RatnexTheme.money(size: 15)),
        ],
      ),
    );
  }
}
