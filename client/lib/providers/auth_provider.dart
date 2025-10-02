import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> checkAuthentication() async {
    try {
      _isLoading = true;
      notifyListeners();

      final token = await ApiService.getToken();
      if (token == null) {
        _isAuthenticated = false;
        return false;
      }

      _currentUser = await ApiService.getCurrentUser();
      _isAuthenticated = true;
      
      // 连接Socket
      SocketService().connect(token);
      
      return true;
    } catch (e) {
      _isAuthenticated = false;
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String username, String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final data = await ApiService.register(username, email, password);
      _currentUser = User.fromJson(data['user']);
      _isAuthenticated = true;
      
      // 连接Socket
      final token = await ApiService.getToken();
      if (token != null) {
        SocketService().connect(token);
      }
      
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final data = await ApiService.login(email, password);
      _currentUser = User.fromJson(data['user']);
      _isAuthenticated = true;
      
      // 连接Socket
      final token = await ApiService.getToken();
      if (token != null) {
        SocketService().connect(token);
      }
      
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    SocketService().disconnect();
    await ApiService.removeToken();
    _currentUser = null;
    _isAuthenticated = false;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
