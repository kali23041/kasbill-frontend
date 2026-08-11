import 'dart:convert';

import 'package:http/http.dart' as http;

/// Live rates from free IBJA community API (India benchmark).
/// Gold values are published per 10g; silver per kg — converted to ₹/g.
class IbjaRates {
  final DateTime date;
  final double gold22kPerGram;
  final double gold24kPerGram;
  final double silverPerGram;
  final double? delta22kPct;
  final double? delta24kPct;
  final double? deltaSilverPct;
  final String session;

  const IbjaRates({
    required this.date,
    required this.gold22kPerGram,
    required this.gold24kPerGram,
    required this.silverPerGram,
    this.delta22kPct,
    this.delta24kPct,
    this.deltaSilverPct,
    required this.session,
  });

  /// Purity-derived from 24K when IBJA only publishes 999/916.
  double get gold18kPerGram => gold24kPerGram * (18 / 24);

  double get gold20kPerGram => gold24kPerGram * (20 / 24);

  /// IBJA publishes fine silver (999) only — other purities derived by fineness.
  double get silver999PerGram => silverPerGram;

  double silverPurityPerGram(int purity) => silverPerGram * (purity / 999);

  double get silver970PerGram => silverPurityPerGram(970);

  double get silver925PerGram => silverPurityPerGram(925);

  double get silver900PerGram => silverPurityPerGram(900);

  double get silver800PerGram => silverPurityPerGram(800);

  /// Online ₹/g for a metal + karat/purity, or null when unavailable (e.g. platinum).
  /// For gold, [karat] is 18/20/22/24. For silver, [karat] stores purity (999/970/925/900/800).
  double? onlineRatePerGram({
    required String metalType,
    int? karat,
  }) {
    switch (metalType) {
      case 'gold':
        switch (karat) {
          case 18:
            return gold18kPerGram;
          case 20:
            return gold20kPerGram;
          case 22:
            return gold22kPerGram;
          case 24:
            return gold24kPerGram;
          default:
            return null;
        }
      case 'silver':
        final purity = karat ?? 999;
        if (purity <= 0 || purity > 999) return null;
        return silverPurityPerGram(purity);
      case 'platinum':
        return null;
      default:
        return null;
    }
  }
}

class IbjaRatesService {
  static const _goldUrl = 'https://ibja-api.vercel.app/latest';
  static const _silverUrl = 'https://ibja-api.vercel.app/silver/latest';

  Future<IbjaRates> fetchLatest() async {
    final goldRes = await http.get(Uri.parse(_goldUrl)).timeout(
      const Duration(seconds: 12),
    );
    final silverRes = await http.get(Uri.parse(_silverUrl)).timeout(
      const Duration(seconds: 12),
    );

    if (goldRes.statusCode != 200) {
      throw Exception('Gold rates unavailable (${goldRes.statusCode})');
    }
    if (silverRes.statusCode != 200) {
      throw Exception('Silver rates unavailable (${silverRes.statusCode})');
    }

    final gold = jsonDecode(goldRes.body) as Map<String, dynamic>;
    final silver = jsonDecode(silverRes.body) as Map<String, dynamic>;

    final gold999Pm = _num(gold['lblGold999_PM']);
    final gold999Am = _num(gold['lblGold999_AM']);
    final gold916Pm = _num(gold['lblGold916_PM']);
    final gold916Am = _num(gold['lblGold916_AM']);

    final usePm = gold999Pm != null || gold916Pm != null;
    final gold999 = usePm ? (gold999Pm ?? gold999Am) : gold999Am;
    final gold916 = usePm ? (gold916Pm ?? gold916Am) : gold916Am;

    if (gold999 == null || gold916 == null) {
      throw Exception('Incomplete IBJA gold data');
    }

    final silverPm = _num(silver['lblSilver999_PM']);
    final silverAm = _num(silver['lblSilver999_AM']);
    final silverKg = usePm ? (silverPm ?? silverAm) : silverAm;
    if (silverKg == null) {
      throw Exception('Incomplete IBJA silver data');
    }

    final dateStr = (gold['date'] ?? silver['date'])?.toString();
    final date = dateStr != null
        ? DateTime.tryParse(dateStr) ?? DateTime.now()
        : DateTime.now();

    return IbjaRates(
      date: date,
      // IBJA gold: ₹ per 10 grams
      gold22kPerGram: gold916 / 10,
      gold24kPerGram: gold999 / 10,
      // IBJA silver: ₹ per kg
      silverPerGram: silverKg / 1000,
      delta22kPct: _pctChange(gold916Am, gold916Pm ?? gold916Am),
      delta24kPct: _pctChange(gold999Am, gold999Pm ?? gold999Am),
      deltaSilverPct: _pctChange(silverAm, silverPm ?? silverAm),
      session: usePm ? 'PM' : 'AM',
    );
  }

  static double? _num(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', ''));
  }

  static double? _pctChange(double? from, double? to) {
    if (from == null || to == null || from == 0) return null;
    return ((to - from) / from) * 100;
  }
}
