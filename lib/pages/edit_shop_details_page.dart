import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_profile_service.dart';
import '../services/stock_image_helper.dart';
import '../theme/ratnex_theme.dart';

class EditShopDetailsPage extends StatefulWidget {
  const EditShopDetailsPage({super.key});

  @override
  State<EditShopDetailsPage> createState() => _EditShopDetailsPageState();
}

class _EditShopDetailsPageState extends State<EditShopDetailsPage> {
  final _service = ShopProfileService();

  final _shopName = TextEditingController();
  final _ownerName = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _altPhone = TextEditingController();
  final _email = TextEditingController();
  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _established = TextEditingController();
  final _tagline = TextEditingController();
  final _description = TextEditingController();
  final _bis = TextEditingController();
  final _association = TextEditingController();
  final _tradeLicense = TextEditingController();
  final _openTime = TextEditingController();
  final _closeTime = TextEditingController();
  final _weeklyOff = TextEditingController();
  final _upi = TextEditingController();
  final _bankName = TextEditingController();
  final _accountName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _ifsc = TextEditingController();
  final _instagram = TextEditingController();
  final _website = TextEditingController();

  String? _shopType;
  String? _logoBase64;
  bool _saving = false;
  bool _hydrated = false;
  bool _pickingLogo = false;

  static const _shopTypes = [
    ('retail', 'Retail'),
    ('wholesale', 'Wholesale'),
    ('both', 'Retail + Wholesale'),
    ('manufacturing', 'Manufacturing'),
  ];

  @override
  void dispose() {
    for (final c in [
      _shopName,
      _ownerName,
      _phone,
      _whatsapp,
      _altPhone,
      _email,
      _address1,
      _address2,
      _city,
      _state,
      _pincode,
      _established,
      _tagline,
      _description,
      _bis,
      _association,
      _tradeLicense,
      _openTime,
      _closeTime,
      _weeklyOff,
      _upi,
      _bankName,
      _accountName,
      _accountNumber,
      _ifsc,
      _instagram,
      _website,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(ShopProfile p) {
    if (_hydrated) return;
    _hydrated = true;
    _shopName.text = p.shopName ?? '';
    _ownerName.text = p.ownerName ?? '';
    _phone.text = p.phone ?? '';
    _whatsapp.text = p.whatsapp ?? '';
    _altPhone.text = p.alternatePhone ?? '';
    _email.text = p.email ?? '';
    _address1.text = p.addressLine1 ?? '';
    _address2.text = p.addressLine2 ?? '';
    _city.text = p.city ?? '';
    _state.text = p.state ?? '';
    _pincode.text = p.pincode ?? '';
    _established.text = p.establishedYear ?? '';
    _tagline.text = p.tagline ?? '';
    _description.text = p.description ?? '';
    _bis.text = p.bisHallmarkNo ?? '';
    _association.text = p.jewellersAssociationId ?? '';
    _tradeLicense.text = p.tradeLicense ?? '';
    _openTime.text = p.openTime ?? '';
    _closeTime.text = p.closeTime ?? '';
    _weeklyOff.text = p.weeklyOff ?? '';
    _upi.text = p.upiId ?? '';
    _bankName.text = p.bankName ?? '';
    _accountName.text = p.accountName ?? '';
    _accountNumber.text = p.accountNumber ?? '';
    _ifsc.text = p.ifsc ?? '';
    _instagram.text = p.instagram ?? '';
    _website.text = p.website ?? '';
    _shopType = p.shopType;
    _logoBase64 = p.logoBase64;
  }

  Future<void> _pickLogo() async {
    setState(() => _pickingLogo = true);
    try {
      final result = await StockImageHelper.pickCompressed(
        source: ImageSource.gallery,
      );
      if (!mounted) return;
      if (result != null) {
        setState(() => _logoBase64 = result.base64);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logo failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _pickingLogo = false);
    }
  }

  Future<void> _save() async {
    if (_shopName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop name is required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.saveProfile(
        ShopProfile(
          shopName: _shopName.text,
          ownerName: _ownerName.text,
          phone: _phone.text,
          whatsapp: _whatsapp.text,
          alternatePhone: _altPhone.text,
          email: _email.text,
          addressLine1: _address1.text,
          addressLine2: _address2.text,
          city: _city.text,
          state: _state.text,
          pincode: _pincode.text,
          shopType: _shopType,
          establishedYear: _established.text,
          tagline: _tagline.text,
          description: _description.text,
          bisHallmarkNo: _bis.text,
          jewellersAssociationId: _association.text,
          tradeLicense: _tradeLicense.text,
          openTime: _openTime.text,
          closeTime: _closeTime.text,
          weeklyOff: _weeklyOff.text,
          upiId: _upi.text,
          bankName: _bankName.text,
          accountName: _accountName.text,
          accountNumber: _accountNumber.text,
          ifsc: _ifsc.text,
          instagram: _instagram.text,
          website: _website.text,
          logoBase64: _logoBase64,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop profile saved')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: RatnexColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: RatnexColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: RatnexColors.hairline),
        ),
      );

  TextStyle get _fieldStyle => RatnexTheme.label(
        size: 14,
        weight: FontWeight.w600,
        color: RatnexColors.ink,
      );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? hint,
    TextInputType? keyboard,
    int maxLines = 1,
    List<TextInputFormatter>? formatters,
    TextCapitalization caps = TextCapitalization.sentences,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: RatnexTheme.label(size: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            style: _fieldStyle,
            maxLines: maxLines,
            keyboardType: keyboard,
            inputFormatters: formatters,
            textCapitalization: caps,
            decoration: _dec(hint ?? label),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('d MMM yyyy').format(DateTime.now());
    final logoBytes = StockImageHelper.decodeBase64(_logoBase64);

    return Scaffold(
      backgroundColor: RatnexColors.surface,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            left: -40,
            right: -40,
            height: 220,
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
            child: StreamBuilder<ShopProfile>(
              stream: _service.watchProfile(),
              builder: (context, snap) {
                if (snap.hasData) _hydrate(snap.data!);
                final profile = snap.data ?? const ShopProfile();
                final pct = profile.completionPercent.round();

                return Column(
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
                                Text(
                                  'Shop details',
                                  style: RatnexTheme.brand(size: 24),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Complete profile  ·  $today',
                                  style: RatnexTheme.label(size: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                        children: [
                          _CompletionBanner(
                            percent: pct,
                            completed: profile.completedCount,
                            total: profile.totalCount,
                          ),
                          const SizedBox(height: 14),
                          _Section(
                            title: 'Shop identity',
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: _pickingLogo ? null : _pickLogo,
                                  child: Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      color: RatnexColors.goldSoft,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: RatnexColors.hairline,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: _pickingLogo
                                        ? const Center(
                                            child: CircularProgressIndicator(
                                              color: RatnexColors.gold,
                                            ),
                                          )
                                        : logoBytes != null
                                            ? Image.memory(
                                                logoBytes,
                                                fit: BoxFit.cover,
                                              )
                                            : const Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.add_a_photo_outlined,
                                                    color: RatnexColors.gold,
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    'Logo',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: RatnexColors.muted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _field('Shop name *', _shopName,
                                    hint: 'e.g. Ratnex Jewellers',
                                    caps: TextCapitalization.words),
                                _field('Owner name', _ownerName,
                                    caps: TextCapitalization.words),
                                _field('Tagline', _tagline,
                                    hint: 'Trusted since …'),
                                _field(
                                  'About shop',
                                  _description,
                                  maxLines: 3,
                                  hint: 'Short description for bills & profile',
                                ),
                                Text('Shop type',
                                    style: RatnexTheme.label(size: 12)),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final t in _shopTypes)
                                      ChoiceChip(
                                        label: Text(t.$2),
                                        selected: _shopType == t.$1,
                                        onSelected: (_) =>
                                            setState(() => _shopType = t.$1),
                                        selectedColor: RatnexColors.ink,
                                        labelStyle: RatnexTheme.label(
                                          size: 12,
                                          weight: FontWeight.w600,
                                          color: _shopType == t.$1
                                              ? Colors.white
                                              : RatnexColors.ink,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _field(
                                  'Established year',
                                  _established,
                                  hint: 'e.g. 1998',
                                  keyboard: TextInputType.number,
                                  formatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _Section(
                            title: 'Contact',
                            child: Column(
                              children: [
                                _field(
                                  'Phone',
                                  _phone,
                                  keyboard: TextInputType.phone,
                                  formatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                                _field(
                                  'WhatsApp',
                                  _whatsapp,
                                  keyboard: TextInputType.phone,
                                  formatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                                _field(
                                  'Alternate phone',
                                  _altPhone,
                                  keyboard: TextInputType.phone,
                                  formatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                                _field(
                                  'Email',
                                  _email,
                                  keyboard: TextInputType.emailAddress,
                                  caps: TextCapitalization.none,
                                ),
                                _field('Instagram', _instagram,
                                    hint: '@yourshop',
                                    caps: TextCapitalization.none),
                                _field('Website', _website,
                                    hint: 'https://',
                                    caps: TextCapitalization.none),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _Section(
                            title: 'Address',
                            child: Column(
                              children: [
                                _field('Address line 1', _address1),
                                _field('Address line 2', _address2),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _field('City', _city,
                                          caps: TextCapitalization.words),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _field('State', _state,
                                          caps: TextCapitalization.words),
                                    ),
                                  ],
                                ),
                                _field(
                                  'PIN code',
                                  _pincode,
                                  keyboard: TextInputType.number,
                                  formatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _Section(
                            title: 'Business hours',
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _field('Opens', _openTime,
                                          hint: '10:00 AM'),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _field('Closes', _closeTime,
                                          hint: '8:00 PM'),
                                    ),
                                  ],
                                ),
                                _field('Weekly off', _weeklyOff,
                                    hint: 'e.g. Tuesday'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _Section(
                            title: 'Licenses & compliance',
                            child: Column(
                              children: [
                                _field('BIS / Hallmark no.', _bis),
                                _field(
                                  'Jewellers association ID',
                                  _association,
                                ),
                                _field('Trade license', _tradeLicense),
                                Text(
                                  'Add GSTIN from Profile → GST (counts toward completion).',
                                  style: RatnexTheme.label(size: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _Section(
                            title: 'Payments',
                            child: Column(
                              children: [
                                _field('UPI ID', _upi,
                                    hint: 'shop@upi',
                                    caps: TextCapitalization.none),
                                _field('Bank name', _bankName,
                                    caps: TextCapitalization.words),
                                _field('Account name', _accountName,
                                    caps: TextCapitalization.words),
                                _field(
                                  'Account number',
                                  _accountNumber,
                                  keyboard: TextInputType.number,
                                  formatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                                _field(
                                  'IFSC',
                                  _ifsc,
                                  caps: TextCapitalization.characters,
                                ),
                              ],
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
                                _saving ? 'Saving…' : 'Save shop profile',
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
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionBanner extends StatelessWidget {
  final int percent;
  final int completed;
  final int total;

  const _CompletionBanner({
    required this.percent,
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return RatnexPanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Profile completion',
                    style: RatnexTheme.label(
                      size: 13,
                      weight: FontWeight.w700,
                      color: RatnexColors.ink,
                    ),
                  ),
                ),
                Text(
                  '$percent%',
                  style: RatnexTheme.money(size: 18, color: RatnexColors.gold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : completed / total,
                minHeight: 8,
                backgroundColor: RatnexColors.hairline,
                color: percent >= 100 ? RatnexColors.up : RatnexColors.gold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$completed of $total details filled',
              style: RatnexTheme.label(size: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: RatnexColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RatnexColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: RatnexTheme.label(
              size: 11,
              weight: FontWeight.w700,
              color: RatnexColors.muted,
            ).copyWith(letterSpacing: 0.4),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
