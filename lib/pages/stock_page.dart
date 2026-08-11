import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_rates_service.dart';
import '../services/shop_stock_service.dart';
import '../services/stock_image_helper.dart';
import '../theme/ratnex_theme.dart';
import 'add_stock_item_page.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final _stockService = ShopStockService();
  final _ratesService = ShopRatesService();
  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// Default to grid; toggle in header switches list ↔ grid.
  bool _isGridView = true;

  Future<void> _confirmDelete(StockItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Remove “${item.name}” from stock?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
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
    if (ok == true) {
      await _stockService.deleteItem(item.id);
    }
  }

  void _openItem(StockItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddStockItemPage(existing: item),
      ),
    );
  }

  Map<String, ShopMetalRate> _metalsMap(List<ShopMetalRate>? metals) {
    final map = <String, ShopMetalRate>{};
    for (final m in metals ?? const <ShopMetalRate>[]) {
      map[m.id] = m;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('d MMM yyyy').format(DateTime.now());

    return StreamBuilder<List<ShopMetalRate>>(
      stream: _ratesService.watchMetals(),
      builder: (context, metalSnap) {
        final metalsById = _metalsMap(metalSnap.data);

        return StreamBuilder<List<StockItem>>(
          stream: _stockService.watchStock(),
          builder: (context, snap) {
            final items = snap.data ?? const <StockItem>[];
            final lowCount = items.where((i) => i.isLow).length;
            final portfolio = StockValuation.portfolio(items, metalsById);

            return RatnexPageScaffold(
              title: 'Stock',
              subtitle: 'Inventory  ·  $today',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RatnexHeaderChip(
                    label: lowCount > 0 ? '$lowCount low' : 'OK',
                    color: lowCount > 0 ? RatnexColors.down : RatnexColors.up,
                  ),
                  const SizedBox(width: 8),
                  _ViewToggle(
                    isGrid: _isGridView,
                    onChanged: (grid) => setState(() => _isGridView = grid),
                  ),
                ],
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RatnexPrimaryButton(
                    label: 'Add stock item',
                    icon: Icons.add,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddStockItemPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _PortfolioStats(
                    itemCount: items.where((i) => i.status != 'sold').length,
                    lowCount: lowCount,
                    portfolio: portfolio,
                    currency: _currency,
                    ready: snap.hasData,
                  ),
                  const SizedBox(height: 16),
                  RatnexSectionLabel(
                    text: _isGridView ? 'Inventory grid' : 'Inventory list',
                  ),
                  const SizedBox(height: 8),
                  if (snap.hasError)
                    RatnexPanel(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Could not load stock: ${snap.error}',
                          style: RatnexTheme.label(size: 13),
                        ),
                      ),
                    )
                  else if (!snap.hasData)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: RatnexColors.gold,
                        ),
                      ),
                    )
                  else if (items.isEmpty)
                    RatnexPanel(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              size: 32,
                              color: RatnexColors.gold,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No stock items yet',
                              style: RatnexTheme.label(
                                size: 15,
                                weight: FontWeight.w700,
                                color: RatnexColors.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Add metals and categories in Profile first, then create stock items for billing.',
                              textAlign: TextAlign.center,
                              style: RatnexTheme.label(size: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_isGridView)
                    _StockGrid(
                      items: items,
                      metalsById: metalsById,
                      currency: _currency,
                      onOpen: _openItem,
                      onDelete: _confirmDelete,
                    )
                  else
                    _StockList(
                      items: items,
                      metalsById: metalsById,
                      currency: _currency,
                      onOpen: _openItem,
                      onDelete: _confirmDelete,
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

class _PortfolioStats extends StatelessWidget {
  final int itemCount;
  final int lowCount;
  final StockValuation portfolio;
  final NumberFormat currency;
  final bool ready;

  const _PortfolioStats({
    required this.itemCount,
    required this.lowCount,
    required this.portfolio,
    required this.currency,
    required this.ready,
  });

  @override
  Widget build(BuildContext context) {
    final pct = portfolio.changePct;
    final pctColor = pct.abs() < 0.05
        ? RatnexColors.muted
        : (pct >= 0 ? RatnexColors.up : RatnexColors.down);
    final pctLabel = ready
        ? '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%'
        : '—';

    return RatnexPanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Items',
                    value: ready ? '$itemCount' : '—',
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: RatnexColors.hairline,
                ),
                Expanded(
                  child: _Metric(
                    label: 'Low',
                    value: ready ? '$lowCount' : '—',
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: RatnexColors.hairline,
                ),
                Expanded(
                  child: _Metric(
                    label: 'Today',
                    value: ready
                        ? currency.format(portfolio.todayLine.round())
                        : '—',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    ready
                        ? 'At add ${currency.format(portfolio.addedLine.round())}'
                        : 'At add —',
                    style: RatnexTheme.label(size: 11),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: pctColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pctLabel,
                    style: RatnexTheme.label(
                      size: 11,
                      weight: FontWeight.w700,
                      color: pctColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PctBadge extends StatelessWidget {
  final double changePct;

  const _PctBadge({required this.changePct});

  @override
  Widget build(BuildContext context) {
    final abs = changePct.abs();
    final color = abs < 0.05
        ? RatnexColors.muted
        : (changePct >= 0 ? RatnexColors.up : RatnexColors.down);
    final label = abs < 0.05
        ? '0%'
        : '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: RatnexTheme.label(
          size: 10,
          weight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final bool isGrid;
  final ValueChanged<bool> onChanged;

  const _ViewToggle({
    required this.isGrid,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: RatnexColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RatnexColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(
            icon: Icons.grid_view_rounded,
            selected: isGrid,
            onTap: () => onChanged(true),
          ),
          _ToggleBtn(
            icon: Icons.view_list_rounded,
            selected: !isGrid,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? RatnexColors.ink : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 16,
            color: selected ? Colors.white : RatnexColors.muted,
          ),
        ),
      ),
    );
  }
}

class _StockGrid extends StatelessWidget {
  final List<StockItem> items;
  final Map<String, ShopMetalRate> metalsById;
  final NumberFormat currency;
  final ValueChanged<StockItem> onOpen;
  final ValueChanged<StockItem> onDelete;

  const _StockGrid({
    required this.items,
    required this.metalsById,
    required this.currency,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.66,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final val = StockValuation.forItem(item, metalsById);
        final low = item.isLow;
        final thumb = StockImageHelper.decodeBase64(item.imageBase64);
        final addedStr = item.createdAt != null
            ? DateFormat('d MMM').format(item.createdAt!)
            : 'added';

        return Material(
          color: RatnexColors.panel,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onOpen(item),
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: RatnexColors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(11),
                          ),
                          child: thumb != null
                              ? Image.memory(thumb, fit: BoxFit.cover)
                              : Container(
                                  color: RatnexColors.goldSoft,
                                  child: const Icon(
                                    Icons.diamond_outlined,
                                    color: RatnexColors.gold,
                                    size: 36,
                                  ),
                                ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => onDelete(item),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: RatnexColors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (low ? RatnexColors.down : RatnexColors.up)
                                  .withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              item.statusLabel,
                              style: RatnexTheme.label(
                                size: 10,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
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
                          item.categoryName.isEmpty
                              ? item.metalLabel
                              : item.categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RatnexTheme.label(size: 11),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                currency.format(val.todayUnit.round()),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: RatnexTheme.money(
                                  size: 14,
                                  color: RatnexColors.gold,
                                ),
                              ),
                            ),
                            _PctBadge(changePct: val.changePct),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${currency.format(val.addedUnit.round())} · $addedStr',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RatnexTheme.label(size: 10),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.quantity} ${item.unit}',
                          style: RatnexTheme.label(
                            size: 11,
                            weight: FontWeight.w600,
                            color: RatnexColors.ink,
                          ),
                        ),
                      ],
                    ),
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

class _StockList extends StatelessWidget {
  final List<StockItem> items;
  final Map<String, ShopMetalRate> metalsById;
  final NumberFormat currency;
  final ValueChanged<StockItem> onOpen;
  final ValueChanged<StockItem> onDelete;

  const _StockList({
    required this.items,
    required this.metalsById,
    required this.currency,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return RatnexPanel(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'ITEM',
                    style: RatnexTheme.label(
                      size: 10,
                      weight: FontWeight.w700,
                    ).copyWith(letterSpacing: 0.5),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'TODAY',
                    style: RatnexTheme.label(
                      size: 10,
                      weight: FontWeight.w700,
                    ).copyWith(letterSpacing: 0.5),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'CHG',
                    style: RatnexTheme.label(
                      size: 10,
                      weight: FontWeight.w700,
                    ).copyWith(letterSpacing: 0.5),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: RatnexColors.hairline,
          ),
          ...List.generate(items.length, (index) {
            final item = items[index];
            final val = StockValuation.forItem(item, metalsById);
            final low = item.isLow;
            final thumb = StockImageHelper.decodeBase64(item.imageBase64);
            final addedStr = item.createdAt != null
                ? DateFormat('d MMM').format(item.createdAt!)
                : 'added';

            return Column(
              children: [
                InkWell(
                  onTap: () => onOpen(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: RatnexColors.goldSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: thumb != null
                              ? Image.memory(thumb, fit: BoxFit.cover)
                              : const Icon(
                                  Icons.diamond_outlined,
                                  size: 18,
                                  color: RatnexColors.gold,
                                ),
                        ),
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: RatnexTheme.label(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: RatnexColors.ink,
                                ),
                              ),
                              Text(
                                '${item.quantity} ${item.unit} · ${low ? 'Low' : item.statusLabel}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: RatnexTheme.label(size: 10),
                              ),
                              Text(
                                '${currency.format(val.addedUnit.round())} · $addedStr',
                                style: RatnexTheme.label(size: 10),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            currency.format(val.todayUnit.round()),
                            style: RatnexTheme.money(
                              size: 12,
                              color: RatnexColors.gold,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _PctBadge(changePct: val.changePct),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed: () => onDelete(item),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: RatnexColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (index != items.length - 1)
                  const Divider(
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

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: RatnexTheme.money(size: 16),
        ),
        const SizedBox(height: 2),
        Text(label, style: RatnexTheme.label(size: 11)),
      ],
    );
  }
}
