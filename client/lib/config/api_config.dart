import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // 自动根据平台选择正确的服务器地址
  static String get baseUrl {
    if (kIsWeb) {
      // Web 浏览器
      return 'http://localhost:3000';
    } else if (Platform.isAndroid) {
      // Android 模拟器使用 10.0.2.2 访问宿主机
      // 真机需要手动改为你的 Mac IP
      const String host = String.fromEnvironment('API_HOST', defaultValue: '10.0.2.2');
      return 'http://$host:3000';
    } else if (Platform.isIOS) {
      // iOS 模拟器可以用 localhost
      // 真机使用 Mac 的局域网 IP
      const String host = String.fromEnvironment('API_HOST', defaultValue: '192.168.10.42');
      return 'http://$host:3000';
    } else {
      // macOS, Windows, Linux
      return 'http://localhost:3000';
    }
  }
  
  static String get apiUrl => '$baseUrl/api';
  static String get socketUrl => baseUrl;
  
  // API端点
  static String get loginEndpoint => '$apiUrl/auth/login';
  static String get registerEndpoint => '$apiUrl/auth/register';
  static String get meEndpoint => '$apiUrl/auth/me';
  static String get searchUsersEndpoint => '$apiUrl/users/search';
  static String get friendRequestEndpoint => '$apiUrl/users/friend-request';
  static String get friendRequestsEndpoint => '$apiUrl/users/friend-requests';
  static String get friendRequestRespondEndpoint => '$apiUrl/users/friend-request/respond';
  static String get friendsEndpoint => '$apiUrl/users/friends';
  static String get messageHistoryEndpoint => '$apiUrl/messages/history';
  static String get markReadEndpoint => '$apiUrl/messages/mark-read';
  static String get unreadCountEndpoint => '$apiUrl/messages/unread-count';
}
