import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/ratnex_format.dart';

/// Sends bills, receipts and reminders straight to a customer's WhatsApp.
///
/// The chat opens pre-filled; the shop still taps send, so nothing goes out
/// without a human in the loop.
class WhatsAppService {
  WhatsAppService._();

  /// Normalises an Indian number to the `91XXXXXXXXXX` form wa.me expects.
  static String? normalizePhone(String? raw, {String countryCode = '91'}) {
    final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.length == 10) return '$countryCode$digits';
    if (digits.length == 11 && digits.startsWith('0')) {
      return '$countryCode${digits.substring(1)}';
    }
    if (digits.length >= 11 && digits.length <= 15) return digits;
    return null;
  }

  static Uri? chatUri(String? phone, String message) {
    final normalized = normalizePhone(phone);
    if (normalized == null) return null;
    return Uri.parse(
      'https://wa.me/$normalized?text=${Uri.encodeComponent(message)}',
    );
  }

  /// Returns false when the number is unusable or WhatsApp is not installed.
  static Future<bool> send(String? phone, String message) async {
    final uri = chatUri(phone, message);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> call(String? phone) async {
    final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return false;
    try {
      return await launchUrl(Uri.parse('tel:$digits'));
    } catch (_) {
      return false;
    }
  }

  static Future<bool> sms(String? phone, String message) async {
    final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return false;
    try {
      return await launchUrl(
        Uri.parse('sms:$digits?body=${Uri.encodeComponent(message)}'),
      );
    } catch (_) {
      return false;
    }
  }

  static Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  // ---- Message templates ---------------------------------------------------

  static String billMessage({
    required String shopName,
    required String customerName,
    required String billNo,
    required double amount,
    double balance = 0,
    String? upiId,
  }) {
    final b = StringBuffer()
      ..writeln('Namaste ${customerName.trim()} 🙏')
      ..writeln()
      ..writeln('Thank you for shopping at $shopName.')
      ..writeln()
      ..writeln('Bill no: $billNo')
      ..writeln('Total: ${RatnexFormat.money(amount)}');
    if (balance > 0.5) {
      b.writeln('Balance due: ${RatnexFormat.money(balance)}');
    }
    if (upiId != null && upiId.trim().isNotEmpty) {
      b
        ..writeln()
        ..writeln('You can pay on UPI: ${upiId.trim()}');
    }
    b
      ..writeln()
      ..write('— $shopName');
    return b.toString();
  }

  static String udhaarReminder({
    required String shopName,
    required String customerName,
    required double outstanding,
    int daysOverdue = 0,
    String? upiId,
  }) {
    final b = StringBuffer()
      ..writeln('Namaste ${customerName.trim()} 🙏')
      ..writeln()
      ..writeln(
        'A gentle reminder: ${RatnexFormat.money(outstanding)} is pending on your account at $shopName.',
      );
    if (daysOverdue > 0) {
      b.writeln('It has been $daysOverdue days since the due date.');
    }
    if (upiId != null && upiId.trim().isNotEmpty) {
      b
        ..writeln()
        ..writeln('You can pay on UPI: ${upiId.trim()}');
    }
    b
      ..writeln()
      ..writeln('Please ignore this message if you have already paid.')
      ..write('— $shopName');
    return b.toString();
  }

  static String girviDueReminder({
    required String shopName,
    required String customerName,
    required String girviNo,
    required double amountDue,
    required DateTime dueDate,
  }) {
    return [
      'Namaste ${customerName.trim()} 🙏',
      '',
      'Your girvi $girviNo at $shopName is due on ${RatnexFormat.date(dueDate)}.',
      'Amount payable: ${RatnexFormat.money(amountDue)}',
      '',
      'Please visit the shop or call us to renew or release your items.',
      '— $shopName',
    ].join('\n');
  }

  static String schemeInstallmentReminder({
    required String shopName,
    required String customerName,
    required String schemeName,
    required double amount,
    required int monthNumber,
  }) {
    return [
      'Namaste ${customerName.trim()} 🙏',
      '',
      'Your $schemeName installment #$monthNumber of ${RatnexFormat.money(amount)} is due at $shopName.',
      '',
      'Pay at the shop or on UPI and keep your savings on track.',
      '— $shopName',
    ].join('\n');
  }

  static String repairReadyMessage({
    required String shopName,
    required String customerName,
    required String jobNo,
    double balance = 0,
  }) {
    final b = StringBuffer()
      ..writeln('Namaste ${customerName.trim()} 🙏')
      ..writeln()
      ..writeln('Good news — your order (token $jobNo) is ready at $shopName.');
    if (balance > 0.5) {
      b.writeln('Balance payable on delivery: ${RatnexFormat.money(balance)}');
    }
    b
      ..writeln()
      ..write('Please collect it at your convenience.\n— $shopName');
    return b.toString();
  }

  static String rateMessage({
    required String shopName,
    required Map<String, double> rates,
    DateTime? at,
  }) {
    final b = StringBuffer()
      ..writeln("Today's rates at $shopName")
      ..writeln(RatnexFormat.date(at ?? DateTime.now()))
      ..writeln();
    rates.forEach((label, value) {
      b.writeln('$label — ${RatnexFormat.money(value)}/g');
    });
    b
      ..writeln()
      ..write('Rates change through the day. Please confirm before buying.');
    return b.toString();
  }
}
