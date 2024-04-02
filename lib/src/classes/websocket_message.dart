import 'package:fusion_mobile_revamped/src/classes/ws_message_obj.dart';
import 'package:fusion_mobile_revamped/src/classes/ws_typing_status.dart';

abstract class WebsocketMessage {
  static WsMessageObject getMessageObj(Map<String, dynamic> messageObj) {
    return WsMessageObject.fromJson(messageObj);
  }

  static WsTypingStatus getTypingStatus(Map<String, dynamic> typingStatus) {
    return WsTypingStatus.fromJson(typingStatus);
  }
}
