import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_gst_service.dart';
import '../theme/ratnex_theme.dart';

class GstPage extends StatefulWidget {
  const GstPage({super.key});

  @override
  State<GstPage> createState() => _GstPageState();
}

class _GstPageState extends State<GstPage> {
  final _service = ShopGstService();
  final _gstCtrl = TextEditingController();
  final _percentCtrl = TextEditingController(text: '3');
  bool _saving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _gstCtrl.dispose();
    _percentCtrl.dispose();
    super.dispose();
  }

  void _hydrate(ShopGstSettings settings) {
    if (_loaded) return;
    _loaded = true;
    _gstCtrl.text = settings.gstNumber ?? '';
    _percentCtrl.text = settings.gstPercent == settings.gstPercent.roundToDouble()
        ? settings.gstPercent.round().toString()
        : settings.gstPercent.toString();
  }

  Future<void> _save() async {
    final number = _gstCtrl.text.trim().toUpperCase();
    final percent = double.tryParse(_percentCtrl.text.trim());
    if (number.length != 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 15-character GSTIN')),
      );
      return;
    }
    if (percent == null || percent < 0 || percent > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid GST %')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.saveSettings(gstNumber: number, gstPercent: percent);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GST settings saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove GST?'),
        content: const Text(
          'Stock items will no longer show the GST enable option until you add a GSTIN again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Remove',
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
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      await _service.clearSettings();
      if (!mounted) return;
      setState(() {
        _gstCtrl.clear();
        _percentCtrl.text = '3';
        _loaded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GST settings removed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('d MMM yyyy').format(DateTime.now());

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
            child: Column(
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('GST', style: RatnexTheme.brand(size: 26)),
                            const SizedBox(height: 2),
                            Text(
                              'Tax settings  ·  $today',
                              style: RatnexTheme.label(size: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<ShopGstSettings>(
                    stream: _service.watchSettings(),
                    builder: (context, snap) {
                      if (snap.hasData) _hydrate(snap.data!);

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                        children: [
                          RatnexPanel(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(
                                'Add your shop GSTIN here. After saving, you can enable or disable GST on each stock item.',
                                style: RatnexTheme.label(size: 13),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const RatnexSectionLabel(text: 'GST details'),
                          const SizedBox(height: 8),
                          RatnexPanel(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'GSTIN *',
                                    style: RatnexTheme.label(size: 12),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _gstCtrl,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    maxLength: 15,
                                    style: RatnexTheme.label(
                                      size: 14,
                                      weight: FontWeight.w700,
                                      color: RatnexColors.ink,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '15-character GSTIN',
                                      counterText: '',
                                      filled: true,
                                      fillColor: RatnexColors.surface,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: RatnexColors.hairline,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: RatnexColors.hairline,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Default GST %',
                                    style: RatnexTheme.label(size: 12),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _percentCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'),
                                      ),
                                    ],
                                    style: RatnexTheme.label(
                                      size: 14,
                                      weight: FontWeight.w600,
                                      color: RatnexColors.ink,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. 3',
                                      filled: true,
                                      fillColor: RatnexColors.surface,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: RatnexColors.hairline,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: RatnexColors.hairline,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (snap.data?.isConfigured == true) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'Saved · GST options unlocked on stock items',
                                      style: RatnexTheme.label(
                                        size: 12,
                                        weight: FontWeight.w600,
                                        color: RatnexColors.up,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RatnexColors.ink,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                _saving ? 'Saving…' : 'Save GST',
                                style: RatnexTheme.label(
                                  size: 14,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          if (snap.data?.isConfigured == true) ...[
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _saving ? null : _clear,
                              child: Text(
                                'Remove GST settings',
                                style: RatnexTheme.label(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: RatnexColors.down,
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
