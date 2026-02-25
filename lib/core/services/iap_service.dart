import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'subscription_service.dart';

/// Service to handle In-App Purchases for Android and iOS
class IAPService {
  // Singleton pattern
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // Product IDs - These must match what's configured in App Store Connect and Google Play Console
  static const String productIdMonthly = 'kpss_premium_monthly';
  static const String productId6Monthly = 'kpss_premium_6monthly';
  static const String productIdYearly = 'kpss_premium_yearly';

  static const Set<String> _productIds = {
    productIdMonthly,
    productId6Monthly,
    productIdYearly,
  };

  final SubscriptionService _subscriptionService = SubscriptionService();

  // Status observables
  final _productsController =
      StreamController<List<ProductDetails>>.broadcast();
  Stream<List<ProductDetails>> get productsStream => _productsController.stream;

  final _purchaseStatusController =
      StreamController<PurchaseStatus>.broadcast();
  Stream<PurchaseStatus> get purchaseStatusStream =>
      _purchaseStatusController.stream;

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  void initialize() {
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _subscription.cancel();
      },
      onError: (error) {
        debugPrint('IAP Subscription Error: $error');
      },
    );

    // Initial fetch
    fetchProducts();
  }

  void dispose() {
    _subscription.cancel();
    _productsController.close();
    _purchaseStatusController.close();
  }

  /// Get products from the stores
  Future<void> fetchProducts() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      debugPrint('IAP not available');
      return;
    }

    final ProductDetailsResponse response = await _inAppPurchase
        .queryProductDetails(_productIds);

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products not found: ${response.notFoundIDs}');
    }

    _products = response.productDetails;
    _productsController.add(_products);
    debugPrint('Fetched ${_products.length} products');
  }

  /// Start purchase process
  Future<void> buyProduct(ProductDetails productDetails) async {
    late PurchaseParam purchaseParam;

    if (Platform.isAndroid) {
      // For Android, we can use the specific Android wrapper if needed,
      // but the base PurchaseParam is usually enough for simple cases.
      purchaseParam = GooglePlayPurchaseParam(productDetails: productDetails);
    } else {
      purchaseParam = PurchaseParam(productDetails: productDetails);
    }

    // We use consumable for testing sometimes, but for subscriptions/premium it should be non-consumable
    // However, if we use real Subscriptions (auto-renewable), we'd use buyNonConsumable.
    // Assuming these are non-consumable for "lifetime" or recurring subs.
    // For auto-renewable subscriptions, the behavior is slightly different.

    try {
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('Error starting purchase: $e');
      _purchaseStatusController.add(PurchaseStatus.error);
    }
  }

  /// Restore previously purchased items
  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
    }
  }

  /// Listen to purchase updates
  Future<void> _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _purchaseStatusController.add(PurchaseStatus.pending);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint('Purchase Error: ${purchaseDetails.error}');
        _purchaseStatusController.add(PurchaseStatus.error);
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        bool valid = await _verifyPurchase(purchaseDetails);
        if (valid) {
          await _handleSuccessfulPurchase(purchaseDetails);
          _purchaseStatusController.add(PurchaseStatus.purchased);
        } else {
          _purchaseStatusController.add(PurchaseStatus.error);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  /// Verify purchase (Ideally happens on your server side)
  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // For now, we trust the client (standard for simple apps without backend verification)
    // In a real production app, you'd send purchaseDetails.verificationData.serverVerificationData
    // to your backend or use Firebase Functions to verify with Google/Apple APIs.
    return true;
  }

  /// Handle a successful purchase by updating the local/cloud subscription status
  Future<void> _handleSuccessfulPurchase(
    PurchaseDetails purchaseDetails,
  ) async {
    String type = 'monthly'; // default
    int days = 30;

    if (purchaseDetails.productID == productId6Monthly) {
      type = '6monthly';
      days = 180;
    } else if (purchaseDetails.productID == productIdYearly) {
      type = 'yearly';
      days = 365;
    }

    final endDate = DateTime.now().add(Duration(days: days));

    await _subscriptionService.setSubscriptionStatus(
      status: 'premium',
      type: type,
      endDate: endDate,
    );

    debugPrint('Successful purchase handled for: ${purchaseDetails.productID}');
  }
}
