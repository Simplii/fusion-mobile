import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/chats/ConversationListView.dart';
import 'package:fusion_mobile_revamped/src/chats/components/conversationsSerachResults.dart';
import 'package:fusion_mobile_revamped/src/chats/components/convestaionsListViewHeader.dart';
import 'package:fusion_mobile_revamped/src/chats/newConversationView.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/chatsVM.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Chats extends StatefulWidget {
  final FusionConnection fusionConnection;
  final Softphone softPhone;
  final SharedPreferences sharedPreferences;
  const Chats({
    required this.fusionConnection,
    required this.softPhone,
    required this.sharedPreferences,
    super.key,
  });

  @override
  State<Chats> createState() => _ChatsState();
}

class _ChatsState extends State<Chats> with WidgetsBindingObserver {
  FusionConnection get _fusionConnection => widget.fusionConnection;
  Softphone get _softPhone => widget.softPhone;
  SharedPreferences get _sharedPreferences => widget.sharedPreferences;
  late ChatsVM _chatsVM;
  final _searchTextController = TextEditingController();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _chatsVM.onAppStateChanged(state);
  }

  @override
  void initState() {
    super.initState();
    _chatsVM = ChatsVM(
      fusionConnection: _fusionConnection,
      softPhone: _softPhone,
      sharedPreferences: _sharedPreferences,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  dispose() {
    _chatsVM.cancelNotificationsStream();
    _chatsVM.debounce.dispose();
    _searchTextController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _openMenu() {
    Scaffold.of(context).openDrawer();
  }

  void _openNewMessage() {
    showModalBottomSheet(
      routeSettings: RouteSettings(name: 'newMessagePopup'),
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => NewMessageView(
          sharedPreferences: _sharedPreferences, chatsVM: _chatsVM),
    );
  }

  _getFloatingButton() {
    return FloatingActionButton(
      backgroundColor: crimsonLight,
      foregroundColor: Colors.white,
      onPressed: _openNewMessage,
      child: Icon(Icons.add),
    );
  }

  void _resetSearch() {
    setState(() {
      _searchTextController.text = "";
      _chatsVM.searchingForConversation = false;
      _chatsVM.conversationsSearchContacts = [];
      _chatsVM.conversationsSearchCrmContacts = [];
      _chatsVM.foundConversations = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: _getFloatingButton(),
        body: ListenableBuilder(
            listenable: _chatsVM,
            builder: (BuildContext context, Widget? child) {
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                      controller: _searchTextController,
                      decoration: InputDecoration(
                          hintStyle: TextStyle(
                              color: Color.fromARGB(255, 154, 148, 149)),
                          hintText: "Search",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  width: 0, style: BorderStyle.none)),
                          fillColor: Color.fromARGB(85, 0, 0, 0),
                          filled: true,
                          prefixIcon: IconButton(
                              icon: Icon(Icons.menu, color: Colors.white),
                              onPressed: _openMenu)),
                      onChanged: _chatsVM.searchConversations,
                      style: TextStyle(color: Colors.white)),
                ),
                Expanded(
                    child: Container(
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.all(Radius.circular(16))),
                        child: _chatsVM.loading
                            ? Center(
                                child:
                                    SpinKitThreeBounce(color: smoke, size: 50))
                            : _chatsVM.searchingForConversation
                                ? ConversationsSearchResults(
                                    chatsVM: _chatsVM,
                                    resetSearch: _resetSearch,
                                  )
                                : Column(children: [
                                    ConversationsListViewHeader(
                                        chatsVM: _chatsVM),
                                    Expanded(
                                        child: ConversationListView(
                                            conversations:
                                                _chatsVM.conversations,
                                            chatsVM: _chatsVM))
                                  ])))
              ]);
            }));
  }
}
