# OpenCat Flutter SDK Spec

## Reference
- Swift SDK: `sdks/swift/Sources/OpenCat/`
- Kotlin SDK: `sdks/kotlin/` (once implemented)

## Architecture
Flutter plugin with platform channels to native SDKs:

```
lib/
  opencat.dart          # Public API (static methods)
  product_offering.dart # ProductOffering model
  customer_info.dart    # CustomerInfo, EntitlementInfo, TransactionInfo
  configuration.dart    # OpenCatMode enum
ios/
  Classes/
    OpenCatPlugin.swift # Method channel → Swift SDK calls
android/
  src/main/kotlin/
    OpenCatPlugin.kt    # Method channel → Kotlin SDK calls
```

## Public API (match Swift exactly)
```dart
class OpenCat {
  static Future<void> configureStandalone({required String appUserId});
  static Future<void> configureWithServer({
    required String serverUrl,
    required String apiKey,
    required String appUserId,
    String appId = '',
  });
  static Future<List<ProductOffering>> getOfferings({List<String> productIds = const []});
  static Future<TransactionInfo> purchase(String productId);
  static Future<CustomerInfo> restorePurchases();
  static bool isEntitled(String entitlementId);
  static Future<CustomerInfo> getCustomerInfo();
  static void onCustomerInfoUpdate(void Function(CustomerInfo) listener);
  static void setLogLevel(LogLevel level);
}
```

## ProductOffering
```dart
class ProductOffering {
  final String storeProductId;
  final String productType;
  final String displayName;
  final String? description;
  final int priceMicros;
  final String currency;
  final String? subscriptionPeriod;
  final String? trialPeriod;
  final List<String> entitlements;

  double get price => priceMicros / 1000000;
  String get displayPrice => NumberFormat.currency(name: currency).format(price);
}
```

## Platform channel methods
| Method | Args | Returns |
|--------|------|---------|
| `configureStandalone` | `{appUserId}` | void |
| `configureWithServer` | `{serverUrl, apiKey, appUserId, appId}` | void |
| `getOfferings` | `{productIds}` | `List<Map>` |
| `purchase` | `{productId}` | `Map` |
| `restorePurchases` | - | `Map` |
| `isEntitled` | `{entitlementId}` | `bool` |
| `getCustomerInfo` | - | `Map` |
| `setLogLevel` | `{level}` | void |

## Packaging
- Publish to pub.dev: `opencat_flutter`
- Min Dart SDK: 3.0
- Flutter: 3.10+
