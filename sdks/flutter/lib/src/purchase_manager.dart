import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'errors.dart';

/// Wraps the in_app_purchase plugin for store interactions.
class PurchaseManager {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Completer<PurchaseDetails>? _purchaseCompleter;

  /// Cached offerings with timestamp for 24h staleness.
  List<ProductDetails>? _cachedOfferings;
  DateTime? _offeringsCachedAt;
  static const _offeringsStaleness = Duration(hours: 24);

  Future<void> initialize() async {
    final available = await _iap.isAvailable();
    if (!available) {
      throw OpenCatError.storeError('Store is not available on this device.');
    }
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        _purchaseCompleter?.completeError(
          OpenCatError.storeError(error.toString()),
        );
        _purchaseCompleter = null;
      },
    );
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final details in purchaseDetailsList) {
      if (details.status == PurchaseStatus.purchased ||
          details.status == PurchaseStatus.restored) {
        if (details.pendingCompletePurchase) {
          _iap.completePurchase(details);
        }
        _purchaseCompleter?.complete(details);
        _purchaseCompleter = null;
      } else if (details.status == PurchaseStatus.error) {
        _purchaseCompleter?.completeError(
          OpenCatError.purchaseFailed(
              details.error?.message ?? 'Purchase failed'),
        );
        _purchaseCompleter = null;
      } else if (details.status == PurchaseStatus.canceled) {
        _purchaseCompleter?.completeError(OpenCatError.purchaseCancelled());
        _purchaseCompleter = null;
      }
    }
  }

  /// Get available products. Cached for 24 hours.
  Future<List<ProductDetails>> getOfferings(Set<String> productIds) async {
    if (_cachedOfferings != null &&
        _offeringsCachedAt != null &&
        DateTime.now().difference(_offeringsCachedAt!) < _offeringsStaleness) {
      return _cachedOfferings!;
    }

    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      throw OpenCatError.storeError(
          response.error?.message ?? 'Failed to query products');
    }
    _cachedOfferings = response.productDetails;
    _offeringsCachedAt = DateTime.now();
    return response.productDetails;
  }

  /// Initiate a purchase for the given product.
  Future<PurchaseDetails> purchase(ProductDetails product) async {
    if (_purchaseCompleter != null) {
      throw OpenCatError.purchaseFailed('A purchase is already in progress.');
    }
    _purchaseCompleter = Completer<PurchaseDetails>();
    final purchaseParam = PurchaseParam(productDetails: product);
    final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    if (!started) {
      _purchaseCompleter = null;
      throw OpenCatError.purchaseFailed('Could not initiate purchase.');
    }
    return _purchaseCompleter!.future;
  }

  /// Restore previous purchases.
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  /// Access the raw purchase stream for listening to updates.
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  void dispose() {
    _subscription?.cancel();
  }
}
