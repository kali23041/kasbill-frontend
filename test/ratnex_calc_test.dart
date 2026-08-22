import 'package:flutter_test/flutter_test.dart';
import 'package:kasbill/utils/ratnex_format.dart';

void main() {
  group('looksLikeExpression', () {
    test('is true only when an operator is present', () {
      expect(RatnexCalc.looksLikeExpression('12.5+3.2'), isTrue);
      expect(RatnexCalc.looksLikeExpression('4*2750'), isTrue);
      expect(RatnexCalc.looksLikeExpression('12.5'), isFalse);
      expect(RatnexCalc.looksLikeExpression(''), isFalse);
      expect(RatnexCalc.looksLikeExpression('gold'), isFalse);
    });

    test('a leading minus alone is not an expression', () {
      expect(RatnexCalc.looksLikeExpression('-5'), isFalse);
    });
  });

  group('evaluate', () {
    test('adds and subtracts weights', () {
      expect(RatnexCalc.evaluate('12.5+3.2'), closeTo(15.7, 0.0001));
      expect(RatnexCalc.evaluate('20-4.25'), closeTo(15.75, 0.0001));
    });

    test('respects operator precedence', () {
      expect(RatnexCalc.evaluate('2+3*4'), 14);
      expect(RatnexCalc.evaluate('(2+3)*4'), 20);
    });

    test('handles the unicode multiply and divide signs', () {
      expect(RatnexCalc.evaluate('4×2750'), 11000);
      expect(RatnexCalc.evaluate('100÷4'), 25);
    });

    test('returns null on malformed input', () {
      expect(RatnexCalc.evaluate('2+'), isNull);
      expect(RatnexCalc.evaluate('(2+3'), isNull);
      expect(RatnexCalc.evaluate('abc'), isNull);
    });

    test('does not divide by zero', () {
      expect(RatnexCalc.evaluate('5/0'), isNull);
    });
  });
}
