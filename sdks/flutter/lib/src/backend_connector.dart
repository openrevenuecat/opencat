import 'dart:convert';
import 'package:http/http.dart' as http;
import 'configuration.dart';
import 'customer_info.dart';
import 'errors.dart';

/// HTTP client for communicating with the OpenCat server in server mode.
class BackendConnector {
  final ServerConfiguration _config;
  final http.Client _client;

  BackendConnector(this._config) : _client = http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_config.apiKey}',
      };

  String get _baseUrl => _config.serverUrl.replaceAll(RegExp(r'/+$'), '');

  /// Fetch the latest CustomerInfo from the server.
  Future<CustomerInfo> getCustomerInfo() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/v1/subscribers/${_config.appUserId}'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return CustomerInfo.fromJson(
            json.decode(response.body) as Map<String, dynamic>);
      }
      throw OpenCatError.networkError(
          'Server returned status ${response.statusCode}');
    } catch (e) {
      if (e is OpenCatError) rethrow;
      throw OpenCatError.networkError(e.toString());
    }
  }

  /// Post a receipt/purchase token to the server for validation.
  Future<CustomerInfo> postReceipt({
    required String productId,
    required String receiptData,
    required String store,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/v1/receipts'),
        headers: _headers,
        body: json.encode({
          'app_user_id': _config.appUserId,
          'product_id': productId,
          'receipt_data': receiptData,
          'store': store,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CustomerInfo.fromJson(
            json.decode(response.body) as Map<String, dynamic>);
      }
      throw OpenCatError.networkError(
          'Server returned status ${response.statusCode}');
    } catch (e) {
      if (e is OpenCatError) rethrow;
      throw OpenCatError.networkError(e.toString());
    }
  }

  /// Restore purchases via server.
  Future<CustomerInfo> restorePurchases() async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/v1/subscribers/${_config.appUserId}/restore'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return CustomerInfo.fromJson(
            json.decode(response.body) as Map<String, dynamic>);
      }
      throw OpenCatError.networkError(
          'Server returned status ${response.statusCode}');
    } catch (e) {
      if (e is OpenCatError) rethrow;
      throw OpenCatError.networkError(e.toString());
    }
  }

  void dispose() {
    _client.close();
  }
}
