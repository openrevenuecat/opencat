import 'customer_info.dart';

/// Resolves entitlement status from CustomerInfo.
class EntitlementEngine {
  /// Check if a specific entitlement is currently active.
  /// An entitlement is active if it exists in activeEntitlements and
  /// either has no expiration date (lifetime) or the expiration date is in the future.
  static bool isEntitled(CustomerInfo? customerInfo, String entitlementId) {
    if (customerInfo == null) return false;
    final entitlement = customerInfo.activeEntitlements[entitlementId];
    if (entitlement == null) return false;
    if (!entitlement.isActive) return false;

    // Lifetime purchase (no expiration)
    if (entitlement.expirationDate == null) return true;

    // Check if expiration is in the future
    return entitlement.expirationDate!.isAfter(DateTime.now());
  }

  /// Filter activeEntitlements to only those that are truly still active
  /// based on their expiration dates.
  static Map<String, EntitlementInfo> resolveActiveEntitlements(
      CustomerInfo customerInfo) {
    final resolved = <String, EntitlementInfo>{};
    for (final entry in customerInfo.activeEntitlements.entries) {
      final e = entry.value;
      if (!e.isActive) continue;
      if (e.expirationDate == null || e.expirationDate!.isAfter(DateTime.now())) {
        resolved[entry.key] = e;
      }
    }
    return resolved;
  }
}
