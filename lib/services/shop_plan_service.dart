import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_helpers.dart';

enum PlanBilling { free, monthly, yearly }

class ShopPlan {
  final String plan; // free | premium
  final PlanBilling billing;
  final int amount;
  final DateTime? startedOn;
  final DateTime? expiresOn;
  final String? planStatus; // trial | active | expired
  final String? planSource;
  final String? planPaymentId;
  final bool fieldsPresent;

  const ShopPlan({
    required this.plan,
    required this.billing,
    required this.amount,
    this.startedOn,
    this.expiresOn,
    this.planStatus,
    this.planSource,
    this.planPaymentId,
    this.fieldsPresent = false,
  });

  static const missing = ShopPlan(
    plan: 'free',
    billing: PlanBilling.free,
    amount: 0,
    fieldsPresent: false,
  );

  static const free = ShopPlan(
    plan: 'free',
    billing: PlanBilling.free,
    amount: 0,
    fieldsPresent: true,
  );

  bool get isPremium => plan == 'premium';

  bool get needsTrialCheckout =>
      !fieldsPresent || (planStatus == null && expiresOn == null);

  /// Website is source of truth: trial/active + future expiry.
  bool get isEntitled {
    if (planStatus != 'trial' && planStatus != 'active') return false;
    if (expiresOn == null) return false;
    return expiresOn!.isAfter(DateTime.now());
  }

  bool get isExpired {
    if (planStatus == 'expired') return true;
    if (expiresOn == null) return !isEntitled;
    return !expiresOn!.isAfter(DateTime.now());
  }

  /// Free trial is one-time (7 days). After start/expiry, force paid plans.
  bool get canStartFreeTrial => needsTrialCheckout;

  bool get trialUsedOrExpired =>
      !needsTrialCheckout &&
      !isEntitled &&
      (planStatus == 'expired' ||
          planStatus == 'trial' ||
          billing == PlanBilling.free ||
          expiresOn != null);

  String get title {
    if (!isEntitled) {
      if (needsTrialCheckout) return 'No plan';
      return 'Expired';
    }
    if (planStatus == 'trial' || billing == PlanBilling.free) {
      return 'Free trial';
    }
    return billing == PlanBilling.yearly ? 'Premium Yearly' : 'Premium Monthly';
  }

  String get priceLabel {
    if (!isEntitled) {
      return needsTrialCheckout ? 'Start trial' : 'Upgrade required';
    }
    switch (billing) {
      case PlanBilling.monthly:
        return '₹399 / month';
      case PlanBilling.yearly:
        return '₹3,999 / year';
      case PlanBilling.free:
        return 'Free trial';
    }
  }

  String get statusLabel {
    if (needsTrialCheckout) return 'Not started';
    switch (planStatus) {
      case 'trial':
        return 'Trial';
      case 'active':
        return 'Active';
      case 'expired':
        return 'Expired';
      default:
        return isEntitled ? 'Active' : 'Expired';
    }
  }

  String get checkoutPlanParam {
    switch (billing) {
      case PlanBilling.yearly:
        return 'yearly';
      case PlanBilling.monthly:
        return 'monthly';
      case PlanBilling.free:
        return 'free';
    }
  }

  static String checkoutParamFor(PlanBilling billing) {
    switch (billing) {
      case PlanBilling.yearly:
        return 'yearly';
      case PlanBilling.monthly:
        return 'monthly';
      case PlanBilling.free:
        return 'free';
    }
  }

  factory ShopPlan.fromUserDoc(Map<String, dynamic>? data) {
    if (data == null) return ShopPlan.missing;

    final hasPlanKey = data.containsKey('plan') ||
        data.containsKey('planStatus') ||
        data.containsKey('planExpiresOn') ||
        data.containsKey('planBilling');

    final plan = (data['plan'] as String?) ?? 'free';
    final billingRaw = data['planBilling'] as String?;
    final PlanBilling resolvedBilling;
    if (billingRaw == 'yearly') {
      resolvedBilling = PlanBilling.yearly;
    } else if (billingRaw == 'monthly') {
      resolvedBilling = PlanBilling.monthly;
    } else if (plan == 'premium') {
      resolvedBilling = PlanBilling.monthly;
    } else {
      resolvedBilling = PlanBilling.free;
    }

    return ShopPlan(
      plan: plan,
      billing: resolvedBilling,
      amount: (data['planAmount'] as num?)?.toInt() ??
          (resolvedBilling == PlanBilling.yearly
              ? 3999
              : resolvedBilling == PlanBilling.monthly
                  ? 399
                  : 0),
      startedOn: (data['planStartedOn'] as Timestamp?)?.toDate(),
      expiresOn: (data['planExpiresOn'] as Timestamp?)?.toDate(),
      planStatus: data['planStatus'] as String?,
      planSource: data['planSource'] as String?,
      planPaymentId: data['planPaymentId'] as String?,
      fieldsPresent: hasPlanKey &&
          (data['planStatus'] != null || data['planExpiresOn'] != null),
    );
  }
}

class ShopPlanService {
  ShopPlanService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  Stream<ShopPlan> watchPlan() {
    final ref = _userRef();
    if (ref == null) return Stream.value(ShopPlan.missing);
    return ref.snapshots().map((snap) => ShopPlan.fromUserDoc(snap.data()));
  }

  Future<ShopPlan> getPlan() async {
    final ref = _userRef();
    if (ref == null) return ShopPlan.missing;
    final snap = await ref.get();
    return ShopPlan.fromUserDoc(snap.data());
  }

  /// Deprecated: website checkout is the source of truth. Kept as no-op.
  @Deprecated('Use CheckoutService.openCheckout — website writes Firestore')
  Future<void> activatePlan(PlanBilling billing) async {
    // No-op: payments and trial activation happen on ratnex.essixx.com
  }
}
