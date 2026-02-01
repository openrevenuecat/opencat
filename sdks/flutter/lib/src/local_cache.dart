import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'customer_info.dart';

/// Encrypted on-device cache for CustomerInfo using flutter_secure_storage.
class LocalCache {
  static const _customerInfoKey = 'opencat_customer_info';
  static const _offeringsTimestampKey = 'opencat_offerings_cached_at';

  final FlutterSecureStorage _storage;

  LocalCache() : _storage = const FlutterSecureStorage();

  /// Save CustomerInfo to secure storage.
  Future<void> saveCustomerInfo(CustomerInfo info) async {
    final jsonStr = json.encode(info.toJson());
    await _storage.write(key: _customerInfoKey, value: jsonStr);
  }

  /// Load CustomerInfo from secure storage. Returns null if not cached.
  Future<CustomerInfo?> loadCustomerInfo() async {
    final jsonStr = await _storage.read(key: _customerInfoKey);
    if (jsonStr == null) return null;
    try {
      return CustomerInfo.fromJson(
          json.decode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Save the timestamp when offerings were last fetched.
  Future<void> saveOfferingsTimestamp(DateTime timestamp) async {
    await _storage.write(
        key: _offeringsTimestampKey, value: timestamp.toIso8601String());
  }

  /// Load the offerings cache timestamp.
  Future<DateTime?> loadOfferingsTimestamp() async {
    final value = await _storage.read(key: _offeringsTimestampKey);
    if (value == null) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  /// Clear all cached data.
  Future<void> clear() async {
    await _storage.delete(key: _customerInfoKey);
    await _storage.delete(key: _offeringsTimestampKey);
  }
}
