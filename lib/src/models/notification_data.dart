import 'dart:convert';

class NotificationData {
  final String toNumber;
  final String badge;
  final String fromNumber;
  final String sound;
  final List<NotificationMember> members;
  final String body;  
  final String title;  
  final bool isGroup;
  final String? departmentId;
  final List<String> numbers;

  NotificationData({
    required this.badge,
    required this.body,
    required this.fromNumber,
    required this.isGroup, 
    required this.members,
    required this.sound,
    required this.title,
    required this.toNumber,
    required this.departmentId,
    required this.numbers,
  });

  factory NotificationData.fromJson(Map<String,dynamic> data) {
    List members = jsonDecode(data['members']) ?? [];
    List numbers = jsonDecode(data['numbers']) ?? [];
    return NotificationData(
      badge: data['badge'] ?? 0, 
      body: data['body']?.toString() ?? "", 
      fromNumber: data['from_number'] ?? "", 
      isGroup: data['is_group'] == "1", 
      members: members.map((m) => NotificationMember.fromJson(m)).toList(), 
      numbers: numbers.map((e) => e.toString()).toList(),
      sound: data['sound'] ?? "", 
      title: data['title'] ?? "" , 
      toNumber: data['to_number']?.toString() ?? "",
      departmentId: data['group_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "to_number": toNumber, 
      "badge": badge, 
      "from_number": fromNumber, 
      "sound": sound, 
      "members": members.map((m) => m.toJson()).toList(), 
      "body": body, 
      "title": title, 
      "is_group": isGroup ? "1" : "0",
      "group_id": departmentId,
      "numbers": numbers
    };
  }
}

class NotificationMember {
  final String number;
  final String name;
  final String crm_name;
  final String avatar;

  NotificationMember({
    required this.number, 
    required this.crm_name, 
    required this.name,
    required this.avatar,
  });

  factory NotificationMember.fromJson(Map<String,dynamic> data) {
    return NotificationMember(
      number: data['number'],
      name: data['name'],
      crm_name: data['crm_name'],
      avatar: data['avatar'] 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "number": number,
      "name": name,
      "crm_name": crm_name,
      "avatar": avatar,
    };
  }
}