import 'package:flutter_test/flutter_test.dart';
import 'package:kasbill/utils/ratnex_format.dart';

void main() {
  group('HUID', () {
    test('accepts exactly six alphanumeric characters', () {
      expect(RatnexValidate.isHuid('AZ4E7K'), isTrue);
      expect(RatnexValidate.isHuid('az4e7k'), isTrue, reason: 'case folded');
      expect(RatnexValidate.isHuid('AZ4E7'), isFalse);
      expect(RatnexValidate.isHuid('AZ4E7KL'), isFalse);
      expect(RatnexValidate.isHuid('AZ4E-K'), isFalse);
    });

    test('an empty field is not an error', () {
      expect(RatnexValidate.huidError(''), isNull);
      expect(RatnexValidate.huidError(null), isNull);
      expect(RatnexValidate.huidError('ABC'), isNotNull);
    });
  });

  group('PAN', () {
    test('matches the AAAAA9999A shape', () {
      expect(RatnexValidate.isPan('ABCDE1234F'), isTrue);
      expect(RatnexValidate.isPan('ABCD1234F'), isFalse);
      expect(RatnexValidate.isPan('ABCDE12345'), isFalse);
    });
  });

  group('GSTIN', () {
    test('requires 15 characters with Z in position 14', () {
      expect(RatnexValidate.isGstin('27ABCDE1234F1Z5'), isTrue);
      expect(RatnexValidate.isGstin('27ABCDE1234F1A5'), isFalse);
      expect(RatnexValidate.isGstin('27ABCDE1234F1Z'), isFalse);
    });
  });

  group('cash and PAN limits', () {
    test('269ST bites at two lakh, not below', () {
      expect(RatnexValidate.breaches269ST(199999), isFalse);
      expect(RatnexValidate.breaches269ST(200000), isTrue);
      expect(RatnexValidate.breaches269ST(250000), isTrue);
    });

    test('PAN is required from two lakh upward', () {
      expect(RatnexValidate.needsPan(199999.99), isFalse);
      expect(RatnexValidate.needsPan(200000), isTrue);
    });
  });

  group('phone', () {
    test('flags short numbers but allows an empty field', () {
      expect(RatnexValidate.phoneError(''), isNull);
      expect(RatnexValidate.phoneError('98765'), isNotNull);
      expect(RatnexValidate.phoneError('9876543210'), isNull);
      expect(RatnexValidate.phoneError('+91 98765 43210'), isNull);
    });
  });

  group('HSN', () {
    test('picks the right code for the item type', () {
      expect(RatnexHsn.forMetalType('Gold 22K'), RatnexHsn.gold);
      expect(
        RatnexHsn.forMetalType('Gold 24K', categoryName: 'Coins'),
        RatnexHsn.coin,
      );
      expect(
        RatnexHsn.forMetalType('Silver', categoryName: 'Bars'),
        RatnexHsn.bullionSilver,
      );
      expect(
        RatnexHsn.forMetalType('Gold 24K', categoryName: 'Biscuit'),
        RatnexHsn.bullionGold,
      );
    });
  });
}
