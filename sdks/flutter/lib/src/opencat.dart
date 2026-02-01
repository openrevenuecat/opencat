import 'dart:async';
import 'dart:io' show Platform;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'configuration.dart';
import 'customer_info.dart';
import 'entitlement_engine.dart';
import 'purchase_manager.dart';
import 'backend_connector.dart';
import 'local_cache.dart';
import 'errors.dart';

export 'errors.dart';

/// Main entry point for the OpenCat SDK.
///
/// Configure with either [configureStandalone] or [configureWithServer],
/// then use the purchase and entitlement APIs.
class OpenCat {
  OpenCat._();

  static bool _configured = false;
  static StandaloneConfiguration? _standaloneConfig;
  static ServerConfiguration? _serverConfig;

  static late PurchaseManager _purchaseManager;
  static BackendConnector? _backendConnector;
  static late LocalCache _cache;

  static CustomerInfo? _cachedCustomerInfo;
  static final _customerInfoController =
      StreamController<CustomerInfo>.broadcast();

  /// Stream of CustomerInfo updates (e.g. renewals, revocations).
  static Stream<CustomerInfo> get customerInfoStream =>
      _customerInfoController.stream;

  // -- Configuration --

  /// Configure in standalone mode (no server, on-device only).
  static Future<void> configureStandalone({
    required String appUserId,
  }) async {
    _standaloneConfig = StandaloneConfiguration(appUserId: appUserId);
    _serverConfig = null;
    await _initialize();
  }

  /// Configure in server mode (full features with OpenCat backend).
  static Future<void> configureWithServer({
    required String serverUrl,
    required String apiKey,
    required String appUserId,
  }) async {
    final config = ServerConfiguration(
      serverUrl: serverUrl,
      apiKey: apiKey,
      appUserId: appUserId,
    );
    _serverConfig = config;
    _standaloneConfig = null;
    _backendConnector = BackendConnector(config);
    await _initialize();
  }

  static Future<void> _initialize() async {
    _cache = LocalCache();
    _purchaseManager = PurchaseManager();
    await _purchaseManager.initialize();

    // Load cached customer info
    _cachedCustomerInfo = await _cache.loadCustomerInfo();

    // Listen for purchase updates to refresh customer info
    _purchaseManager.purchaseStream.listen((purchases) {
      for (final details in purchases) {
        if (details.status == PurchaseStatus.purchased ||
            details.status == PurchaseStatus.restored) {
          _onPurchaseUpdated(details);
        }
      }
    });

    _configured = true;
  }

  static void _ensureConfigured() {
    if (!_configured) throw OpenCatError.notConfigured();
  }

  static String get _appUserId =>
      _serverConfig?.appUserId ?? _standaloneConfig!.appUserId;

  static bool get _isServerMode => _serverConfig != null;

  // -- Public API --

  /// Get available product offerings from the store.
  /// Results are cached for 24 hours.
  static Future<List<ProductDetails>> getOfferings(
      {required Set<String> productIds}) async {
    _ensureConfigured();
    return _purchaseManager.getOfferings(productIds);
  }

  /// Purchase a product by its ID.
  /// In server mode, the receipt is posted to the OpenCat server.
  static Future<CustomerInfo> purchase(String productId) async {
    _ensureConfigured();

    // Find the product from cached offerings or query it
    final products =
        await _purchaseManager.getOfferings({productId});
    final product = products.firstWhere(
      (p) => p.id == productId,
      orElse: () =>
          throw OpenCatError.purchaseFailed('Product "$productId" not found.'),
    );

    final purchaseDetails = await _purchaseManager.purchase(product);

    if (_isServerMode) {
      final store = Platform.isIOS ? 'apple' : 'google';
      final receipt = purchaseDetails.verificationData.serverVerificationData;
      final info = await _backendConnector!.postReceipt(
        productId: productId,
        receiptData: receipt,
        store: store,
      );
      await _updateCustomerInfo(info);
      return info;
    } else {
      // Standalone: build CustomerInfo from on-device data
      return _refreshStandaloneCustomerInfo();
    }
  }

  /// Restore previous purchases.
  static Future<CustomerInfo> restorePurchases() async {
    _ensureConfigured();

    if (_isServerMode) {
      final info = await _backendConnector!.restorePurchases();
      await _updateCustomerInfo(info);
      return info;
    } else {
      await _purchaseManager.restorePurchases();
      return _refreshStandaloneCustomerInfo();
    }
  }

  /// Check if user has an active entitlement. Synchronous, reads from cache.
  static bool isEntitled(String entitlementId) {
    _ensureConfigured();
    return EntitlementEngine.isEntitled(_cachedCustomerInfo, entitlementId);
  }

  /// Get the latest CustomerInfo.
  /// Returns cached data if offline, fetches fresh data if online (server mode).
  static Future<CustomerInfo> getCustomerInfo() async {
    _ensureConfigured();

    if (_isServerMode) {
      try {
        final info = await _backendConnector!.getCustomerInfo();
        await _updateCustomerInfo(info);
        return info;
      } catch (_) {
        // Offline fallback: return cached
        if (_cachedCustomerInfo != null) return _cachedCustomerInfo!;
        rethrow;
      }
    } else {
      if (_cachedCustomerInfo != null) return _cachedCustomerInfo!;
      return _refreshStandaloneCustomerInfo();
    }
  }

  // -- Internal --

  static Future<void> _updateCustomerInfo(CustomerInfo info) async {
    _cachedCustomerInfo = info;
    await _cache.saveCustomerInfo(info);
    _customerInfoController.add(info);
  }

  static void _onPurchaseUpdated(PurchaseDetails details) {
    // Trigger a refresh of customer info when purchases are updated
    if (_isServerMode) {
      _backendConnector!.getCustomerInfo().then(_updateCustomerInfo).catchError((_) {});
    } else {
      _refreshStandaloneCustomerInfo().catchError((_) {});
    }
  }

  /// Build CustomerInfo from on-device restore data in standalone mode.
  static Future<CustomerInfo> _refreshStandaloneCustomerInfo() async {
    // In standalone mode we build a minimal CustomerInfo from restore data.
    // The in_app_purchase plugin doesn't provide entitlement mapping directly,
    // so the app is responsible for mapping product IDs to entitlement IDs.
    final info = _cachedCustomerInfo ??
        CustomerInfo(
          appUserId: _appUserId,
          activeEntitlements: {},
          allTransactions: [],
          firstSeenAt: DateTime.now(),
        );
    await _updateCustomerInfo(info);
    return info;
  }
}
