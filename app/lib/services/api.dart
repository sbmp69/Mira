import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

// Use 192.168.1.5 for physical device over local network
const String baseUrl = kIsWeb ? 'http://localhost:3000/api' : 'http://192.168.1.5:3000/api';

class AuthApi {
  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userToken', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userToken');
  }
  
  static Future<void> setUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
  }
  
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userToken');
    await prefs.remove('userId');
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400) throw Exception(data['error'] ?? 'Login failed');
    await setToken(data['token']);
    if (data['user'] != null && data['user']['id'] != null) {
      await setUserId(data['user']['id']);
    }
    return data['user'];
  }

  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400) throw Exception(data['error'] ?? 'Signup failed');
    await setToken(data['token']);
    if (data['user'] != null && data['user']['id'] != null) {
      await setUserId(data['user']['id']);
    }
    return data['user'];
  }

  static Future<void> updatePushToken(String pushToken) async {
    final token = await getToken();
    if (token == null) return;
    await http.post(
      Uri.parse('$baseUrl/auth/push-token'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode({'pushToken': pushToken}),
    );
  }
}

class ChatApi {
  static Future<List<dynamic>> getCompanions() async {
    final token = await AuthApi.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/companions'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode >= 400) throw Exception('Failed to fetch companions');
    final data = jsonDecode(response.body);
    return data['companions'];
  }

  static Future<List<dynamic>> getChatHistory(String companionId) async {
    final token = await AuthApi.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/chat/$companionId/history'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['messages'] ?? [];
    } else {
      throw Exception('Failed to load chat history');
    }
  }

  static Future<Map<String, dynamic>> sendMessage(String userId, String companionId, String message, {String? imageBase64, String? audioBase64, String? replyToId}) async {
    final token = await AuthApi.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/chat/send'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'companionId': companionId,
        'message': message,
        if (imageBase64 != null) 'image': imageBase64,
        if (audioBase64 != null) 'audio': audioBase64,
        if (replyToId != null) 'replyToId': replyToId,
      }),
    );
    if (response.statusCode >= 400) throw Exception('Network response was not ok');
    return jsonDecode(response.body);
  }
}
