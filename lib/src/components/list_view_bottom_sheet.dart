import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';

class ListViewBottomsheet extends StatelessWidget {
  final String label;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int itemCount;
  const ListViewBottomsheet(
      {Key? key,
      this.label = "",
      required this.itemBuilder,
      required this.itemCount})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height - 100,
      ),
      child: Container(
          margin: EdgeInsets.only(left: 20, right: 20),
          decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                    color: translucentBlack(0.28),
                    offset: Offset.zero,
                    blurRadius: 36)
              ],
              color: coal,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16), topRight: Radius.circular(16))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    label,
                    style: TextStyle(
                        color: smoke,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  )),
              Divider(
                color: lightDivider,
                thickness: 1,
              ),
              LimitedBox(
                maxHeight: MediaQuery.of(context).size.height - 230,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemBuilder: itemBuilder,
                  itemCount: itemCount,
                ),
              ),
              Container(
                margin: EdgeInsets.only(bottom: 25, top: 10),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: offBlack,
                    borderRadius: BorderRadius.all(Radius.circular(44)),
                    boxShadow: [
                      BoxShadow(
                          offset: Offset.fromDirection(90, 2),
                          blurRadius: 2,
                          spreadRadius: 0)
                    ]),
                child: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    padding: EdgeInsets.all(6),
                    icon:
                        Icon(CupertinoIcons.xmark, color: offWhite, size: 12)),
              )
            ],
          )),
    );
  }
}
