import 'dart:convert';

class WsTypingStatus {
  final String departmentId;
  final String conversationId;
  final String to;
  final String uid;
  final String username;
  WsTypingStatus({
    required this.departmentId,
    required this.conversationId,
    required this.to,
    required this.uid,
    required this.username,
  });
  factory WsTypingStatus.fromJson(Map<String, dynamic> data) {
    return WsTypingStatus(
      departmentId: data["groupId"] ?? "",
      conversationId: data["groupConversationId"].toString(),
      to: data["to"] ?? "",
      uid: data["uid"] ?? "",
      username: data["username"] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "groupId": departmentId,
      "groupConversationId": int.parse(conversationId),
      "to": to,
      "uid": uid,
      "username": username,
    };
  }
}
