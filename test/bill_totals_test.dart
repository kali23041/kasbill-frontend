import 'package:flutter_test/flutter_test.dart';
import 'package:kasbill/services/shop_bills_service.dart';

BillLineItem _item({
  double netWeight = 10,
  double rate = 7000,
  double making = 500,
  String makingType = 'flat',
  double wastage = 0,
  bool applyGst = false,
  double gstPercent = 3,
  int qty = 1,
}) {
  return BillLineItem.compute(
    name: 'Chain',
    grossWeight: netWeight,
    netWeight: netWeight,
    ratePerGram: rate,
    makingCharge: making,
    makingType: makingType,
    wastagePercent: wastage,
    stoneCharge: 0,
    otherCharge: 0,
    qty: qty,
    applyGst: applyGst,
    gstPercent: gstPercent,
  );
}

void main() {
  group('BillTotals without an exchange', () {
    test('balance is the grand total less what was paid', () {
      final totals = BillTotals.fromItems(
        items: [_item()],
        paidAmount: 20000,
      );
      expect(totals.grandTotal, 70500);
      expect(totals.exchangeValue, 0);
      expect(totals.netPayable, 70500);
      expect(totals.balance, 50500);
    });

    test('overpayment never produces a negative balance', () {
      final totals = BillTotals.fromItems(
        items: [_item()],
        paidAmount: 999999,
      );
      expect(totals.balance, 0);
    });

    test('GST is added on top of the taxable value', () {
      final totals = BillTotals.fromItems(
        items: [_item(applyGst: true, gstPercent: 3)],
        paidAmount: 0,
      );
      expect(totals.taxable, 70500);
      expect(totals.gst, closeTo(2115, 0.01));
      expect(totals.grandTotal, closeTo(72615, 0.01));
    });
  });

  group('BillTotals with an old-gold exchange', () {
    test('grandTotal stays the full sale so GST is unaffected', () {
      final totals = BillTotals.fromItems(
        items: [_item(applyGst: true, gstPercent: 3)],
        paidAmount: 0,
        exchangeValue: 30000,
      );
      expect(totals.taxable, 70500, reason: 'exchange is not a discount');
      expect(totals.gst, closeTo(2115, 0.01));
      expect(totals.grandTotal, closeTo(72615, 0.01));
    });

    test('the credit comes off what the customer actually pays', () {
      final totals = BillTotals.fromItems(
        items: [_item()],
        paidAmount: 10000,
        exchangeValue: 30000,
      );
      expect(totals.grandTotal, 70500);
      expect(totals.netPayable, 40500);
      expect(totals.balance, 30500);
      expect(totals.hasExchange, isTrue);
    });

    test('an exchange larger than the sale leaves nothing payable', () {
      final totals = BillTotals.fromItems(
        items: [_item()],
        paidAmount: 0,
        exchangeValue: 999999,
      );
      expect(totals.netPayable, 0);
      expect(totals.balance, 0);
    });
  });

  group('BillTotals.fromMap', () {
    test('older bills without an exchange field still read correctly', () {
      final totals = BillTotals.fromMap({
        'taxable': 70500,
        'gst': 0,
        'grandTotal': 70500,
        'paidAmount': 500,
        'balance': 70000,
      });
      expect(totals.exchangeValue, 0);
      expect(totals.netPayable, 70500);
      expect(totals.hasExchange, isFalse);
      expect(totals.balance, 70000);
    });
  });

  group('BillExchangeItem', () {
    test('credits metal value less the melting deduction', () {
      const item = BillExchangeItem(
        name: 'Old bangles',
        grossWeight: 22,
        netWeight: 20,
        ratePerGram: 7000,
        deductionPercent: 8,
      );
      expect(item.grossValue, 140000);
      expect(item.deduction, closeTo(11200, 0.01));
      expect(item.value, closeTo(128800, 0.01));
    });

    test('totals a basket of exchanged pieces', () {
      const items = [
        BillExchangeItem(
          name: 'Ring',
          grossWeight: 5,
          netWeight: 5,
          ratePerGram: 7000,
        ),
        BillExchangeItem(
          name: 'Chain',
          grossWeight: 10,
          netWeight: 10,
          ratePerGram: 7000,
          deductionPercent: 10,
        ),
      ];
      expect(BillExchangeItem.totalOf(items), closeTo(35000 + 63000, 0.01));
    });
  });

  group('statusFromPaid', () {
    test('classifies unpaid, partial and paid', () {
      expect(
        ShopBill.statusFromPaid(grandTotal: 1000, paidAmount: 0),
        'unpaid',
      );
      expect(
        ShopBill.statusFromPaid(grandTotal: 1000, paidAmount: 400),
        'partial',
      );
      expect(
        ShopBill.statusFromPaid(grandTotal: 1000, paidAmount: 1000),
        'paid',
      );
    });

    test('a cancelled bill stays cancelled', () {
      expect(
        ShopBill.statusFromPaid(
          grandTotal: 1000,
          paidAmount: 1000,
          forced: 'cancelled',
        ),
        'cancelled',
      );
    });
  });
}
