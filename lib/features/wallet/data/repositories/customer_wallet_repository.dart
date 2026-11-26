import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/network/api_constants.dart';
import '../../../auth/data/repositories/token_storage.dart';
import '../models/customer_wallet_model.dart';

class CustomerWalletData {
  final CustomerWallet wallet;
  final List<WalletTransaction> transactions;

  const CustomerWalletData({
    required this.wallet,
    this.transactions = const [],
  });
}

class CustomerWalletRepository {
  final http.Client _client;
  final TokenStorage _tokenStorage;

  CustomerWalletRepository({
    http.Client? client,
    TokenStorage? tokenStorage,
  })  : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _tokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      return ApiConstants.authHeaders(token);
    }
    return ApiConstants.defaultHeaders();
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMessage = 'Server error (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map) {
          errorMessage = body['message'] ?? body['error'] ?? body['detail'] ?? errorMessage;
        }
      } catch (_) {
        if (response.body.isNotEmpty && !response.body.contains('<html')) {
          errorMessage = response.body;
        }
      }
      throw Exception(errorMessage);
    }
  }

  /// 1. Fetch Wallet Balance, Dedicated NUBAN details & Latest Transactions
  Future<CustomerWalletData> getWallet() async {
    final response = await _client.get(
      Uri.parse('${ApiConstants.baseUrl}/wallet'),
      headers: await _getHeaders(),
    );
    _checkStatus(response);

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final walletJson = decoded['wallet'] as Map<String, dynamic>? ?? {};
    final transactionsList = (decoded['transactions'] as List<dynamic>? ?? [])
        .map((t) => WalletTransaction.fromJson(t as Map<String, dynamic>))
        .toList();

    return CustomerWalletData(
      wallet: CustomerWallet.fromJson(walletJson),
      transactions: transactionsList,
    );
  }

  /// 2. Activate Dedicated Bank Account (BVN / NIN Submission)
  Future<CustomerWalletData> provisionWallet({
    String? phone,
    String? bvn,
    String? nin,
  }) async {
    final payload = <String, dynamic>{};
    if (phone != null && phone.trim().isNotEmpty) {
      payload['phone'] = phone.trim();
    }
    if (bvn != null && bvn.trim().isNotEmpty) {
      payload['bvn'] = bvn.trim();
    } else if (nin != null && nin.trim().isNotEmpty) {
      payload['nin'] = nin.trim();
    }

    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/wallet/provision'),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );
    _checkStatus(response);

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final walletJson = decoded['wallet'] as Map<String, dynamic>? ?? {};
    final transactionsList = (decoded['transactions'] as List<dynamic>? ?? [])
        .map((t) => WalletTransaction.fromJson(t as Map<String, dynamic>))
        .toList();

    return CustomerWalletData(
      wallet: CustomerWallet.fromJson(walletJson),
      transactions: transactionsList,
    );
  }

  /// 3. First-time PIN setup (has_payment_pin == false)
  Future<Map<String, dynamic>> setPin(String pin) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/wallet/pin'),
      headers: await _getHeaders(),
      body: jsonEncode({'pin': pin}),
    );
    _checkStatus(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Change existing PIN (using current PIN)
  Future<Map<String, dynamic>> changePin({
    required String pin,
    required String currentPin,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/wallet/pin'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'pin': pin,
        'current_pin': currentPin,
      }),
    );
    _checkStatus(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Reset forgotten PIN (authorized with account password)
  Future<Map<String, dynamic>> resetPin({
    required String pin,
    required String accountPassword,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/wallet/pin'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'pin': pin,
        'account_password': accountPassword,
      }),
    );
    _checkStatus(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
