import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';

class VMChangeNotifier extends ValueNotifier<SMSConversation?> {
  VMChangeNotifier(SMSConversation? value) : super(value);
  void update(SMSConversation updatedConvo) => value = updatedConvo;
  void reset() => value = null;
}
