enum Store { apple, google }

enum TransactionStatus { active, expired, refunded, gracePeriod, billingRetry }

class EntitlementInfo {
  final String id;
  final bool isActive;
  final DateTime? expirationDate;
  final String productId;
  final Store store;
  final bool willRenew;
  final DateTime purchaseDate;

  const EntitlementInfo({
    required this.id,
    required this.isActive,
    this.expirationDate,
    required this.productId,
    required this.store,
    required this.willRenew,
    required this.purchaseDate,
  });

  factory EntitlementInfo.fromJson(Map<String, dynamic> json) {
    return EntitlementInfo(
      id: json['id'] as String,
      isActive: json['is_active'] as bool,
      expirationDate: json['expiration_date'] != null
          ? DateTime.parse(json['expiration_date'] as String)
          : null,
      productId: json['product_id'] as String,
      store: json['store'] == 'apple' ? Store.apple : Store.google,
      willRenew: json['will_renew'] as bool,
      purchaseDate: DateTime.parse(json['purchase_date'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'is_active': isActive,
        'expiration_date': expirationDate?.toIso8601String(),
        'product_id': productId,
        'store': store == Store.apple ? 'apple' : 'google',
        'will_renew': willRenew,
        'purchase_date': purchaseDate.toIso8601String(),
      };
}

class TransactionInfo {
  final String transactionId;
  final String productId;
  final DateTime purchaseDate;
  final DateTime? expirationDate;
  final TransactionStatus status;

  const TransactionInfo({
    required this.transactionId,
    required this.productId,
    required this.purchaseDate,
    this.expirationDate,
    required this.status,
  });

  factory TransactionInfo.fromJson(Map<String, dynamic> json) {
    return TransactionInfo(
      transactionId: json['transaction_id'] as String,
      productId: json['product_id'] as String,
      purchaseDate: DateTime.parse(json['purchase_date'] as String),
      expirationDate: json['expiration_date'] != null
          ? DateTime.parse(json['expiration_date'] as String)
          : null,
      status: _parseStatus(json['status'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'transaction_id': transactionId,
        'product_id': productId,
        'purchase_date': purchaseDate.toIso8601String(),
        'expiration_date': expirationDate?.toIso8601String(),
        'status': _statusToString(status),
      };

  static TransactionStatus _parseStatus(String s) {
    switch (s) {
      case 'active':
        return TransactionStatus.active;
      case 'expired':
        return TransactionStatus.expired;
      case 'refunded':
        return TransactionStatus.refunded;
      case 'grace_period':
        return TransactionStatus.gracePeriod;
      case 'billing_retry':
        return TransactionStatus.billingRetry;
      default:
        return TransactionStatus.expired;
    }
  }

  static String _statusToString(TransactionStatus s) {
    switch (s) {
      case TransactionStatus.active:
        return 'active';
      case TransactionStatus.expired:
        return 'expired';
      case TransactionStatus.refunded:
        return 'refunded';
      case TransactionStatus.gracePeriod:
        return 'grace_period';
      case TransactionStatus.billingRetry:
        return 'billing_retry';
    }
  }
}

class CustomerInfo {
  final String appUserId;
  final Map<String, EntitlementInfo> activeEntitlements;
  final List<TransactionInfo> allTransactions;
  final DateTime firstSeenAt;

  const CustomerInfo({
    required this.appUserId,
    required this.activeEntitlements,
    required this.allTransactions,
    required this.firstSeenAt,
  });

  factory CustomerInfo.fromJson(Map<String, dynamic> json) {
    final entitlements = <String, EntitlementInfo>{};
    if (json['active_entitlements'] != null) {
      (json['active_entitlements'] as Map<String, dynamic>)
          .forEach((key, value) {
        entitlements[key] =
            EntitlementInfo.fromJson(value as Map<String, dynamic>);
      });
    }

    final transactions = <TransactionInfo>[];
    if (json['all_transactions'] != null) {
      for (final t in json['all_transactions'] as List) {
        transactions.add(TransactionInfo.fromJson(t as Map<String, dynamic>));
      }
    }

    return CustomerInfo(
      appUserId: json['app_user_id'] as String,
      activeEntitlements: entitlements,
      allTransactions: transactions,
      firstSeenAt: DateTime.parse(json['first_seen_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'app_user_id': appUserId,
        'active_entitlements':
            activeEntitlements.map((k, v) => MapEntry(k, v.toJson())),
        'all_transactions': allTransactions.map((t) => t.toJson()).toList(),
        'first_seen_at': firstSeenAt.toIso8601String(),
      };
}
