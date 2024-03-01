import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fusion_mobile_revamped/src/models/messages.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PictureMessageBody extends StatelessWidget {
  final SMSMessage message;
  final bool isMe;
  const PictureMessageBody({
    required this.message,
    required this.isMe,
    super.key,
  });

  //TODO: switch to copy image data as blob
  Future<void> _copy(GlobalKey<TooltipState> toolTipKey) async {
    await Clipboard.setData(ClipboardData(text: message.message));
    Clipboard.getData(Clipboard.kTextPlain).then((value) {
      if (value!.text != '') {
        toolTipKey.currentState?.ensureTooltipVisible();
        urlToXFile(Uri.parse(value.text!)).then(
          (value) {
            SharedPreferences.getInstance().then((SharedPreferences prefs) {
              prefs.setString("copiedImagePath", value.path);
            });
          },
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey<TooltipState> toolTipKey = GlobalKey<TooltipState>();
    return GestureDetector(
        onLongPress: () => _copy(toolTipKey),
        onTap: () => print("_openMedia"), //FIXME:
        child: ClipRRect(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isMe ? 8 : 0),
                topRight: Radius.circular(isMe ? 0 : 8),
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8)),
            child: FittedBox(
              child: Container(
                  constraints: BoxConstraints(
                    minWidth: 1,
                    minHeight: 1,
                  ),
                  child: Tooltip(
                    message: 'Copied',
                    key: toolTipKey,
                    triggerMode: TooltipTriggerMode.manual,
                    child: Image.network(message.message),
                  )),
            )));
  }
}
