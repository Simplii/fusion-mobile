import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/chats/chatsVM.dart';
import 'package:fusion_mobile_revamped/src/chats/components/conversationListRow.dart';
import 'package:fusion_mobile_revamped/src/chats/conversationView.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';

class ConversationListView extends StatefulWidget {
  final List<SMSConversation> conversations;
  final ChatsVM chatsVM;
  const ConversationListView({
    required this.conversations,
    required this.chatsVM,
    super.key,
  });

  @override
  State<ConversationListView> createState() => _ConversationListViewState();
}

class _ConversationListViewState extends State<ConversationListView> {
  List<SMSConversation> get _conversations => widget.conversations;
  ChatsVM get _chatsVM => widget.chatsVM;
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreData);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  //FIXME: fix load more convos
  void _loadMoreData() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_chatsVM.loading) {
      // User has reached the end of the list
      // Load more data or trigger pagination in flutter
      print('MDBM end of list');
    }
  }

  //Routes
  void _openConversation(SMSConversation convo) {
    // _fusionConnection.conversations.markRead(convo);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ConversationView(
          conversation: convo,
          chatsVM: _chatsVM,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _conversations.length,
      itemBuilder: (BuildContext context, int index) {
        return GestureDetector(
          onTap: () => _openConversation(_conversations[index]),
          child: Dismissible(
            key: ValueKey<SMSConversation>(_conversations[index]),
            direction: DismissDirection.endToStart,
            background: Container(
              color: crimsonDark,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Icon(Icons.delete, color: Colors.white),
                ),
              ),
            ),
            onDismissed: (DismissDirection direction) {
              _chatsVM.deleteConversation(conversationIndex: index);
            },
            confirmDismiss: (DismissDirection direction) async {
              return await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Confirm"),
                    content: const Text(
                        "Are you sure you wish to delete this conversation?"),
                    actions: <Widget>[
                      TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: crimsonDark,
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text("DELETE")),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text("CANCEL"),
                      ),
                    ],
                  );
                },
              );
            },
            child: ConversationRow(
              convo: _conversations[index],
              chatsVM: _chatsVM,
            ),
          ),
        );
      },
    );
  }
}
