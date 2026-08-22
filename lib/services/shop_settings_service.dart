import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_helpers.dart';
import '../utils/ratnex_format.dart';

/// Shop-wide preferences stored at `users/{email}/settings/preferences`.
///
/// A subcollection rather than fields on the user document so nothing here can
/// collide with the production `plan` / `shopProfile` / `gstNumber` fields.
class ShopSettings {
  // Invoice numbering
  final bool sequentialInvoiceNo;
  final String invoicePrefix;
  final int invoicePadding;
  final bool includeFinancialYear;

  // Documents
  final String printerFormat; // a4 | thermal80 | thermal58
  final bool showAmountInWords;
  final bool showHsnSummary;
  final bool roundOffTotals;
  final String? invoiceTerms;
  final String? invoiceFooter;

  // Compliance
  final bool warnCash269ST;
  final bool requirePanAboveLimit;
  final bool requireKycOnGirvi;
  final bool validateHuid;

  // Behaviour
  final bool lockRateOnBill;
  final bool autoSaveDrafts;
  final int deadStockDays;
  final int lowStockThreshold;
  final double defaultGirviInterest;
  final int udhaarDueDays;

  // Reminders
  final bool remindGirviDue;
  final bool remindUdhaar;
  final bool remindSchemeInstallment;
  final bool remindDailyCash;
  final bool remindRateChange;
  final double rateChangeThreshold;

  const ShopSettings({
    this.sequentialInvoiceNo = false,
    this.invoicePrefix = 'RTX',
    this.invoicePadding = 4,
    this.includeFinancialYear = true,
    this.printerFormat = 'a4',
    this.showAmountInWords = true,
    this.showHsnSummary = true,
    this.roundOffTotals = true,
    this.invoiceTerms,
    this.invoiceFooter,
    this.warnCash269ST = true,
    this.requirePanAboveLimit = true,
    this.requireKycOnGirvi = true,
    this.validateHuid = true,
    this.lockRateOnBill = true,
    this.autoSaveDrafts = true,
    this.deadStockDays = 90,
    this.lowStockThreshold = 2,
    this.defaultGirviInterest = 24,
    this.udhaarDueDays = 30,
    this.remindGirviDue = true,
    this.remindUdhaar = true,
    this.remindSchemeInstallment = true,
    this.remindDailyCash = true,
    this.remindRateChange = false,
    this.rateChangeThreshold = 50,
  });

  static const defaults = ShopSettings();

  ShopSettings copyWith({
    bool? sequentialInvoiceNo,
    String? invoicePrefix,
    int? invoicePadding,
    bool? includeFinancialYear,
    String? printerFormat,
    bool? showAmountInWords,
    bool? showHsnSummary,
    bool? roundOffTotals,
    String? invoiceTerms,
    String? invoiceFooter,
    bool? warnCash269ST,
    bool? requirePanAboveLimit,
    bool? requireKycOnGirvi,
    bool? validateHuid,
    bool? lockRateOnBill,
    bool? autoSaveDrafts,
    int? deadStockDays,
    int? lowStockThreshold,
    double? defaultGirviInterest,
    int? udhaarDueDays,
    bool? remindGirviDue,
    bool? remindUdhaar,
    bool? remindSchemeInstallment,
    bool? remindDailyCash,
    bool? remindRateChange,
    double? rateChangeThreshold,
  }) {
    return ShopSettings(
      sequentialInvoiceNo: sequentialInvoiceNo ?? this.sequentialInvoiceNo,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      invoicePadding: invoicePadding ?? this.invoicePadding,
      includeFinancialYear: includeFinancialYear ?? this.includeFinancialYear,
      printerFormat: printerFormat ?? this.printerFormat,
      showAmountInWords: showAmountInWords ?? this.showAmountInWords,
      showHsnSummary: showHsnSummary ?? this.showHsnSummary,
      roundOffTotals: roundOffTotals ?? this.roundOffTotals,
      invoiceTerms: invoiceTerms ?? this.invoiceTerms,
      invoiceFooter: invoiceFooter ?? this.invoiceFooter,
      warnCash269ST: warnCash269ST ?? this.warnCash269ST,
      requirePanAboveLimit: requirePanAboveLimit ?? this.requirePanAboveLimit,
      requireKycOnGirvi: requireKycOnGirvi ?? this.requireKycOnGirvi,
      validateHuid: validateHuid ?? this.validateHuid,
      lockRateOnBill: lockRateOnBill ?? this.lockRateOnBill,
      autoSaveDrafts: autoSaveDrafts ?? this.autoSaveDrafts,
      deadStockDays: deadStockDays ?? this.deadStockDays,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      defaultGirviInterest: defaultGirviInterest ?? this.defaultGirviInterest,
      udhaarDueDays: udhaarDueDays ?? this.udhaarDueDays,
      remindGirviDue: remindGirviDue ?? this.remindGirviDue,
      remindUdhaar: remindUdhaar ?? this.remindUdhaar,
      remindSchemeInstallment:
          remindSchemeInstallment ?? this.remindSchemeInstallment,
      remindDailyCash: remindDailyCash ?? this.remindDailyCash,
      remindRateChange: remindRateChange ?? this.remindRateChange,
      rateChangeThreshold: rateChangeThreshold ?? this.rateChangeThreshold,
    );
  }

  factory ShopSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return defaults;
    const d = defaults;
    return ShopSettings(
      sequentialInvoiceNo:
          m['sequentialInvoiceNo'] as bool? ?? d.sequentialInvoiceNo,
      invoicePrefix: (m['invoicePrefix'] as String?)?.trim().isNotEmpty == true
          ? (m['invoicePrefix'] as String).trim()
          : d.invoicePrefix,
      invoicePadding: (m['invoicePadding'] as num?)?.toInt() ?? d.invoicePadding,
      includeFinancialYear:
          m['includeFinancialYear'] as bool? ?? d.includeFinancialYear,
      printerFormat: (m['printerFormat'] as String?) ?? d.printerFormat,
      showAmountInWords:
          m['showAmountInWords'] as bool? ?? d.showAmountInWords,
      showHsnSummary: m['showHsnSummary'] as bool? ?? d.showHsnSummary,
      roundOffTotals: m['roundOffTotals'] as bool? ?? d.roundOffTotals,
      invoiceTerms: m['invoiceTerms'] as String?,
      invoiceFooter: m['invoiceFooter'] as String?,
      warnCash269ST: m['warnCash269ST'] as bool? ?? d.warnCash269ST,
      requirePanAboveLimit:
          m['requirePanAboveLimit'] as bool? ?? d.requirePanAboveLimit,
      requireKycOnGirvi:
          m['requireKycOnGirvi'] as bool? ?? d.requireKycOnGirvi,
      validateHuid: m['validateHuid'] as bool? ?? d.validateHuid,
      lockRateOnBill: m['lockRateOnBill'] as bool? ?? d.lockRateOnBill,
      autoSaveDrafts: m['autoSaveDrafts'] as bool? ?? d.autoSaveDrafts,
      deadStockDays: (m['deadStockDays'] as num?)?.toInt() ?? d.deadStockDays,
      lowStockThreshold:
          (m['lowStockThreshold'] as num?)?.toInt() ?? d.lowStockThreshold,
      defaultGirviInterest: (m['defaultGirviInterest'] as num?)?.toDouble() ??
          d.defaultGirviInterest,
      udhaarDueDays: (m['udhaarDueDays'] as num?)?.toInt() ?? d.udhaarDueDays,
      remindGirviDue: m['remindGirviDue'] as bool? ?? d.remindGirviDue,
      remindUdhaar: m['remindUdhaar'] as bool? ?? d.remindUdhaar,
      remindSchemeInstallment:
          m['remindSchemeInstallment'] as bool? ?? d.remindSchemeInstallment,
      remindDailyCash: m['remindDailyCash'] as bool? ?? d.remindDailyCash,
      remindRateChange: m['remindRateChange'] as bool? ?? d.remindRateChange,
      rateChangeThreshold: (m['rateChangeThreshold'] as num?)?.toDouble() ??
          d.rateChangeThreshold,
    );
  }

  Map<String, dynamic> toMap() => {
        'sequentialInvoiceNo': sequentialInvoiceNo,
        'invoicePrefix': invoicePrefix,
        'invoicePadding': invoicePadding,
        'includeFinancialYear': includeFinancialYear,
        'printerFormat': printerFormat,
        'showAmountInWords': showAmountInWords,
        'showHsnSummary': showHsnSummary,
        'roundOffTotals': roundOffTotals,
        'invoiceTerms': invoiceTerms,
        'invoiceFooter': invoiceFooter,
        'warnCash269ST': warnCash269ST,
        'requirePanAboveLimit': requirePanAboveLimit,
        'requireKycOnGirvi': requireKycOnGirvi,
        'validateHuid': validateHuid,
        'lockRateOnBill': lockRateOnBill,
        'autoSaveDrafts': autoSaveDrafts,
        'deadStockDays': deadStockDays,
        'lowStockThreshold': lowStockThreshold,
        'defaultGirviInterest': defaultGirviInterest,
        'udhaarDueDays': udhaarDueDays,
        'remindGirviDue': remindGirviDue,
        'remindUdhaar': remindUdhaar,
        'remindSchemeInstallment': remindSchemeInstallment,
        'remindDailyCash': remindDailyCash,
        'remindRateChange': remindRateChange,
        'rateChangeThreshold': rateChangeThreshold,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class ShopSettingsService {
  ShopSettingsService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const preferencesDocId = 'preferences';
  static const invoiceCounterDocId = 'invoiceCounter';

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  /// users/{email}/settings/{docId}
  CollectionReference<Map<String, dynamic>>? _settings() =>
      _userRef()?.collection('settings');

  Stream<ShopSettings> watchSettings() {
    final col = _settings();
    if (col == null) return Stream.value(ShopSettings.defaults);
    return col
        .doc(preferencesDocId)
        .snapshots()
        .map((s) => ShopSettings.fromMap(s.data()));
  }

  Future<ShopSettings> getSettings() async {
    final col = _settings();
    if (col == null) return ShopSettings.defaults;
    try {
      final snap = await col.doc(preferencesDocId).get();
      return ShopSettings.fromMap(snap.data());
    } catch (_) {
      return ShopSettings.defaults;
    }
  }

  Future<void> save(ShopSettings settings) async {
    final col = _settings();
    if (col == null) throw Exception('Not signed in');
    await col
        .doc(preferencesDocId)
        .set(settings.toMap(), SetOptions(merge: true));
  }

  Future<void> patch(Map<String, dynamic> fields) async {
    final col = _settings();
    if (col == null) throw Exception('Not signed in');
    await col.doc(preferencesDocId).set(
      {...fields, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  /// Allocates the next invoice number in a gap-free per-financial-year series,
  /// e.g. `RTX/25-26/0001`. GST rules expect a continuous series, so the
  /// counter is bumped inside a transaction.
  ///
  /// Stored at `users/{email}/settings/invoiceCounter` as `{ "25-26": 41 }`.
  Future<String> nextInvoiceNumber({DateTime? at}) async {
    final col = _settings();
    if (col == null) throw Exception('Not signed in');
    final settings = await getSettings();
    final date = at ?? DateTime.now();
    final fy = RatnexFormat.financialYear(date);
    final ref = col.doc(invoiceCounterDocId);

    final seq = await _firestore.runTransaction<int>((txn) async {
      final snap = await txn.get(ref);
      final data = snap.data() ?? <String, dynamic>{};
      final current = (data[fy] as num?)?.toInt() ?? 0;
      final next = current + 1;
      txn.set(
        ref,
        {fy: next, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      return next;
    });

    final padded = seq.toString().padLeft(settings.invoicePadding, '0');
    final parts = <String>[
      settings.invoicePrefix,
      if (settings.includeFinancialYear) fy,
      padded,
    ];
    return parts.join('/');
  }

  /// Reads the current sequence without consuming a number — used by the
  /// settings screen to preview the next invoice number.
  Future<String> previewNextInvoiceNumber({DateTime? at}) async {
    final col = _settings();
    final settings = await getSettings();
    final date = at ?? DateTime.now();
    final fy = RatnexFormat.financialYear(date);
    var current = 0;
    if (col != null) {
      try {
        final snap = await col.doc(invoiceCounterDocId).get();
        current = (snap.data()?[fy] as num?)?.toInt() ?? 0;
      } catch (_) {
        current = 0;
      }
    }
    final padded =
        (current + 1).toString().padLeft(settings.invoicePadding, '0');
    final parts = <String>[
      settings.invoicePrefix,
      if (settings.includeFinancialYear) fy,
      padded,
    ];
    return parts.join('/');
  }
}
