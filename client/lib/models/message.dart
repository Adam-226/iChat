class Message {
  final String id;
  final String fromId;
  final String fromUsername;
  final String fromAvatar;
  final String toId;
  final String toUsername;
  final String toAvatar;
  final String content;
  final String type;
  final bool read;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.fromId,
    required this.fromUsername,
    this.fromAvatar = '',
    required this.toId,
    required this.toUsername,
    this.toAvatar = '',
    required this.content,
    this.type = 'text',
    this.read = false,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? json['_id'] ?? '',
      fromId: json['from']['id'] ?? json['from']['_id'] ?? '',
      fromUsername: json['from']['username'] ?? '',
      fromAvatar: json['from']['avatar'] ?? '',
      toId: json['to']['id'] ?? json['to']['_id'] ?? '',
      toUsername: json['to']['username'] ?? '',
      toAvatar: json['to']['avatar'] ?? '',
      content: json['content'] ?? '',
      type: json['type'] ?? 'text',
      read: json['read'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from': {
        'id': fromId,
        'username': fromUsername,
        'avatar': fromAvatar,
      },
      'to': {
        'id': toId,
        'username': toUsername,
        'avatar': toAvatar,
      },
      'content': content,
      'type': type,
      'read': read,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
