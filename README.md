# iChat - 跨平台实时聊天应用

一个功能完整的实时聊天应用，支持 Windows、macOS、iOS 和 Android 平台。

## ✨ 功能特性

- 🔐 **用户认证** - 安全的用户注册和登录
- 👥 **好友系统** - 搜索用户、发送好友请求、管理好友列表
- 💬 **实时通讯** - 基于 WebSocket 的即时消息传递
- 🟢 **在线状态** - 实时显示好友在线/离线状态
- ⌨️ **输入提示** - 显示对方正在输入
- 📱 **跨平台** - 支持 iOS、Android、macOS、Windows
- 🎨 **现代 UI** - Material Design 3 设计风格
- 🌙 **深色模式** - 自动适配系统主题

## 🏗️ 技术栈

### 后端
- **Node.js** - 服务器运行环境
- **Express** - Web 框架
- **Socket.io** - 实时通信
- **MongoDB** - 数据库
- **JWT** - 身份认证
- **Bcrypt** - 密码加密

### 前端
- **Flutter** - 跨平台框架
- **Provider** - 状态管理
- **Socket.io Client** - 实时通信
- **Material Design 3** - UI 设计

## 📋 前置要求

### 后端
- Node.js 16+ 
- MongoDB 4.4+

### 前端
- Flutter 3.0+
- Dart 3.0+

## 🚀 快速开始

### 1. 启动后端服务器

```bash
# 进入服务器目录
cd server

# 安装依赖
npm install

# 创建环境变量文件
cp .env.example .env

# 编辑 .env 文件，配置数据库连接和 JWT 密钥
# PORT=3000
# MONGODB_URI=mongodb://localhost:27017/ichat
# JWT_SECRET=your_secret_key_here
# NODE_ENV=development

# 启动 MongoDB（如果本地运行）
# macOS: brew services start mongodb-community
# Windows: net start MongoDB

# 启动服务器
npm start

# 或使用开发模式（自动重启）
npm run dev
```

服务器将在 `http://localhost:3000` 运行

### 2. 启动 Flutter 客户端

```bash
# 进入客户端目录
cd client

# 获取依赖
flutter pub get

# 配置服务器地址
# 编辑 lib/config/api_config.dart
# 将 baseUrl 改为你的服务器地址

# 运行应用

# macOS 桌面版
flutter run -d macos

# Windows 桌面版
flutter run -d windows

# iOS 模拟器
flutter run -d ios

# Android 模拟器
flutter run -d android

# 查看可用设备
flutter devices
```

## 📁 项目结构

```
ichat/
├── server/                 # 后端服务器
│   ├── src/
│   │   ├── models/        # 数据模型
│   │   │   ├── User.js
│   │   │   └── Message.js
│   │   ├── routes/        # API 路由
│   │   │   ├── auth.js
│   │   │   ├── users.js
│   │   │   └── messages.js
│   │   ├── middleware/    # 中间件
│   │   │   └── auth.js
│   │   ├── socket/        # Socket.io 处理
│   │   │   └── chatHandler.js
│   │   └── index.js       # 入口文件
│   ├── package.json
│   └── .env.example
│
└── client/                # Flutter 客户端
    ├── lib/
    │   ├── config/        # 配置文件
    │   │   └── api_config.dart
    │   ├── models/        # 数据模型
    │   │   ├── user.dart
    │   │   ├── message.dart
    │   │   └── friend_request.dart
    │   ├── providers/     # 状态管理
    │   │   ├── auth_provider.dart
    │   │   └── chat_provider.dart
    │   ├── services/      # 服务层
    │   │   ├── api_service.dart
    │   │   └── socket_service.dart
    │   ├── screens/       # 界面
    │   │   ├── splash_screen.dart
    │   │   ├── login_screen.dart
    │   │   ├── register_screen.dart
    │   │   ├── home_screen.dart
    │   │   └── chat_screen.dart
    │   └── main.dart      # 入口文件
    └── pubspec.yaml
```

## 🔧 API 接口

### 认证
- `POST /api/auth/register` - 用户注册
- `POST /api/auth/login` - 用户登录
- `GET /api/auth/me` - 获取当前用户信息

### 用户
- `GET /api/users/search?query=xxx` - 搜索用户
- `POST /api/users/friend-request` - 发送好友请求
- `GET /api/users/friend-requests` - 获取好友请求列表
- `POST /api/users/friend-request/respond` - 处理好友请求
- `GET /api/users/friends` - 获取好友列表

### 消息
- `GET /api/messages/history/:userId` - 获取聊天历史
- `POST /api/messages/mark-read` - 标记消息为已读
- `GET /api/messages/unread-count` - 获取未读消息数量

### WebSocket 事件

#### 客户端发送
- `send_message` - 发送消息
- `typing` - 正在输入
- `stop_typing` - 停止输入

#### 服务器推送
- `receive_message` - 接收消息
- `message_sent` - 消息已发送确认
- `friend_online` - 好友上线
- `friend_offline` - 好友离线
- `user_typing` - 用户正在输入
- `user_stop_typing` - 用户停止输入

## 🌐 部署

### 后端部署

推荐使用以下平台部署后端：
- **Railway** - https://railway.app
- **Render** - https://render.com
- **Heroku** - https://heroku.com
- **DigitalOcean** - https://digitalocean.com

环境变量配置：
```
PORT=3000
MONGODB_URI=mongodb+srv://...
JWT_SECRET=your_production_secret
NODE_ENV=production
```

### 前端部署

#### iOS
```bash
flutter build ios --release
# 使用 Xcode 上传到 App Store
```

#### Android
```bash
flutter build apk --release
# 或构建 App Bundle
flutter build appbundle --release
```

#### macOS
```bash
flutter build macos --release
```

#### Windows
```bash
flutter build windows --release
```

## 🔒 安全注意事项

1. **生产环境必须更改**：
   - JWT_SECRET 密钥
   - MongoDB 数据库密码
   - 启用 HTTPS

2. **建议配置**：
   - 实施速率限制
   - 添加输入验证
   - 启用 CORS 白名单
   - 定期备份数据库

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

## 👨‍💻 作者

iChat Team

## 📞 支持

如有问题，请提交 Issue 或联系我们。

---

**享受聊天吧！ 💬**
