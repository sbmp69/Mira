import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Live Vercel backend - works from anywhere in the world
const String baseUrl = 'https://mira-ruby-six.vercel.app/api';

String get _webClientId => dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

class AuthApi {
  static SupabaseClient get _client => Supabase.instance.client;

  // Get the current Supabase access token
  static String? getToken() {
    return _client.auth.currentSession?.accessToken;
  }

  // Get the current user ID
  static String? getUserId() {
    return _client.auth.currentUser?.id;
  }

  // Sign up with email/password via Supabase Auth
  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
    if (response.user == null) throw Exception('Signup failed');
    // Also register in our backend to create the User profile row
    final token = response.session?.accessToken;
    if (token != null) {
      await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );
    }
    return {'id': response.user!.id, 'email': email, 'name': name};
  }

  // Sign in with email/password via Supabase Auth
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user == null) throw Exception('Login failed');
    return {
      'id': response.user!.id,
      'email': response.user!.email,
      'name': response.user!.userMetadata?['name'] ?? email.split('@')[0],
    };
  }

  // Sign in with Google
  static Future<Map<String, dynamic>> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      serverClientId: _webClientId,
    );
    
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign in aborted');
    
    final googleAuth = await googleUser.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;
    
    if (idToken == null) {
      throw Exception('No ID Token found.');
    }
    
    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    
    if (response.user == null) throw Exception('Supabase sign in failed');
    
    return {
      'id': response.user!.id,
      'email': response.user!.email,
      'name': response.user!.userMetadata?['name'] ?? response.user!.email?.split('@')[0] ?? 'User',
    };
  }

  // Sign out
  static Future<void> logout() async {
    await _client.auth.signOut();
  }

  // Check if user is logged in
  static bool isLoggedIn() {
    return _client.auth.currentSession != null;
  }

  // Delete account
  static Future<void> deleteAccount() async {
    final token = getToken();
    if (token == null) return;
    
    final response = await http.delete(
      Uri.parse('$baseUrl/auth/account'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode >= 400) throw Exception('Failed to delete account');
    await logout();
  }

  static Future<void> updatePushToken(String pushToken) async {
    final token = getToken();
    if (token == null) return;
    await http.post(
      Uri.parse('$baseUrl/auth/push-token'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'pushToken': pushToken}),
    );
  }
}

class ChatApi {
  static Future<List<dynamic>> getCompanions() async {
    final token = AuthApi.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/companions'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode >= 400) throw Exception('Failed to fetch companions');
    final data = jsonDecode(response.body);
    return data['companions'];
  }

  static Future<List<dynamic>> getChatHistory(String companionId) async {
    final token = AuthApi.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/chat/$companionId/history'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['messages'] ?? [];
    } else {
      throw Exception('Failed to load chat history');
    }
  }

  static Future<Map<String, dynamic>> sendMessage(String userId, String companionId, String message, {String? imageBase64, String? audioBase64, String? replyToId}) async {
    final token = AuthApi.getToken();
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
