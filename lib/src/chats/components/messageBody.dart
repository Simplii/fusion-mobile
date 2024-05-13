import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageBody extends StatelessWidget {
  final double maxWidth;
  final bool isMe;
  final String messageText;
  final bool isTyping;
  const MessageBody({
    required this.isMe,
    required this.maxWidth,
    required this.messageText,
    required this.isTyping,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: isMe ? coal : Colors.white,
    );
    final urlRegExp = new RegExp(
        r"((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?");
    final urlMatches = urlRegExp.allMatches(messageText).toList();

    int start = 0;
    List<TextSpan> texts = [];

    for (RegExpMatch urlMatch in urlMatches) {
      if (urlMatch.start > start) {
        texts.add(TextSpan(
            text: messageText.substring(start, urlMatch.start), style: style));
      }
      TapGestureRecognizer recognizer = TapGestureRecognizer()
        ..onTap = () {
          String url = messageText.substring(urlMatch.start, urlMatch.end);
          Uri uri =
              Uri.parse(url.startsWith("https://") ? url : "https://$url");
          launchUrl(uri);
        };
      texts.add(TextSpan(
          text: messageText.substring(urlMatch.start, urlMatch.end),
          style: TextStyle(color: crimsonDark),
          recognizer: recognizer));
      start = urlMatch.end;
    }

    texts.add(TextSpan(text: messageText.substring(start), style: style));
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      margin: EdgeInsets.only(top: 2),
      padding: EdgeInsets.only(left: 16, right: 16, top: 6, bottom: 8),
      decoration: BoxDecoration(
        color: isMe ? particle : coal,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isMe ? 8 : 0),
          topRight: Radius.circular(isMe ? 0 : 8),
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: isTyping
          ? SizedBox(
              width: 20,
              child: SpinKitThreeBounce(
                color: Colors.white,
                size: 12,
              ),
            )
          : SelectableText.rich(
              TextSpan(children: texts),
            ),
    );
  }
}
