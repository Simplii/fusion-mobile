import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';

class CallVM extends ChangeNotifier {
  final EventChannel eventChannel = Softphone.callInfoChannel;
  late final eventStream = eventChannel.receiveBroadcastStream();
  late StreamSubscription stream;
  bool callMonitorReady = false;
  int lowScore = 0;

  CallVM() {
    stream = eventStream.listen((event) {
      // Handle events or data received from the platform
      if (event < 3) {
        lowScore += 1;
      } else {
        lowScore = 0;
      }
      print("MDBM CallVM $event $lowScore");
      callMonitorReady = true;
      return event;
    });
  }

  @override
  void dispose() {
    stream.cancel();
    super.dispose();
  }
}
