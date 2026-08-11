import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'shop_plan_service.dart';

class CheckoutService {
  static const baseUrl = 'https://ratnex.essixx.com/checkout';
  static const successReturnUrl = 'ratnex://payment/success';
  static const cancelReturnUrl = 'ratnex://payment/cancel';

  /// Builds checkout URI for the hosted Cashfree page.
  static Future<Uri> buildCheckoutUri(PlanBilling billing) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim().toLowerCase();
    if (user == null || email == null || email.isEmpty) {
      throw Exception('Sign in required to open checkout');
    }

    String? token;
    try {
      token = await user.getIdToken();
    } catch (e) {
      debugPrint('Checkout idToken skipped: $e');
    }

    final params = <String, String>{
      'plan': ShopPlan.checkoutParamFor(billing),
      'email': email,
      'returnUrl': successReturnUrl,
    };
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) params['name'] = name;
    if (user.uid.isNotEmpty) params['uid'] = user.uid;
    if (token != null && token.isNotEmpty) params['token'] = token;

    return Uri.parse(baseUrl).replace(queryParameters: params);
  }

  /// Opens checkout in the system browser (preferred for Cashfree UPI).
  static Future<bool> openCheckout(PlanBilling billing) async {
    final uri = await buildCheckoutUri(billing);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw Exception('Could not open checkout browser');
    }
    return true;
  }
}
