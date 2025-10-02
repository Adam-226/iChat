import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../models/friend_request.dart';

class ApiService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // 认证相关
  static Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse(ApiConfig.registerEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await saveToken(data['token']);
      return data;
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? '注册失败');
    }
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse(ApiConfig.loginEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveToken(data['token']);
      return data;
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? '登录失败');
    }
  }

  static Future<User> getCurrentUser() async {
    final response = await http.get(
      Uri.parse(ApiConfig.meEndpoint),
      headers: await getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data['user']);
    } else {
      throw Exception('获取用户信息失败');
    }
  }

  // 用户相关
  static Future<List<User>> searchUsers(String query) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.searchUsersEndpoint}?query=$query'),
      headers: await getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['users'] as List)
          .map((json) => User.fromJson(json))
          .toList();
    } else {
      throw Exception('搜索用户失败');
    }
  }

  static Future<List<User>> getFriends() async {
    final response = await http.get(
      Uri.parse(ApiConfig.friendsEndpoint),
      headers: await getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['friends'] as List)
          .map((json) => User.fromJson(json))
          .toList();
    } else {
      throw Exception('获取好友列表失败');
    }
  }

  static Future<void> sendFriendRequest(String userId) async {
    final response = await http.post(
      Uri.parse(ApiConfig.friendRequestEndpoint),
      headers: await getHeaders(),
      body: jsonEncode({'userId': userId}),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? '发送好友请求失败');
    }
  }

  static Future<List<FriendRequest>> getFriendRequests() async {
    final response = await http.get(
      Uri.parse(ApiConfig.friendRequestsEndpoint),
      headers: await getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['requests'] as List)
          .map((json) => FriendRequest.fromJson(json))
          .toList();
    } else {
      throw Exception('获取好友请求失败');
    }
  }

  static Future<void> respondToFriendRequest(
    String requestId,
    bool accept,
  ) async {
    final response = await http.post(
      Uri.parse(ApiConfig.friendRequestRespondEndpoint),
      headers: await getHeaders(),
      body: jsonEncode({
        'requestId': requestId,
        'accept': accept,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('处理好友请求失败');
    }
  }

  // 消息相关
  static Future<List<Message>> getMessageHistory(
    String userId, {
    int limit = 50,
    String? before,
  }) async {
    var url = '${ApiConfig.messageHistoryEndpoint}/$userId?limit=$limit';
    if (before != null) {
      url += '&before=$before';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: await getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['messages'] as List)
          .map((json) => Message.fromJson(json))
          .toList();
    } else {
      throw Exception('获取聊天记录失败');
    }
  }

  static Future<void> markMessagesAsRead(List<String> messageIds) async {
    final response = await http.post(
      Uri.parse(ApiConfig.markReadEndpoint),
      headers: await getHeaders(),
      body: jsonEncode({'messageIds': messageIds}),
    );

    if (response.statusCode != 200) {
      throw Exception('标记消息已读失败');
    }
  }

  static Future<int> getUnreadCount() async {
    final response = await http.get(
      Uri.parse(ApiConfig.unreadCountEndpoint),
      headers: await getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['count'];
    } else {
      throw Exception('获取未读消息数量失败');
    }
  }
}
