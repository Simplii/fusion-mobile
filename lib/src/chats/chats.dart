import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/chats/ConversationListView.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/chatsVM.dart';
import 'package:fusion_mobile_revamped/src/components/fusion_dropdown.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
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

class _ChatsState extends State<Chats> {
  FusionConnection get _fusionConnection => widget.fusionConnection;
  Softphone get _softPhone => widget.softPhone;
  SharedPreferences get _sharedPreferences => widget.sharedPreferences;
  late ChatsVM _chatsVM;
  late StreamSubscription<ConnectivityResult> connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _chatsVM = ChatsVM(
      fusionConnection: _fusionConnection,
      softPhone: _softPhone,
      sharedPreferences: _sharedPreferences,
    );
    connectivitySubscription =
        _fusionConnection.connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    setState(() {
      _fusionConnection.connectivityResult = result;
    });
  }

  @override
  dispose() {
    connectivitySubscription.cancel();
    _chatsVM.cancelNotificationsStream();
    super.dispose();
  }

  void _openMenu() {
    Scaffold.of(context).openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _chatsVM,
      builder: (BuildContext context, Widget? child) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                decoration: InputDecoration(
                  hintStyle: TextStyle(
                    color: Color.fromARGB(255, 154, 148, 149),
                  ),
                  hintText: "Search",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      width: 0,
                      style: BorderStyle.none,
                    ),
                  ),
                  fillColor: Color.fromARGB(85, 0, 0, 0),
                  filled: true,
                  prefixIcon: IconButton(
                    icon: Icon(
                      Icons.menu,
                      color: Colors.white,
                    ),
                    onPressed: _openMenu,
                  ),
                ),
                style: TextStyle(color: Colors.white),
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                          top: 16, left: 24, right: 24, bottom: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            height: 30,
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width - 90,
                            ),
                            child: Text(
                              _chatsVM.selectedDepartmentName(),
                              style: headerTextStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          FusionDropdown(
                            selectedNumber: "",
                            onChange: _chatsVM.onGroupChange,
                            value: _chatsVM.selectedDepartmentId,
                            options: _chatsVM.groupOptions(),
                            label: "Select a Department",
                            button: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: translucentSmoke,
                              ),
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.expand_more,
                                size: 30,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: _chatsVM.loading
                          ? Center(
                              child: SpinKitThreeBounce(color: smoke, size: 50),
                            )
                          : ConversationListView(
                              conversations: _chatsVM.conversations,
                              chatsVM: _chatsVM,
                            ),
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
