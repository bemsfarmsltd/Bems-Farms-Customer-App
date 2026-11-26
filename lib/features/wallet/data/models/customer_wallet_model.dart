class CustomerWallet {
  final int? customerId;
  final double balance;
  final double totalToppedUp;
  final double totalSpent;
  final String? accountReference;
  final String? accountNumber;
  final String? bankName;
  final String? bankCode;
  final String? accountName;
  final List<dynamic>? accounts;
  final String? provisionError;
  final bool hasPaymentPin;
  final DateTime? paymentPinSetAt;
  final DateTime? pinLockedUntil;

  const CustomerWallet({
    this.customerId,
    this.balance = 0.0,
    this.totalToppedUp = 0.0,
    this.totalSpent = 0.0,
    this.accountReference,
    this.accountNumber,
    this.bankName,
    this.bankCode,
    this.accountName,
    this.accounts,
    this.provisionError,
    this.hasPaymentPin = false,
    this.paymentPinSetAt,
    this.pinLockedUntil,
  });

  bool get isActivated => accountNumber != null && accountNumber!.trim().isNotEmpty;

  bool get isPinLocked {
    if (pinLockedUntil == null) return false;
    return pinLockedUntil!.isAfter(DateTime.now());
  }

  factory CustomerWallet.fromJson(Map<String, dynamic> json) {
    return CustomerWallet(
      customerId: json['customer_id'] is int ? json['customer_id'] : int.tryParse(json['customer_id']?.toString() ?? ''),
      balance: (json['balance'] is num) ? (json['balance'] as num).toDouble() : (double.tryParse(json['balance']?.toString() ?? '') ?? 0.0),
      totalToppedUp: (json['total_topped_up'] is num) ? (json['total_topped_up'] as num).toDouble() : (double.tryParse(json['total_topped_up']?.toString() ?? '') ?? 0.0),
      totalSpent: (json['total_spent'] is num) ? (json['total_spent'] as num).toDouble() : (double.tryParse(json['total_spent']?.toString() ?? '') ?? 0.0),
      accountReference: json['account_reference']?.toString(),
      accountNumber: json['account_number']?.toString(),
      bankName: json['bank_name']?.toString(),
      bankCode: json['bank_code']?.toString(),
      accountName: json['account_name']?.toString(),
      accounts: json['accounts'] is List ? json['accounts'] as List : null,
      provisionError: json['provision_error']?.toString(),
      hasPaymentPin: json['has_payment_pin'] == true || json['has_payment_pin'] == 1 || json['has_payment_pin'] == 'true',
      paymentPinSetAt: json['payment_pin_set_at'] != null ? DateTime.tryParse(json['payment_pin_set_at'].toString()) : null,
      pinLockedUntil: json['pin_locked_until'] != null ? DateTime.tryParse(json['pin_locked_until'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'balance': balance,
      'total_topped_up': totalToppedUp,
      'total_spent': totalSpent,
      'account_reference': accountReference,
      'account_number': accountNumber,
      'bank_name': bankName,
      'bank_code': bankCode,
      'account_name': accountName,
      'accounts': accounts,
      'provision_error': provisionError,
      'has_payment_pin': hasPaymentPin,
      'payment_pin_set_at': paymentPinSetAt?.toIso8601String(),
      'pin_locked_until': pinLockedUntil?.toIso8601String(),
    };
  }
}

class WalletTransaction {
  final int? id;
  final String type; // "credit" (Top-Up) | "debit" (Order Payment)
  final String? category;
  final double amount;
  final double balanceAfter;
  final String? reference;
  final String? description;
  final DateTime? createdAt;

  const WalletTransaction({
    this.id,
    required this.type,
    this.category,
    this.amount = 0.0,
    this.balanceAfter = 0.0,
    this.reference,
    this.description,
    this.createdAt,
  });

  bool get isCredit => type.toLowerCase() == 'credit';
  bool get isDebit => type.toLowerCase() == 'debit';

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      type: json['type']?.toString().toLowerCase() ?? 'credit',
      category: json['category']?.toString(),
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : (double.tryParse(json['amount']?.toString() ?? '') ?? 0.0),
      balanceAfter: (json['balance_after'] is num) ? (json['balance_after'] as num).toDouble() : (double.tryParse(json['balance_after']?.toString() ?? '') ?? 0.0),
      reference: json['reference']?.toString(),
      description: json['description']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}
