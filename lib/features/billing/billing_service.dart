import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Google Play product id for the Lawn Estimator Pro monthly subscription.
///
/// Created in Play Console as a SUBSCRIPTION with one base plan:
///   - 30-day free trial (Play-managed offer on the base plan)
///   - then $19.95/month (USD), auto-renewing
///
/// This string must match the Play Console product id EXACTLY.
/// Trial eligibility is enforced server-side by Google Play — the app runs
/// no local trial timer.
///
/// What "Pro" means: unlimited estimates, zero ads, and clean PDFs with
/// no watermark. The free tier gets 5 new estimates per calendar month,
/// AdMob banner ads plus a full-screen interstitial after each completed
/// estimate (dismissed with a tap), and a light "FREE VERSION" watermark
/// on generated PDFs.
const String kProSubscriptionId = 'lawn_estimator_pro_monthly';

/// Marketing copy shown on the upgrade screen. Keep it in one place so the
/// upgrade screen and the Play Store listing never disagree.
const String kTrialLengthText = '30-day free trial';
const String kMonthlyPriceText = '\$19.95/month';

enum BillingState {
  /// Still talking to the store; the gate shows a loading screen.
  unknown,

  /// No active subscription/trial: 5 new estimates per calendar month,
  /// AdMob banners, a full-screen interstitial after each completed
  /// estimate, and a "FREE VERSION" PDF watermark.
  /// Also used when the store is unreachable or the product isn't in Play
  /// Console yet — the user is never blocked, the upgrade screen just
  /// explains the situation.
  free,

  /// Active subscription (or Play-managed trial). Unlimited estimates,
  /// zero ads, clean PDFs.
  pro,
}

/// Owns the Google Play Billing subscription flow and the app's tier state.
///
/// Freemium model: [BillingState.free] gets 5 new estimates per calendar
/// month with ads (banners + a post-estimate interstitial) and watermarked
/// PDFs; [BillingState.pro] is unlimited, ad-free, and prints clean PDFs.
///
/// Source of truth for the tier is the Play Billing client (queryPurchases
/// via restorePurchases + the purchase stream): if Google Play reports an
/// owned subscription for [kProSubscriptionId], the user is Pro. Expired,
/// cancelled, or refunded subscriptions stop appearing in that query, so
/// they drop back to the free tier automatically.
///
/// IMPORTANT — purchase verification: this build performs a local sanity
/// check ([_verifyLocally]) and acknowledges every purchase with
/// completePurchase (required — Play auto-refunds unacknowledged purchases
/// after 3 days). True server-side verification (Play Developer API
/// purchases.subscriptionsv2.get with a service account) needs a backend and
/// is NOT in this build; that is a documented follow-up before launch.
class BillingService extends ChangeNotifier {
  BillingService._();

  static final BillingService instance = BillingService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  BillingState _state = BillingState.unknown;
  BillingState get state => _state;

  /// True while the user has dismissed the launch upgrade offer this
  /// session ("Continue free with ads"). Resets on every app start so free
  /// users get the choice on each launch.
  bool _upgradeDismissed = false;
  bool get upgradeDismissed => _upgradeDismissed;

  void dismissUpgradeOffer() {
    _upgradeDismissed = true;
    notifyListeners();
  }

  ProductDetails? _product;
  ProductDetails? get product => _product;

  /// True when the subscription product exists in the Play Store and the
  /// purchase flow can actually run.
  bool get canPurchase => _product != null && !_storeDown;

  bool _storeDown = false;
  bool get storeDown => _storeDown;

  String? _lastError;
  String? get lastError => _lastError;

  bool _purchasePending = false;
  bool get purchasePending => _purchasePending;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  Timer? _safetyTimer;
  bool _initialized = false;

  /// Connects the purchase stream and performs the first tier check.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) {
        _lastError = 'Purchase stream error: $e';
        notifyListeners();
      },
    );
    await refresh();
  }

  /// Full re-check: store availability, product details, owned purchases.
  /// Shows the loading state while running.
  Future<void> refresh() async {
    _lastError = null;
    _storeDown = false;
    _setState(BillingState.unknown);
    _safetyTimer?.cancel();
    // Defensive: restorePurchases always emits to the stream on Android, but
    // if the stream never fires we must not hang on the loading screen.
    // Freemium fallback is the free tier — never a block.
    _safetyTimer = Timer(const Duration(seconds: 12), () {
      if (_state == BillingState.unknown) {
        _lastError =
            'Timed out talking to Google Play. You can keep using the app '
            'free with ads and retry the upgrade later.';
        _storeDown = true;
        _setState(BillingState.free);
      }
    });
    try {
      final bool available = await _iap.isAvailable();
      if (!available) {
        _lastError =
            'Google Play Billing is not available on this device. The app '
            'works free with ads; upgrading needs the Play Store.';
        _storeDown = true;
        _setState(BillingState.free);
        return;
      }
      final ProductDetailsResponse response = await _iap.queryProductDetails({
        kProSubscriptionId,
      });
      if (response.error != null) {
        _lastError =
            'Could not load subscription info: ${response.error!.message}. '
            'The app works free with ads for now.';
        _storeDown = true;
        _setState(BillingState.free);
        return;
      }
      _product = response.productDetails.isNotEmpty
          ? response.productDetails.first
          : null;
      if (_product == null) {
        // Product not created/activated in Play Console yet. Free tier
        // works; the upgrade screen explains what Brandon still needs to do.
        _lastError =
            'The Pro subscription is not set up in the Play Store yet.';
        _setState(BillingState.free);
        return;
      }
      // Pulls owned subscriptions (and one-time products) through the
      // purchase stream; _onPurchaseUpdate evaluates the tier.
      await _iap.restorePurchases();
    } catch (e) {
      _lastError = 'Billing check failed: $e. The app works free with ads.';
      _storeDown = true;
      _setState(BillingState.free);
    }
  }

  /// Silent re-check used on app resume: only flips the tier if it actually
  /// changed (e.g. the subscription expired or was cancelled in the Play
  /// Store while the app was away).
  Future<void> recheckEntitlement() async {
    if (!_initialized || _state == BillingState.unknown) return;
    try {
      await _iap.restorePurchases();
    } catch (_) {
      // Keep the current tier; a failed background check must not change
      // anything. The next full refresh surfaces errors.
    }
  }

  /// Launches the Google Play purchase flow for the subscription.
  /// Play applies the 30-day free trial automatically when the base plan's
  /// trial offer makes the user eligible — no local timer involved.
  Future<void> startTrial() async {
    final ProductDetails? product = _product;
    if (product == null) {
      _lastError =
          'The Pro subscription is not available right now. Please retry later.';
      notifyListeners();
      return;
    }
    _lastError = null;
    _purchasePending = true;
    notifyListeners();
    try {
      final bool launched = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!launched) {
        _purchasePending = false;
        _lastError = 'Could not open the Google Play purchase screen.';
        notifyListeners();
      }
      // If launched, the result arrives via the purchase stream; the pending
      // flag clears in _onPurchaseUpdate.
    } catch (e) {
      _purchasePending = false;
      _lastError = 'Purchase failed to start: $e';
      notifyListeners();
    }
  }

  /// Re-queries owned purchases (user-tapped "Restore purchases").
  Future<void> restore() async {
    _lastError = null;
    notifyListeners();
    try {
      await _iap.restorePurchases();
    } catch (e) {
      _lastError = 'Restore failed: $e';
      notifyListeners();
    }
  }

  /// Handles every purchase update from the Play Billing client.
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    _safetyTimer?.cancel();
    bool pending = false;
    bool pro = false;
    for (final PurchaseDetails purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          pending = true;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.productID == kProSubscriptionId &&
              _verifyLocally(purchase)) {
            pro = true;
            if (purchase.pendingCompletePurchase) {
              // Acknowledge with Play. Unacknowledged purchases are
              // auto-refunded after 3 days.
              await _iap.completePurchase(purchase);
            }
          }
          break;
        case PurchaseStatus.error:
          final String? msg = purchase.error?.message;
          _lastError = (msg != null && msg.isNotEmpty)
              ? msg
              : 'The purchase failed.';
          break;
        case PurchaseStatus.canceled:
          // User backed out of the Play sheet; not an error.
          break;
      }
    }

    final bool pendingChanged = pending != _purchasePending;
    _purchasePending = pending;

    final BillingState next = pro ? BillingState.pro : BillingState.free;
    if (next != _state || pendingChanged) {
      _setState(next);
    } else {
      // Error text may have changed even when the state didn't.
      notifyListeners();
    }
  }

  /// Local sanity check on a purchase. This is NOT server-side verification:
  /// a backend calling the Play Developer API is the documented follow-up.
  /// It rejects obviously invalid purchase records (wrong product, empty
  /// verification payload) before granting Pro.
  bool _verifyLocally(PurchaseDetails purchase) {
    return purchase.verificationData.serverVerificationData.isNotEmpty;
  }

  void _setState(BillingState next) {
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
