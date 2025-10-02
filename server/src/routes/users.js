const express = require('express');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');
const { getIO, onlineUsers } = require('../socket/chatHandler');

const router = express.Router();

// 搜索用户
router.get('/search', authMiddleware, async (req, res) => {
  try {
    const { query } = req.query;
    
    if (!query) {
      return res.status(400).json({ error: '请提供搜索关键词' });
    }

    const users = await User.find({
      $and: [
        { _id: { $ne: req.user._id } }, // 排除当前用户
        {
          $or: [
            { username: { $regex: query, $options: 'i' } },
            { email: { $regex: query, $options: 'i' } }
          ]
        }
      ]
    }).select('username email avatar status').limit(20);

    res.json({ users });
  } catch (error) {
    console.error('搜索用户错误:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

// 发送好友请求
router.post('/friend-request', authMiddleware, async (req, res) => {
  try {
    const { userId } = req.body;

    if (!userId) {
      return res.status(400).json({ error: '请提供用户ID' });
    }

    if (userId === req.user._id.toString()) {
      return res.status(400).json({ error: '不能添加自己为好友' });
    }

    const targetUser = await User.findById(userId);
    if (!targetUser) {
      return res.status(404).json({ error: '用户不存在' });
    }

    // 检查是否已经是好友
    if (req.user.friends.includes(userId)) {
      return res.status(400).json({ error: '已经是好友了' });
    }

    // 检查是否已经发送过请求
    const existingRequest = targetUser.friendRequests.find(
      request => request.from.toString() === req.user._id.toString() && request.status === 'pending'
    );

    if (existingRequest) {
      return res.status(400).json({ error: '已经发送过好友请求' });
    }

    // 添加好友请求
    targetUser.friendRequests.push({
      from: req.user._id,
      status: 'pending'
    });
    await targetUser.save();

    // 实时通知接收者有新的好友请求
    try {
      const io = getIO();
      const recipientSocketId = onlineUsers.get(userId);
      if (recipientSocketId) {
        // 填充发送者信息
        const savedUser = await User.findById(userId)
          .populate('friendRequests.from', 'username email avatar status');
        
        const newRequest = savedUser.friendRequests[savedUser.friendRequests.length - 1];
        
        io.to(recipientSocketId).emit('new_friend_request', {
          id: newRequest._id,
          from: {
            id: newRequest.from._id,
            username: newRequest.from.username,
            email: newRequest.from.email,
            avatar: newRequest.from.avatar,
            status: newRequest.from.status
          },
          status: newRequest.status,
          createdAt: newRequest.createdAt
        });
      }
    } catch (error) {
      console.error('发送好友请求通知失败:', error);
    }

    res.json({ message: '好友请求已发送' });
  } catch (error) {
    console.error('发送好友请求错误:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

// 获取好友请求列表
router.get('/friend-requests', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.user._id)
      .populate('friendRequests.from', 'username email avatar status');

    const pendingRequests = user.friendRequests.filter(request => request.status === 'pending');

    res.json({ requests: pendingRequests });
  } catch (error) {
    console.error('获取好友请求错误:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

// 处理好友请求（接受/拒绝）
router.post('/friend-request/respond', authMiddleware, async (req, res) => {
  try {
    const { requestId, accept } = req.body;

    const user = await User.findById(req.user._id);
    const request = user.friendRequests.id(requestId);

    if (!request) {
      return res.status(404).json({ error: '好友请求不存在' });
    }

    if (request.status !== 'pending') {
      return res.status(400).json({ error: '该请求已被处理' });
    }

    if (accept) {
      // 接受好友请求
      request.status = 'accepted';
      user.friends.push(request.from);
      await user.save();

      // 将当前用户添加到对方的好友列表
      const sender = await User.findById(request.from);
      sender.friends.push(user._id);
      await sender.save();

      // 实时通知发送者好友请求已被接受
      try {
        const io = getIO();
        const senderId = request.from.toString();
        const senderSocketId = onlineUsers.get(senderId);
        
        console.log(`📢 尝试通知 ${sender.username}(${senderId}) 好友请求被接受`);
        console.log(`   接受者: ${user.username}(${user._id})`);
        console.log(`   发送者Socket ID: ${senderSocketId ? senderSocketId : '不在线'}`);
        
        if (senderSocketId) {
          io.to(senderSocketId).emit('friend_request_accepted', {
            id: user._id.toString(),
            _id: user._id.toString(),
            username: user.username,
            email: user.email,
            avatar: user.avatar,
            status: user.status
          });
          console.log(`✅ 已发送 friend_request_accepted 事件到 ${sender.username}`);
        } else {
          console.log(`⚠️ ${sender.username} 不在线，无法发送实时通知`);
        }
      } catch (error) {
        console.error('发送实时通知失败:', error);
      }

      res.json({ message: '已接受好友请求' });
    } else {
      // 拒绝好友请求
      request.status = 'rejected';
      await user.save();
      res.json({ message: '已拒绝好友请求' });
    }
  } catch (error) {
    console.error('处理好友请求错误:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

// 获取好友列表
router.get('/friends', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.user._id)
      .populate('friends', '_id username email avatar status');

    res.json({ friends: user.friends });
  } catch (error) {
    console.error('获取好友列表错误:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

module.exports = router;
