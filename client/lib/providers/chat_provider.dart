import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../models/friend_request.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class ChatProvider with ChangeNotifier {
  List<User> _friends = [];
  List<FriendRequest> _friendRequests = [];
  Map<String, List<Message>> _conversations = {};
  Map<String, bool> _typingStatus = {};
  Map<String, int> _unreadCounts = {}; // 每个对话的未读消息数
  int _unreadCount = 0; // 总未读消息数
  String? _currentChatUserId; // 当前正在聊天的用户ID

  List<User> get friends => _friends;
  List<FriendRequest> get friendRequests => _friendRequests;
  Map<String, List<Message>> get conversations => _conversations;
  int get unreadCount => _unreadCount;

  bool isUserTyping(String userId) => _typingStatus[userId] ?? false;
  
  // 获取指定用户的未读消息数
  int getUnreadCount(String userId) => _unreadCounts[userId] ?? 0;
  
  // 设置当前正在聊天的用户
  void setCurrentChatUser(String? userId) {
    print('设置当前聊天用户: $_currentChatUserId -> $userId');
    _currentChatUserId = userId;
    // 不在这里调用 notifyListeners，避免在 build 期间触发重建
  }

  void initialize() {
    _setupSocketListeners();
    
    // 设置Socket连接成功回调，确保每次连接后都重新设置监听器
    SocketService().setOnConnectCallback(() {
      print('🔄 Socket连接成功，重新设置监听器...');
      _setupSocketListeners();
    });
  }

  void _setupSocketListeners() {
    final socketService = SocketService();

    // 接收消息
    socketService.onReceiveMessage((message) {
      _addMessageToConversation(message);
      
      // 如果不是当前正在聊天的用户发来的消息，增加未读计数
      if (_currentChatUserId != message.fromId) {
        _unreadCounts[message.fromId] = (_unreadCounts[message.fromId] ?? 0) + 1;
        _unreadCount++;
        print('收到消息，增加未读: fromId=${message.fromId}, 该用户未读=${_unreadCounts[message.fromId]}, 总未读=${_unreadCount}');
      } else {
        // 如果是当前正在聊天的用户发来的消息，自动标记为已读
        print('收到消息，但用户正在聊天中，不增加未读: fromId=${message.fromId}');
        ApiService.markMessagesAsRead([message.id]).catchError((error) {
          print('自动标记消息已读失败: $error');
        });
      }
      
      notifyListeners();
    });

    // 消息已发送
    socketService.onMessageSent((message) {
      _addMessageToConversation(message);
      notifyListeners();
    });

    // 好友上线
    socketService.onFriendOnline((userId, username) {
      print('📢 收到好友上线通知: $username($userId)');
      final friendIndex = _friends.indexWhere((f) => f.id == userId);
      if (friendIndex != -1) {
        print('✅ 更新好友状态为在线: $username');
        _friends[friendIndex] = _friends[friendIndex].copyWith(status: 'online');
        notifyListeners();
      } else {
        print('⚠️ 好友列表中未找到: $username($userId)');
      }
    });

    // 好友离线
    socketService.onFriendOffline((userId) {
      print('📢 收到好友离线通知: $userId');
      final friendIndex = _friends.indexWhere((f) => f.id == userId);
      if (friendIndex != -1) {
        print('✅ 更新好友状态为离线');
        _friends[friendIndex] = _friends[friendIndex].copyWith(status: 'offline');
        notifyListeners();
      }
    });

    // 用户正在输入
    socketService.onUserTyping((userId, username) {
      _typingStatus[userId] = true;
      notifyListeners();
      
      // 3秒后自动清除输入状态
      Future.delayed(const Duration(seconds: 3), () {
        _typingStatus[userId] = false;
        notifyListeners();
      });
    });

    // 用户停止输入
    socketService.onUserStopTyping((userId) {
      _typingStatus[userId] = false;
      notifyListeners();
    });

    // 好友请求被接受
    socketService.onFriendRequestAccepted((friendData) {
      final newFriend = User.fromJson(friendData);
      if (!_friends.any((f) => f.id == newFriend.id)) {
        _friends.add(newFriend);
        notifyListeners();
      }
    });

    // 收到新的好友请求
    socketService.onNewFriendRequest((requestData) {
      try {
        final newRequest = FriendRequest.fromJson(requestData);
        // 检查是否已经存在
        if (!_friendRequests.any((r) => r.id == newRequest.id)) {
          _friendRequests.add(newRequest);
          print('收到新的好友请求: ${newRequest.from.username}');
          notifyListeners();
        }
      } catch (e) {
        print('处理好友请求通知失败: $e');
      }
    });
  }

  void _addMessageToConversation(Message message) {
    // 生成对话key（始终使用两个用户ID排序后的组合）
    final ids = <String>[message.fromId, message.toId];
    ids.sort();
    final conversationKey = ids.join('_');
    
    if (!_conversations.containsKey(conversationKey)) {
      _conversations[conversationKey] = [];
    }
    
    // 检查是否已经存在相同的消息（避免重复）
    final existingMessage = _conversations[conversationKey]!
        .where((m) => m.id == message.id)
        .isNotEmpty;
    
    if (!existingMessage) {
      _conversations[conversationKey]!.add(message);
      print('消息已添加到对话: ${message.content}');
      print('  发送者: ${message.fromUsername}(${message.fromId})');
      print('  接收者: ${message.toUsername}(${message.toId})');
      print('  对话Key: $conversationKey');
    } else {
      print('⚠️ 消息重复，跳过: ${message.content} (ID: ${message.id})');
    }
  }

  Future<void> loadFriends() async {
    try {
      _friends = await ApiService.getFriends();
      print('✅ 加载了 ${_friends.length} 个好友');
      notifyListeners();
    } catch (e) {
      print('加载好友列表失败: $e');
    }
  }

  Future<void> loadFriendRequests() async {
    try {
      _friendRequests = await ApiService.getFriendRequests();
      notifyListeners();
    } catch (e) {
      print('加载好友请求失败: $e');
    }
  }

  Future<void> loadMessageHistory(String userId, String currentUserId) async {
    try {
      final messages = await ApiService.getMessageHistory(userId);
      final ids = <String>[userId, currentUserId];
      ids.sort();
      final conversationKey = ids.join('_');
      _conversations[conversationKey] = messages;
      notifyListeners();
    } catch (e) {
      print('加载聊天记录失败: $e');
    }
  }

  Future<void> loadUnreadCount() async {
    try {
      _unreadCount = await ApiService.getUnreadCount();
      notifyListeners();
    } catch (e) {
      print('加载未读消息数量失败: $e');
    }
  }

  Future<bool> sendFriendRequest(String userId) async {
    try {
      await ApiService.sendFriendRequest(userId);
      return true;
    } catch (e) {
      print('发送好友请求失败: $e');
      return false;
    }
  }

  Future<bool> respondToFriendRequest(String requestId, bool accept) async {
    try {
      await ApiService.respondToFriendRequest(requestId, accept);
      await loadFriendRequests();
      if (accept) {
        await loadFriends();
      }
      return true;
    } catch (e) {
      print('处理好友请求失败: $e');
      return false;
    }
  }

  void sendMessage(String to, String content) {
    SocketService().sendMessage(to, content);
  }

  void sendTyping(String to) {
    SocketService().sendTyping(to);
  }

  void sendStopTyping(String to) {
    SocketService().sendStopTyping(to);
  }

  List<Message> getConversation(String userId, String currentUserId) {
    final ids = <String>[userId, currentUserId];
    ids.sort();
    final conversationKey = ids.join('_');
    return _conversations[conversationKey] ?? [];
  }

  // 清除指定用户的未读消息计数
  void clearUnreadCount(String userId) {
    final count = _unreadCounts[userId] ?? 0;
    print('清除未读计数: userId=$userId, count=$count, 总未读数=${_unreadCount}');
    
    _unreadCount -= count;
    if (_unreadCount < 0) _unreadCount = 0;
    _unreadCounts[userId] = 0;
    
    print('清除后: 总未读数=${_unreadCount}');
    
    // 延迟通知以避免在build期间调用setState
    Future.microtask(() => notifyListeners());
  }

  // 清除所有数据（用于退出登录）
  void clear() {
    _friends = [];
    _friendRequests = [];
    _conversations = {};
    _typingStatus = {};
    _unreadCounts = {};
    _unreadCount = 0;
    _currentChatUserId = null;
    notifyListeners();
  }
}
