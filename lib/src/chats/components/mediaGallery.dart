import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/conversation.dart';
import 'package:fusion_mobile_revamped/src/models/messages.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:video_player/video_player.dart';

class MediaGallery extends StatelessWidget {
  final ConversationVM conversationVM;
  final SMSMessage tappedMessage;
  const MediaGallery({
    required this.conversationVM,
    required this.tappedMessage,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    List<SMSMessage> galleryItems = conversationVM.conversationMessages
        .where((SMSMessage message) {
          return message.mime != null && message.mime!.contains("image") ||
              message.mime != null && message.mime!.contains("video");
        })
        .toList()
        .cast<SMSMessage>();
    int currentPage = 0;

    int index = 0;
    for (SMSMessage m in galleryItems) {
      if (m == tappedMessage) currentPage = index;
      index += 1;
    }

    PageController pageController = PageController(initialPage: currentPage);
    return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
            decoration: BoxDecoration(color: Colors.transparent),
            child: PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                SMSMessage message = galleryItems[index];
                if (message.mime!.contains("image"))
                  return PhotoViewGalleryPageOptions(
                    imageProvider: NetworkImage(message.message!),
                    initialScale: PhotoViewComputedScale.contained * 0.8,
                    heroAttributes:
                        PhotoViewHeroAttributes(tag: galleryItems[index].id!),
                  );
                else
                  return PhotoViewGalleryPageOptions.customChild(
                      initialScale: PhotoViewComputedScale.contained * 0.8,
                      heroAttributes:
                          PhotoViewHeroAttributes(tag: galleryItems[index].id!),
                      child: VideoPlayer(
                          VideoPlayerController.network(message.message!)));
              },
              itemCount: galleryItems.length,
              loadingBuilder: (context, event) => Center(
                child: Container(
                  width: 20.0,
                  height: 20.0,
                  child: CircularProgressIndicator(
                    value: event == null
                        ? 0
                        : event.cumulativeBytesLoaded /
                            event.expectedTotalBytes!,
                  ),
                ),
              ),
              backgroundDecoration: BoxDecoration(color: Colors.transparent),
              pageController: pageController,
              onPageChanged: (int page) {},
            )));
  }
}
