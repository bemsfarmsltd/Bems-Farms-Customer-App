import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bems_farms/core/network/api_constants.dart';
import 'package:bems_farms/features/auth/data/repositories/token_storage.dart';
import '../models/address_model.dart';

class AddressRepository {
  final http.Client _client;
  final TokenStorage _tokenStorage;

  AddressRepository({http.Client? client, TokenStorage? tokenStorage})
      : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _tokenStorage.getToken();
    return ApiConstants.authHeaders(token ?? '');
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode == 401) {
      throw Exception('Session expired. Please log in again.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMessage = 'API error ${response.statusCode}: ${response.reasonPhrase}';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body.containsKey('message')) {
          errorMessage = body['message'];
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  Future<List<Address>> getAddresses() async {
    final response = await _client.get(
      Uri.parse('${ApiConstants.baseUrl}/addresses/'),
      headers: await _authHeaders(),
    );
    _checkStatus(response);
    final decoded = jsonDecode(response.body);
    List items = [];
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map<String, dynamic>) {
      items = decoded['addresses'] ?? decoded['results'] ?? [];
    }
    return items.whereType<Map<String, dynamic>>().map((e) => Address.fromJson(e)).toList();
  }

  Future<Address> addAddress(Address address) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/addresses/'),
      headers: await _authHeaders(),
      body: jsonEncode(address.toJson()),
    );
    _checkStatus(response);
    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic> && decoded.containsKey('address') 
        ? decoded['address'] 
        : decoded;
    return Address.fromJson(data as Map<String, dynamic>);
  }

  Future<Address> updateAddress(Address address) async {
    final response = await _client.patch(
      Uri.parse('${ApiConstants.baseUrl}/addresses/${address.id}'),
      headers: await _authHeaders(),
      body: jsonEncode(address.toJson()),
    );
    _checkStatus(response);
    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic> && decoded.containsKey('address') 
        ? decoded['address'] 
        : decoded;
    return Address.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteAddress(String id) async {
    final response = await _client.delete(
      Uri.parse('${ApiConstants.baseUrl}/addresses/$id'),
      headers: await _authHeaders(),
    );
    _checkStatus(response);
  }
}
