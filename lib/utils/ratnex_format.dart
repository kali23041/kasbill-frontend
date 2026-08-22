import 'dart:math' as math;

import 'package:intl/intl.dart';

/// Formatting + number helpers shared across bills, girvi, MOD and PDFs.
class RatnexFormat {
  RatnexFormat._();

  static final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final NumberFormat _inrPaise = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  static final NumberFormat _plain = NumberFormat('#,##,##0.00', 'en_IN');
  static final NumberFormat _compactInr = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );

  static String money(num v) => _inr.format(v);

  static String moneyPaise(num v) => _inrPaise.format(v);

  static String plain(num v) => _plain.format(v);

  /// ₹1.2L / ₹4.5Cr style for dashboard tiles.
  static String compact(num v) => _compactInr.format(v);

  static String grams(num v) {
    final s = v.toStringAsFixed(3);
    return '${s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')} g';
  }

  static String date(DateTime? d) =>
      d == null ? '—' : DateFormat('dd MMM yyyy').format(d);

  static String dateTime(DateTime? d) =>
      d == null ? '—' : DateFormat('dd MMM yyyy, hh:mm a').format(d);

  static String shortDate(DateTime? d) =>
      d == null ? '—' : DateFormat('dd MMM').format(d);

  static String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static String monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);

  /// Rounds to the nearest rupee and returns the signed adjustment applied.
  static ({double rounded, double adjustment}) roundOff(double amount) {
    final rounded = amount.roundToDouble();
    return (rounded: rounded, adjustment: rounded - amount);
  }

  /// Indian financial year label for a date: 2025-07-14 -> "25-26".
  static String financialYear(DateTime d) {
    final startYear = d.month >= 4 ? d.year : d.year - 1;
    final a = startYear.toString().substring(2);
    final b = (startYear + 1).toString().substring(2);
    return '$a-$b';
  }

  /// First day of the financial year containing [d].
  static DateTime financialYearStart(DateTime d) {
    final startYear = d.month >= 4 ? d.year : d.year - 1;
    return DateTime(startYear, 4, 1);
  }

  static const _ones = <String>[
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen',
  ];
  static const _tens = <String>[
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy',
    'Eighty', 'Ninety',
  ];

  static String _twoDigits(int n) {
    if (n < 20) return _ones[n];
    final t = _tens[n ~/ 10];
    final o = _ones[n % 10];
    return o.isEmpty ? t : '$t $o';
  }

  static String _threeDigits(int n) {
    final hundreds = n ~/ 100;
    final rest = n % 100;
    final parts = <String>[];
    if (hundreds > 0) parts.add('${_ones[hundreds]} Hundred');
    if (rest > 0) parts.add(_twoDigits(rest));
    return parts.join(' ');
  }

  /// Indian-system amount in words, e.g. "Rupees Forty Two Thousand Only".
  /// Legally expected on Indian tax invoices.
  static String amountInWords(double amount) {
    if (amount.isNaN || amount.isInfinite) return '—';
    final negative = amount < 0;
    final abs = amount.abs();
    final rupees = abs.floor();
    final paise = ((abs - rupees) * 100).round();

    final words = _rupeesInWords(rupees);
    final buffer = StringBuffer();
    if (negative) buffer.write('Minus ');
    buffer.write('Rupees $words');
    if (paise > 0) {
      buffer.write(' and ${_twoDigits(paise)} Paise');
    }
    buffer.write(' Only');
    return buffer.toString();
  }

  static String _rupeesInWords(int value) {
    if (value == 0) return 'Zero';
    var n = value;
    final parts = <String>[];

    final crore = n ~/ 10000000;
    n %= 10000000;
    final lakh = n ~/ 100000;
    n %= 100000;
    final thousand = n ~/ 1000;
    n %= 1000;

    if (crore > 0) parts.add('${_rupeesInWords(crore)} Crore');
    if (lakh > 0) parts.add('${_twoDigits(lakh)} Lakh');
    if (thousand > 0) parts.add('${_twoDigits(thousand)} Thousand');
    if (n > 0) parts.add(_threeDigits(n));
    return parts.join(' ');
  }

  /// Masks all but the last 4 characters — used for PAN/Aadhaar display.
  static String maskId(String? raw, {int visible = 4}) {
    final v = raw?.trim() ?? '';
    if (v.length <= visible) return v;
    return '${'X' * (v.length - visible)}${v.substring(v.length - visible)}';
  }

  static String initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters().toUpperCase();
    return (parts.first.characters() + parts[1].characters()).toUpperCase();
  }

  static String relativeDays(DateTime? d) {
    if (d == null) return '—';
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 0) return 'In ${-days}d';
    if (days < 30) return '${days}d ago';
    if (days < 365) return '${(days / 30).floor()}mo ago';
    return '${(days / 365).floor()}y ago';
  }
}

extension _FirstChar on String {
  String characters() => isEmpty ? '' : substring(0, 1);
}

/// Evaluates simple arithmetic typed into weight/amount fields, so a shop can
/// enter `12.5+3.2` or `4*2.75` directly. Returns null when not an expression.
class RatnexCalc {
  RatnexCalc._();

  static final _exprPattern = RegExp(r'^[0-9+\-*/×÷.\s()]+$');

  static bool looksLikeExpression(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return false;
    if (!_exprPattern.hasMatch(s)) return false;
    return RegExp(r'[+\-*/×÷()]').hasMatch(s.replaceFirst(RegExp(r'^-'), ''));
  }

  /// Returns the evaluated value, or null when the expression is invalid.
  static double? evaluate(String raw) {
    final normalized =
        raw.replaceAll('×', '*').replaceAll('÷', '/').replaceAll(' ', '');
    if (normalized.isEmpty) return null;
    try {
      final tokens = _tokenize(normalized);
      if (tokens.isEmpty) return null;
      final rpn = _toRpn(tokens);
      return _evalRpn(rpn);
    } catch (_) {
      return null;
    }
  }

  static List<String> _tokenize(String s) {
    final out = <String>[];
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (RegExp(r'[0-9.]').hasMatch(c)) {
        buf.write(c);
        continue;
      }
      if (buf.isNotEmpty) {
        out.add(buf.toString());
        buf.clear();
      }
      // Unary minus at the start or after an operator/open paren.
      if (c == '-' && (out.isEmpty || _isOp(out.last) || out.last == '(')) {
        buf.write('-');
        continue;
      }
      out.add(c);
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }

  static bool _isOp(String t) => t == '+' || t == '-' || t == '*' || t == '/';

  static int _precedence(String op) => (op == '*' || op == '/') ? 2 : 1;

  static List<String> _toRpn(List<String> tokens) {
    final output = <String>[];
    final ops = <String>[];
    for (final t in tokens) {
      if (_isOp(t)) {
        while (ops.isNotEmpty &&
            _isOp(ops.last) &&
            _precedence(ops.last) >= _precedence(t)) {
          output.add(ops.removeLast());
        }
        ops.add(t);
      } else if (t == '(') {
        ops.add(t);
      } else if (t == ')') {
        while (ops.isNotEmpty && ops.last != '(') {
          output.add(ops.removeLast());
        }
        if (ops.isEmpty) throw const FormatException('unbalanced');
        ops.removeLast();
      } else {
        output.add(t);
      }
    }
    while (ops.isNotEmpty) {
      final op = ops.removeLast();
      if (op == '(') throw const FormatException('unbalanced');
      output.add(op);
    }
    return output;
  }

  static double _evalRpn(List<String> rpn) {
    final stack = <double>[];
    for (final t in rpn) {
      if (_isOp(t)) {
        if (stack.length < 2) throw const FormatException('bad expr');
        final b = stack.removeLast();
        final a = stack.removeLast();
        switch (t) {
          case '+':
            stack.add(a + b);
          case '-':
            stack.add(a - b);
          case '*':
            stack.add(a * b);
          case '/':
            if (b == 0) throw const FormatException('div0');
            stack.add(a / b);
        }
      } else {
        final v = double.tryParse(t);
        if (v == null) throw const FormatException('bad number');
        stack.add(v);
      }
    }
    if (stack.length != 1) throw const FormatException('bad expr');
    final result = stack.single;
    if (result.isNaN || result.isInfinite) throw const FormatException('nan');
    // Trim floating point noise from chained operations.
    return (result * 1000).roundToDouble() / 1000;
  }
}

/// Domain validators used across stock, billing and KYC forms.
class RatnexValidate {
  RatnexValidate._();

  static final _huid = RegExp(r'^[0-9A-Z]{6}$');
  static final _pan = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
  static final _gstin = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z][Z][0-9A-Z]$',
  );
  static final _ifsc = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');

  /// BIS hallmark HUID is exactly 6 alphanumeric characters.
  static bool isHuid(String? v) =>
      v != null && _huid.hasMatch(v.trim().toUpperCase());

  static String? huidError(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    return isHuid(s) ? null : 'HUID must be exactly 6 letters/digits';
  }

  static bool isPan(String? v) =>
      v != null && _pan.hasMatch(v.trim().toUpperCase());

  static String? panError(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    return isPan(s) ? null : 'PAN looks like ABCDE1234F';
  }

  static bool isGstin(String? v) =>
      v != null && _gstin.hasMatch(v.trim().toUpperCase());

  static String? gstinError(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    return isGstin(s) ? null : 'GSTIN must be 15 characters';
  }

  static bool isIfsc(String? v) =>
      v != null && _ifsc.hasMatch(v.trim().toUpperCase());

  static String? phoneError(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.length < 10) return 'Enter a 10-digit number';
    return null;
  }

  /// Section 269ST: cash receipts of ₹2,00,000 or more from one person in a
  /// single day / single transaction attract a penalty equal to the amount.
  static const cashLimit269ST = 200000.0;

  static bool breaches269ST(double cashAmount) =>
      cashAmount >= cashLimit269ST;

  /// PAN is required from the customer for jewellery sales at or above ₹2 lakh.
  static const panRequiredAbove = 200000.0;

  static bool needsPan(double billTotal) => billTotal >= panRequiredAbove;
}

/// Default HSN codes for jewellery so invoices carry the legally required
/// HSN summary. Shops can override per category.
class RatnexHsn {
  RatnexHsn._();

  static const gold = '7113';
  static const silver = '7113';
  static const diamond = '7113';
  static const looseStone = '7103';
  static const bullionGold = '7108';
  static const bullionSilver = '7106';
  static const coin = '7118';
  static const making = '9988';

  static String forMetalType(String? metalType, {String? categoryName}) {
    final t = (metalType ?? '').toLowerCase();
    final c = (categoryName ?? '').toLowerCase();
    if (c.contains('coin')) return coin;
    if (c.contains('bar') || c.contains('bullion') || c.contains('biscuit')) {
      return t.contains('silver') ? bullionSilver : bullionGold;
    }
    if (t.contains('stone') || t.contains('gem')) return looseStone;
    return gold;
  }
}

double safeDiv(double a, double b) => b == 0 ? 0 : a / b;

double clampPositive(num v) => math.max(0, v.toDouble());
