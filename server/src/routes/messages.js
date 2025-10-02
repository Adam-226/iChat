const express = require('express');
const Message = require('../models/Message');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// 获取与特定用户的聊天历史
router.get('/history/:userId', authMiddleware, async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 50, before } = req.query;

    // 验证对方是否是好友
    const user = await User.findById(req.user._id);
    if (!user.friends.includes(userId)) {
      return res.status(403).json({ error: '只能查看好友的消息记录' });
    }

    const query = {
      $or: [
        { from: req.user._id, to: userId },
        { from: userId, to: req.user._id }
      ]
    };

    if (before) {
      query.createdAt = { $lt: new Date(before) };
    }

    const messages = await Message.find(query)
      .sort({ createdAt: -1 })
      .limit(parseInt(limit))
      .populate('from', 'username avatar')
      .populate('to', 'username avatar');

    res.json({ messages: messages.reverse() });
  } catch (error) {
    console.error('获取聊天历史错误:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

// 标记消息为已读
router.post('/mark-read', authMiddleware, async (req, res) => {
  try {
    const { messageIds } = req.body;

    await Message.updateMany(
      { _id: { $in: messageIds }, to: req.user._id },
      { read: true }
    );

    res.json({ message: '消息已标记为已读' });
  } catch (error) {
    console.error('标记已读错误:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

// 获取未读消息数量
router.get('/unread-count', authMiddleware, async (req, res) => {
  try {
    const count = await Message.countDocuments({
      to: req.user._id,
      read: false
    });

    res.json({ count });
  } catch (error) {
    console.error('获取未读消息数量错误:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

module.exports = router;
