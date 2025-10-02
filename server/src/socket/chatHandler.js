const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Message = require('../models/Message');

// 存储在线用户的socket连接
const onlineUsers = new Map();
let ioInstance = null;

const initializeChatSocket = (io) => {
  ioInstance = io;
  io.use(async (socket, next) => {
    let username = 'unknown';
    try {
      console.log(`🔑 [1/5] 收到Socket连接请求`);
      
      const token = socket.handshake.auth.token;
      if (!token) {
        console.log(`🔑 [ERROR] 未提供token`);
        return next(new Error('未提供认证令牌'));
      }
      console.log(`🔑 [2/5] Token存在，长度: ${token.length}`);

      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      console.log(`🔑 [3/5] Token验证成功，userId: ${decoded.userId}`);
      
      const user = await User.findById(decoded.userId)
        .select('-password')
        .populate('friends', '_id');
      console.log(`🔑 [4/5] 用户查询完成: ${user ? user.username : 'null'}`);
      
      if (!user) {
        console.log(`🔑 [ERROR] 用户不存在: ${decoded.userId}`);
        return next(new Error('用户不存在'));
      }

      username = user.username;
      socket.userId = user._id.toString();
      socket.user = user;
      
      console.log(`🔐 [5/5] 认证成功: ${user.username}, 好友数: ${user.friends.length}`);
      
      next();
    } catch (error) {
      console.error(`🔐 认证失败 [user=${username}]: ${error.message}`);
      console.error(`🔐 错误堆栈:`, error.stack);
      next(new Error('认证失败'));
    }
  });

  io.on('connection', async (socket) => {
    try {
      console.log(`用户连接: ${socket.user.username} (${socket.userId})`);

      // 如果该用户已经有连接，先断开旧连接
      const existingSocketId = onlineUsers.get(socket.userId);
      if (existingSocketId && existingSocketId !== socket.id) {
        console.log(`⚠️ 用户 ${socket.user.username} 已有连接，断开旧连接`);
        const existingSocket = io.sockets.sockets.get(existingSocketId);
        if (existingSocket) {
          existingSocket.disconnect(true);
        }
        // 等待旧连接完全断开
        await new Promise(resolve => setTimeout(resolve, 100));
      }

      // 将用户标记为在线
      onlineUsers.set(socket.userId, socket.id);
      console.log(`✅ 用户 ${socket.user.username} Socket ID: ${socket.id}`);
      
      // 不保存用户状态到数据库，避免并发问题
      // 直接在内存中标记为在线
      
      // 通知用户的好友其上线
      socket.user.friends.forEach(friendId => {
        const friendSocketId = onlineUsers.get(friendId.toString());
        if (friendSocketId) {
          io.to(friendSocketId).emit('friend_online', {
            userId: socket.userId,
            username: socket.user.username
          });
        }
      });
      
      console.log(`👥 已通知 ${socket.user.friends.length} 个好友上线`);
    } catch (error) {
      console.error(`❌ 处理用户连接失败: ${error.message}`, error.stack);
      socket.disconnect(true);
      return;
    }

    // 发送私聊消息
    socket.on('send_message', async (data) => {
      try {
        const { to, content, type = 'text' } = data;
        
        console.log(`📨 收到消息: from=${socket.user.username}(${socket.userId}), to=${to}, content="${content}"`);
        console.log(`👥 ${socket.user.username} 的好友列表: [${socket.user.friends.map(f => f._id || f).join(', ')}]`);

        // 验证是否是好友（将ObjectId转换为字符串）
        const friendIds = socket.user.friends.map(f => (f._id || f).toString());
        const isFriend = friendIds.includes(to);
        
        if (!isFriend) {
          console.log(`❌ ${socket.user.username} 尝试向非好友 ${to} 发送消息`);
          console.log(`   好友ID列表: [${friendIds.join(', ')}]`);
          return socket.emit('error', { message: '只能给好友发送消息' });
        }
        
        console.log(`✅ 好友验证通过`);
        console.log(`📤 ${socket.user.username} → ${to}: ${content}`);

        // 保存消息到数据库
        const message = new Message({
          from: socket.userId,
          to,
          content,
          type
        });
        await message.save();

        // 填充用户信息
        await message.populate('from', 'username avatar');
        await message.populate('to', 'username avatar');

        // 如果接收者在线，实时发送消息
        const recipientSocketId = onlineUsers.get(to);
        if (recipientSocketId) {
          io.to(recipientSocketId).emit('receive_message', {
            id: message._id,
            from: {
              id: message.from._id,
              username: message.from.username,
              avatar: message.from.avatar
            },
            to: {
              id: message.to._id,
              username: message.to.username,
              avatar: message.to.avatar
            },
            content: message.content,
            type: message.type,
            read: message.read,
            createdAt: message.createdAt
          });
        }

        // 向发送者确认消息已发送
        socket.emit('message_sent', {
          id: message._id,
          from: {
            id: message.from._id,
            username: message.from.username,
            avatar: message.from.avatar
          },
          to: {
            id: message.to._id,
            username: message.to.username,
            avatar: message.to.avatar
          },
          content: message.content,
          type: message.type,
          read: message.read,
          createdAt: message.createdAt
        });
      } catch (error) {
        console.error('发送消息错误:', error);
        socket.emit('error', { message: '发送消息失败' });
      }
    });

    // 用户正在输入
    socket.on('typing', (data) => {
      const { to } = data;
      const recipientSocketId = onlineUsers.get(to);
      if (recipientSocketId) {
        io.to(recipientSocketId).emit('user_typing', {
          userId: socket.userId,
          username: socket.user.username
        });
      }
    });

    // 用户停止输入
    socket.on('stop_typing', (data) => {
      const { to } = data;
      const recipientSocketId = onlineUsers.get(to);
      if (recipientSocketId) {
        io.to(recipientSocketId).emit('user_stop_typing', {
          userId: socket.userId
        });
      }
    });

    // 用户断开连接
    socket.on('disconnect', async () => {
      console.log(`用户断开连接: ${socket.user.username} (${socket.userId})`);
      
      onlineUsers.delete(socket.userId);
      
      // 更新用户状态为离线
      const user = await User.findById(socket.userId);
      if (user) {
        user.status = 'offline';
        await user.save();

        // 通知用户的好友其离线
        user.friends.forEach(friendId => {
          const friendSocketId = onlineUsers.get(friendId.toString());
          if (friendSocketId) {
            io.to(friendSocketId).emit('friend_offline', {
              userId: socket.userId
            });
          }
        });
      }
    });
  });
};

const getIO = () => {
  if (!ioInstance) {
    throw new Error('Socket.io not initialized');
  }
  return ioInstance;
};

module.exports = { initializeChatSocket, onlineUsers, getIO };
