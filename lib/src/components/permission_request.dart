import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionRequestScreen extends StatelessWidget {
  final PermissionRequest permissionRequest;
  const PermissionRequestScreen({super.key, required this.permissionRequest});

  void _requestPermission(BuildContext context) async {
    await permissionRequest.permission.request();
    permissionRequest.complete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: coal,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: () => permissionRequest.complete(),
            icon: Text(
              "Skip",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white),
            ),
            label: Icon(
              Icons.chevron_right,
              size: 28,
              color: Colors.white,
            ),
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage("assets/background.png"),
                fit: BoxFit.cover,
                opacity: 0.5)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                permissionRequest.image,
                Positioned(
                  right: 0,
                  width: MediaQuery.of(context).size.width / 1.5,
                  child: Container(
                    child: Text(
                      permissionRequest.permissionTextDescription,
                      style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: Colors.white),
                    ),
                  ),
                )
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 48,
              ),
              margin: EdgeInsets.only(top: 43),
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: crimsonLight,
                      foregroundColor: Colors.white,
                      fixedSize: Size(280, 45),
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 16)),
                  onPressed: () => _requestPermission(context),
                  child: Text(
                    permissionRequest.buttonText,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  )),
            )
          ],
        ),
      ),
    );
  }
}

class PermissionRequest {
  String permissionTextDescription;
  String buttonText;
  Image image;
  Permission permission;
  Function complete;
  RequestStyle? requestStyle;

  PermissionRequest(this.buttonText, this.image, this.permissionTextDescription,
      this.permission, this.complete,
      {this.requestStyle});
}

class RequestStyle {
  double descriptionTextWidth;
  RequestStyle(this.descriptionTextWidth);
}
