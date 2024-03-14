import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';

class CallVM extends ChangeNotifier {
  final EventChannel eventChannel = Softphone.callInfoChannel;
  late final eventStream = eventChannel.receiveBroadcastStream();
  late StreamSubscription stream;

  CallVM() {
    stream = eventStream.listen((event) {
      // Handle events or data received from the platform
      print("MDBM CallInfoStream st ${event}");
      return event;
    });
  }

  @override
  void dispose() {
    stream.cancel();
    super.dispose();
  }
}
