import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bems_farms/core/network/api_constants.dart';
import 'package:bems_farms/features/auth/data/repositories/token_storage.dart';

class AIRepository {
  final http.Client _client;
  final TokenStorage _tokenStorage;

  AIRepository({http.Client? client, TokenStorage? tokenStorage})
      : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _tokenStorage.getToken();
    return ApiConstants.authHeaders(token ?? '');
  }

  Future<Map<String, dynamic>> getRecommendations({
    required String dietaryNeed,
    required String budget,
    required String familySize,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/ai/recommendations'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'dietary_need': dietaryNeed,
        'budget': budget,
        'family_size': familySize,
      }),
    );
    _checkStatus(response);
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getCoPurchases(String productId) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/ai/co-purchase'),
      headers: await _authHeaders(),
      body: jsonEncode({'product_id': productId}),
    );
    _checkStatus(response);
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getRecipeHelper(String recipeName) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/ai/recipe-helper'),
      headers: await _authHeaders(),
      body: jsonEncode({'recipe_name': recipeName}),
    );
    _checkStatus(response);
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> chat(List<Map<String, String>> messages, {String? sessionId}) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/ai/chat'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'messages': messages,
        if (sessionId != null) 'session_id': sessionId,
      }),
    );
    _checkStatus(response);
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> chefChat(String message, {String? sessionId}) async {
    final payload = {
      'message': message,
      'bot_type': 'chef',
      if (sessionId != null) 'session_id': sessionId,
    };
    print('Sending to /ai/chef-chat: $payload');
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/ai/chef-chat'),
      headers: await _authHeaders(),
      body: jsonEncode(payload),
    );
    print('Response from /ai/chef-chat: ${response.statusCode} ${response.body}');
    _checkStatus(response);
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> visualScan(String base64Image) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/ai/visual-scan'),
      headers: await _authHeaders(),
      body: jsonEncode({'image': base64Image}),
    );
    _checkStatus(response);
    return jsonDecode(response.body);
  }

  // --- Context / History APIs ---

  Future<List<dynamic>> getConversations({String? botType}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/ai/context/conversations').replace(
      queryParameters: botType != null ? {'bot_type': botType} : null,
    );
    print('Fetching conversations from $uri');
    final response = await _client.get(
      uri,
      headers: await _authHeaders(),
    );
    print('Conversations response: ${response.statusCode} ${response.body}');
    _checkStatus(response);
    final data = jsonDecode(response.body);
    
    // The backend uses the "conversations" key!
    if (data is List) return data;
    if (data is Map) {
      if (data['conversations'] is List) return data['conversations'];
      if (data['data'] is List) return data['data'];
      if (data['results'] is List) return data['results'];
    }
    return [];
  }

  Future<Map<String, dynamic>> getConversationById(String id) async {
    final response = await _client.get(
      Uri.parse('${ApiConstants.baseUrl}/ai/context/conversations/$id'),
      headers: await _authHeaders(),
    );
    _checkStatus(response);
    final data = jsonDecode(response.body);
    
    if (data is Map && data.containsKey('data') && data['data'] is Map) {
      return data['data'];
    }
    if (data is Map && data.containsKey('conversation') && data['conversation'] is Map) {
      return data['conversation'];
    }
    return data;
  }

  Future<void> renameConversation(String id, String title) async {
    final response = await _client.patch(
      Uri.parse('${ApiConstants.baseUrl}/ai/context/conversations/$id'),
      headers: await _authHeaders(),
      body: jsonEncode({'title': title}),
    );
    _checkStatus(response);
  }

  Future<void> deleteConversation(String id) async {
    final response = await _client.delete(
      Uri.parse('${ApiConstants.baseUrl}/ai/context/conversations/$id'),
      headers: await _authHeaders(),
    );
    _checkStatus(response);
  }


  // GET /api/ai/context/me (Customer Food Profile)
  Future<Map<String, dynamic>> getCustomerFoodProfile() async {
    final response = await _client.get(
      Uri.parse('${ApiConstants.baseUrl}/ai/context/me'),
      headers: await _authHeaders(),
    );
    _checkStatus(response);
    return jsonDecode(response.body);
  }

  // PATCH /api/ai/context/me (Update Customer Food Profile)
  Future<void> updateCustomerFoodProfile(Map<String, dynamic> data) async {
    final response = await _client.patch(
      Uri.parse('${ApiConstants.baseUrl}/ai/context/me'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );
    _checkStatus(response);
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
        } else if (body is Map && body.containsKey('detail')) {
          errorMessage = body['detail'];
        }
      } catch (_) {
        // ignore
      }
      throw Exception(errorMessage);
    }
  }
}
