import 'dart:convert';

import 'package:flutter/foundation.dart';

class WsMessageObject {
  final int id;
  final String mime;
  final String from;
  final String to;
  final String time;
  final bool media;
  final String messageStatus;
  final String type;
  final bool convertedMMS;
  final bool isGroup;
  final bool read;
  final int unixtime;
  final String? user;
  final bool smsWebhookId;
  final String domain;
  final String message;
  final bool scheduledAt;
  final bool smsCampaignId;
  final bool flagged;
  final String flag;
  final String flagLevel;
  final String errorMessage;

  WsMessageObject({
    required this.id,
    required this.mime,
    required this.from,
    required this.to,
    required this.time,
    required this.media,
    required this.messageStatus,
    required this.type,
    required this.convertedMMS,
    required this.isGroup,
    required this.read,
    required this.unixtime,
    required this.smsWebhookId,
    required this.user,
    required this.domain,
    required this.message,
    required this.scheduledAt,
    required this.smsCampaignId,
    required this.flagged,
    required this.flag,
    required this.flagLevel,
    required this.errorMessage,
  });

  factory WsMessageObject.fromJson(Map<String, dynamic> data) {
    return WsMessageObject(
      id: data["id"],
      mime: data["mime"],
      from: data["from"],
      to: data["to"],
      time: data["time"],
      media: data["media"],
      messageStatus: data.containsKey("message_status")
          ? data["message_status"] ?? ""
          : "",
      type: data["type"],
      convertedMMS: data["converted_mms"] == 1,
      isGroup: data["is_group"],
      read: data["read"] == 1,
      unixtime: data["unixtime"],
      smsWebhookId: data["sms_webhook_id"],
      user: data.containsKey("user") && data["user"].runtimeType == String
          ? data["user"]
          : null,
      domain: data["domain"].runtimeType == String ? data["domain"] : "",
      message: data["message"],
      scheduledAt: data["scheduled_at"],
      smsCampaignId: data["sms_campaign_id"],
      flagged: data["flagged"],
      flag: data["flag"],
      flagLevel: data["flagLevel"],
      errorMessage: data["error_message"],
    );
  }
}
