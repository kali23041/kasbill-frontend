import 'package:flutter_test/flutter_test.dart';
import 'package:kasbill/utils/ratnex_format.dart';

void main() {
  group('amountInWords', () {
    test('formats in the Indian system', () {
      expect(
        RatnexFormat.amountInWords(42000),
        'Rupees Forty Two Thousand Only',
      );
      expect(RatnexFormat.amountInWords(0), 'Rupees Zero Only');
      expect(RatnexFormat.amountInWords(1), 'Rupees One Only');
      expect(RatnexFormat.amountInWords(100), 'Rupees One Hundred Only');
      expect(RatnexFormat.amountInWords(115), 'Rupees One Hundred Fifteen Only');
    });

    test('uses lakh and crore, not million', () {
      expect(RatnexFormat.amountInWords(100000), 'Rupees One Lakh Only');
      expect(
        RatnexFormat.amountInWords(250000),
        'Rupees Two Lakh Fifty Thousand Only',
      );
      expect(RatnexFormat.amountInWords(10000000), 'Rupees One Crore Only');
      expect(
        RatnexFormat.amountInWords(12345678),
        'Rupees One Crore Twenty Three Lakh Forty Five Thousand Six Hundred Seventy Eight Only',
      );
    });

    test('includes paise when present', () {
      expect(
        RatnexFormat.amountInWords(1250.50),
        'Rupees One Thousand Two Hundred Fifty and Fifty Paise Only',
      );
    });

    test('handles a negative amount', () {
      expect(RatnexFormat.amountInWords(-500), 'Minus Rupees Five Hundred Only');
    });
  });

  group('roundOff', () {
    test('rounds to the nearest rupee and reports the adjustment', () {
      final up = RatnexFormat.roundOff(1234.60);
      expect(up.rounded, 1235);
      expect(up.adjustment, closeTo(0.40, 0.001));

      final down = RatnexFormat.roundOff(1234.20);
      expect(down.rounded, 1234);
      expect(down.adjustment, closeTo(-0.20, 0.001));
    });

    test('leaves a whole rupee alone', () {
      final exact = RatnexFormat.roundOff(1000);
      expect(exact.rounded, 1000);
      expect(exact.adjustment, 0);
    });
  });

  group('financialYear', () {
    test('runs April to March', () {
      expect(RatnexFormat.financialYear(DateTime(2025, 4, 1)), '25-26');
      expect(RatnexFormat.financialYear(DateTime(2025, 12, 31)), '25-26');
      expect(RatnexFormat.financialYear(DateTime(2026, 3, 31)), '25-26');
      expect(RatnexFormat.financialYear(DateTime(2026, 4, 1)), '26-27');
    });

    test('start date is 1 April of the opening year', () {
      expect(
        RatnexFormat.financialYearStart(DateTime(2026, 1, 15)),
        DateTime(2025, 4, 1),
      );
    });
  });

  group('maskId', () {
    test('leaves only the last four characters visible', () {
      expect(RatnexFormat.maskId('ABCDE1234F'), 'XXXXXX234F');
      expect(RatnexFormat.maskId('123'), '123');
      expect(RatnexFormat.maskId(null), '');
    });
  });
}
