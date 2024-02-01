import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend/fusion_connection.dart';
import 'styles.dart';

class LoginView extends StatefulWidget {
  final FusionConnection? _fusionConnection;
  final Function(String username, String? password) _onLogin;

  LoginView(this._onLogin, this._fusionConnection, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  FusionConnection? get _fusionConnection => widget._fusionConnection;

  Function(String username, String? password) get _onLogin => widget._onLogin;
  final _usernameController =
      TextEditingController.fromValue(TextEditingValue(text: ""));
  final _passwordController =
      TextEditingController.fromValue(TextEditingValue(text: ""));
  bool? _wasSuccessful = null;
  bool _isPending = false;

  @override
  initState() {
    super.initState();
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      String? username = prefs.getString("username");
      if (username != null) {
        _usernameController.text = username;

        _fusionConnection!
            .login(username, null,
                (bool success) {
                  if (success) {
                    _wasSuccessful = true;
                    _onLogin(
                        _usernameController.value.text,
                        null);
                  }
                  if (mounted != null && mounted)
                    this.setState(() {});
                });
      }
    });
  }

  _usernameInput() {
    return Flexible(
        child: TextField(
          style: TextStyle( color: Colors.white),
            decoration:  InputDecoration(
                filled: true,
                fillColor: translucentBlack(0.5),
                contentPadding: EdgeInsets.only(left: 8, top: 0, right: 8, bottom: 0),
                hintStyle: TextStyle(color: ash),
                focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(
                            color: translucentBlack(0.5),
                            width: 2.0,
                            style: BorderStyle.solid)),
                border: OutlineInputBorder(
                    borderSide:
                        BorderSide(
                            color: translucentBlack(1),
                            width: 1.0,
                            style: BorderStyle.solid)),
                hintText: "Username"),
            controller: _usernameController));
  }

  _passwordInput() {
    return Flexible(
        child: TextField(
            obscureText: true,
            style: TextStyle( color: Colors.white),
            decoration:  InputDecoration(
                filled: true,
                fillColor: translucentBlack(0.5),
                focusColor: translucentBlack(0.3),
                contentPadding: EdgeInsets.only(left: 8, top: 0, right: 8, bottom: 0),
                hintStyle: TextStyle(color: ash),
                focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(
                            color: translucentBlack(0.5),
                            width: 2.0,
                            style: BorderStyle.solid)),
                border: OutlineInputBorder(
                    borderSide:
                        BorderSide(
                            color: translucentBlack(1),
                            width: 1.0,
                            style: BorderStyle.solid)),
                hintText: "Password"),
            controller: _passwordController));
  }

  _loginButton() {
    return ElevatedButton(
        style: ButtonStyle(
            backgroundColor: MaterialStateColor.resolveWith((state) {
          return crimsonLight;
        }), foregroundColor: MaterialStateColor.resolveWith((state) {
          return Colors.white;
        })),
        onPressed: _login,
        child: Text("Log in", style: TextStyle(
            fontSize: 16,
            color: Colors.white)));
  }

  _login() {
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      prefs.setString("username", _usernameController.value.text); });
    
    this.setState(() {
      _isPending = true;
    });

    Timer loginTimeout = Timer(Duration(seconds: 15), () {
      setState(() {
        _isPending = false;
      });
    });

    _fusionConnection!
        .login(_usernameController.value.text, _passwordController.value.text,
            (bool success) {
      if (success) {
        _wasSuccessful = true;
        _onLogin(
            _usernameController.value.text, _passwordController.value.text);
      } else {
        _wasSuccessful = false;
      }
      loginTimeout.cancel();
      this.setState(() {
        _isPending = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [
      Container(margin: EdgeInsets.only(top:12, bottom: 6),
        alignment: Alignment.centerLeft,
        child: Text(
            "Username",
            textAlign: TextAlign.left,
            style: TextStyle(color: ash, fontSize: 14)),
      ),
      Row(children: [_usernameInput()]),
      Container(margin: EdgeInsets.only(top:12, bottom: 6),
        alignment: Alignment.centerLeft,
        child: Text(
            "Password",
            textAlign: TextAlign.left,
            style: TextStyle(color: ash, fontSize: 14)),
      ),
      Row(children: [_passwordInput()]),
      Container(height: 20)
    ];

    if (_wasSuccessful == false) {
      children.add(Row(children: [
        Expanded(
            child: Container(
                margin: EdgeInsets.only(top: 8, bottom: 0),
                child: Center(
                    child: Text("Incorrect username or password",
                        style: TextStyle(color: crimsonLight)))))
      ]));
    }

    children.add(Row(children: [
      Expanded(
          child: _isPending ? SpinKitWave(color: smoke, size: 25) : _loginButton())
    ]));

    return Container(
        decoration: BoxDecoration(color: Colors.transparent),
        child: Column(
          children: [
            Row(children: [
              Expanded(
                  child: Center(
                      child: Container(
                          margin: EdgeInsets.only(top: 48, bottom: 8, left: 56, right: 56),
                          child: Image.asset("assets/simplii_logo.png")))),
            ]),
            Row(children: [
              Expanded(
                  child: Center(
                      child: Container(
                          margin: EdgeInsets.only(top: 8, bottom: 8, left: 96, right: 96),
                          child: Image.asset("assets/fusion.png")))),
            ]),
            Row(children: [
              Expanded(
                  child: Container(
                      padding: EdgeInsets.only(top:24, left: 32, right: 32, bottom: 36),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          boxShadow: tripleShadow(),
                          border: Border.all(color: translucentBlack(0.16), width: 1.0),
                          color: coal),//Color.fromARGB(255, 255, 255, 255)),
                      margin:
                          EdgeInsets.only(left: 32.0, right: 32.0, top: 24.0),
                      child: Column(children: children)))
            ])
          ],
        ));
  }
}
