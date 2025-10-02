import 'dart:math';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';
import '../models/message.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  Function()? _onConnectCallback;

  bool get isConnected => _isConnected;
  
  // 设置连接成功回调
  void setOnConnectCallback(Function() callback) {
    _onConnectCallback = callback;
  }

  void connect(String token) {
    // 如果已经连接，直接返回
    if (_socket != null && _socket!.connected) {
      print('⚠️ Socket已连接，跳过重复连接');
      return;
    }

    // 如果有旧的socket，先清理
    if (_socket != null) {
      print('⚠️ 清理旧的Socket实例');
      try {
        _socket!.disconnect();
        _socket!.dispose();
      } catch (e) {
        print('清理Socket时出错: $e');
      }
      _socket = null;
      _isConnected = false;
    }

    print('🔌 创建新的Socket连接... Token长度: ${token.length}');
    _socket = IO.io(
      ApiConfig.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()  // 启用自动重连
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .setAuth({'token': token})
          .build(),
    );

    print('🔌 开始连接到服务器...');
    // 手动连接
    _socket!.connect();

    _socket!.onConnect((_) {
      print('✅ Socket 已连接成功！Socket ID: ${_socket!.id}');
      _isConnected = true;
      
      // Socket连接成功后，通知需要重新设置监听器
      if (_onConnectCallback != null) {
        _onConnectCallback!();
      }
    });

    _socket!.onDisconnect((reason) {
      print('❌ Socket 已断开: $reason');
      _isConnected = false;
      
      // 如果是服务器主动断开，尝试重连
      if (reason == 'io server disconnect') {
        print('⚠️ 服务器主动断开连接，2秒后尝试重连...');
        Future.delayed(const Duration(seconds: 2), () {
          if (_socket != null && !_socket!.connected) {
            print('🔄 执行重连...');
            _socket!.connect();
          }
        });
      }
    });

    _socket!.onConnectError((data) {
      print('❌ Socket 连接错误: $data');
      print('   检查Token是否有效，Token长度: ${token.length}');
      _isConnected = false;
    });

    _socket!.onError((data) {
      print('❌ Socket 错误: $data');
    });
    
    // 添加认证错误监听
    _socket!.on('connect_error', (data) {
      print('❌ Socket连接错误详情: $data');
      print('   Token前20字符: ${token.substring(0, min(20, token.length))}...');
    });
    
    // 重连事件
    _socket!.on('reconnect_attempt', (attemptNumber) {
      print('🔄 Socket重连尝试 #$attemptNumber');
    });
    
    _socket!.on('reconnect', (attemptNumber) {
      print('✅ Socket重连成功！尝试次数: $attemptNumber');
      _isConnected = true;
    });
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
    }
  }

  // 发送消息
  void sendMessage(String to, String content, {String type = 'text'}) {
    if (_socket != null && _isConnected) {
      _socket!.emit('send_message', {
        'to': to,
        'content': content,
        'type': type,
      });
    }
  }

  // 移除所有监听器
  void removeAllListeners() {
    if (_socket != null) {
      print('🧹 移除所有Socket监听器');
      _socket!.off('receive_message');
      _socket!.off('message_sent');
      _socket!.off('friend_online');
      _socket!.off('friend_offline');
      _socket!.off('friend_request_accepted');
      _socket!.off('new_friend_request');
      _socket!.off('user_typing');
      _socket!.off('user_stop_typing');
      _socket!.off('error');
    }
  }

  // 监听接收消息
  void onReceiveMessage(Function(Message) callback) {
    _socket?.off('receive_message');  // 先移除旧监听器
    _socket?.on('receive_message', (data) {
      callback(Message.fromJson(data));
    });
  }

  // 监听消息已发送
  void onMessageSent(Function(Message) callback) {
    _socket?.off('message_sent');  // 先移除旧监听器
    _socket?.on('message_sent', (data) {
      callback(Message.fromJson(data));
    });
  }

  // 监听好友上线
  void onFriendOnline(Function(String userId, String username) callback) {
    _socket?.off('friend_online');  // 先移除旧监听器
    _socket?.on('friend_online', (data) {
      print('🔔 Socket收到friend_online事件: ${data['username']}(${data['userId']})');
      callback(data['userId'], data['username']);
    });
  }

  // 监听好友离线
  void onFriendOffline(Function(String userId) callback) {
    _socket?.off('friend_offline');  // 先移除旧监听器
    _socket?.on('friend_offline', (data) {
      print('🔔 Socket收到friend_offline事件: ${data['userId']}');
      callback(data['userId']);
    });
  }

  // 监听好友请求被接受
  void onFriendRequestAccepted(Function(Map<String, dynamic> friendData) callback) {
    _socket?.off('friend_request_accepted');  // 先移除旧监听器
    _socket?.on('friend_request_accepted', (data) {
      callback(data);
    });
  }

  // 监听新的好友请求
  void onNewFriendRequest(Function(Map<String, dynamic> requestData) callback) {
    _socket?.off('new_friend_request');  // 先移除旧监听器
    _socket?.on('new_friend_request', (data) {
      callback(data);
    });
  }

  // 发送正在输入状态
  void sendTyping(String to) {
    if (_socket != null && _isConnected) {
      _socket!.emit('typing', {'to': to});
    }
  }

  // 发送停止输入状态
  void sendStopTyping(String to) {
    if (_socket != null && _isConnected) {
      _socket!.emit('stop_typing', {'to': to});
    }
  }

  // 监听用户正在输入
  void onUserTyping(Function(String userId, String username) callback) {
    _socket?.off('user_typing');  // 先移除旧监听器
    _socket?.on('user_typing', (data) {
      callback(data['userId'], data['username']);
    });
  }

  // 监听用户停止输入
  void onUserStopTyping(Function(String userId) callback) {
    _socket?.off('user_stop_typing');  // 先移除旧监听器
    _socket?.on('user_stop_typing', (data) {
      callback(data['userId']);
    });
  }

  // 监听错误
  void onSocketError(Function(String message) callback) {
    _socket?.off('error');  // 先移除旧监听器
    _socket?.on('error', (data) {
      callback(data['message'] ?? '未知错误');
    });
  }
}
