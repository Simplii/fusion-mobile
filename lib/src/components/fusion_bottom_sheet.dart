import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fusion_mobile_revamped/src/components/popup_menu.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';

class FusionFeedbackSheet extends StatelessWidget {
  final Function(String, {Map<String, dynamic>? extras}) onSubmit;
  final ScrollController? scrollController;
  const FusionFeedbackSheet({
    required this.onSubmit,
    this.scrollController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    TextEditingController _controller = TextEditingController();
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        Align(
          alignment: Alignment.center,
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
                color: halfSmoke,
                borderRadius: BorderRadius.all(
                  Radius.circular(3),
                )),
            width: 36,
            height: 5,
          ),
        ),
        Container(
          padding: EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
              border: Border(
            bottom: BorderSide(color: lightDivider, width: 1.0),
          )),
          child: Text(
            "WHAT'S WRONG ?",
            textAlign: TextAlign.center,
            style: TextStyle(
                color: smoke, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 8,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
          child: TextFormField(
            controller: _controller,
            keyboardType: TextInputType.multiline,
            minLines: 3,
            maxLines: null,
            style: TextStyle(
                color: coal, fontSize: 16, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelStyle: TextStyle(
                    color: smoke, fontSize: 16, fontWeight: FontWeight.w400),
                focusedBorder: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                fillColor: particle,
                filled: true,
                hintText: "Please add a small description of what happened",
                hintStyle: TextStyle(
                    color: smoke, fontSize: 16, fontWeight: FontWeight.w400)),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: () => onSubmit(_controller.text),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: Text("Report"),
          ),
        )
      ],
    );
  }
}
