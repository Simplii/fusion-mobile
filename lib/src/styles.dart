import 'dart:math';

import 'package:flutter/material.dart';

Color fusionRed = Color.fromARGB(255, 255, 51, 74);
Color crimsonLight = fusionRed;
Color crimsonDark = Color.fromARGB(255, 229, 3, 42);
Color crimsonDarker = Color.fromARGB(255, 217, 3, 40);
Color darkGrey = Color.fromARGB(255, 51, 45, 46);
Color coal = Color.fromARGB(255, 51, 45, 45);
Color bgBlend = Color.fromARGB((255 * 0.75).round(), 51, 45, 45);
Color translucentSmoke = Color.fromARGB(38, 153, 148, 149);
Color char = Color.fromARGB(255, 102, 94, 96);
Color smoke = Color.fromARGB(255, 153, 148, 149);
Color halfSmoke = Color.fromARGB(128, 153, 148, 149);
Color particle = Color.fromARGB(255, 243, 242, 242);
Color lightHighlight = Color.fromARGB(26, 255, 255, 255);
Color lightDivider = Color.fromARGB(255, 102, 94, 96);
Color offWhite = Color.fromARGB(255, 229, 227, 228);
Color offBlack = Color.fromARGB(255, 27, 24, 24);
Color ash = Color.fromARGB(255, 229, 227, 227);
Color halfGray = Color.fromARGB(255, 112, 112, 122);
Color informationBlue = Color.fromARGB(255, 0, 170, 255);
Color successGreen = Color.fromARGB(255, 0, 204, 136);
Color fusionChatsBg = Color.fromARGB((255 * 0.05).round(), 217, 3, 40);
Color personalChatBg = Color.fromARGB((255 * 0.10).round(), 255, 128, 0);
Color telegramChatBg = Color.fromARGB((255 * 0.10).round(), 42, 169, 235);
Color whatsappChatBg = Color.fromARGB((255 * 0.20).round(), 101, 207, 114);
Color facebookChatBg = Color.fromARGB((255 * 0.10).round(), 177, 75, 211);
Color fusionChats = Color(0xffD90328);
Color personalChat = Color(0xffCC6600);
Color telegramChat = Color(0xff1B6D97);
Color whatsappChat = Color(0xff356E3D);
Color facebookChat = Color(0xff992EBD);
Color translucentBlack(double amount) {
  return Color.fromARGB((255 * amount).round(), 0, 0, 0);
}

Color translucentWhite(double amount) {
  return Color.fromARGB((255 * amount).round(), 255, 255, 255);
}

List<BoxShadow> tripleShadow() {
  return [
    BoxShadow(
        color: translucentBlack(0.08),
        blurRadius: 5.79,
        spreadRadius: 0.0,
        offset: Offset.fromDirection(90, 3.39)),
    BoxShadow(
        color: translucentBlack(0.012),
        blurRadius: 19.43,
        spreadRadius: 0.0,
        offset: Offset.fromDirection(90, 11.39)),
    BoxShadow(
        color: translucentBlack(0.2),
        blurRadius: 87.0,
        spreadRadius: 0.0,
        offset: Offset.fromDirection(90, 51)),
  ];
}

TextStyle headerTextStyle = TextStyle(
    color: coal, fontSize: 16, fontWeight: FontWeight.w700, height: 1.4);

String mDash = "\u2014";
String nDash = "\u2013";

TextStyle subHeaderTextStyle = TextStyle(
    color: coal, fontSize: 12, height: 1.4, fontWeight: FontWeight.w400);

TextStyle smallTextStyle = subHeaderTextStyle;

TextStyle dropdownTextStyle =
    TextStyle(color: coal, fontSize: 14, fontWeight: FontWeight.w700);

BoxDecoration dropdownDecoration = BoxDecoration(
    color: translucentSmoke,
    borderRadius: BorderRadius.all(Radius.circular(4)));

horizontalLine(double margin, {Color? color}) {
  return Expanded(
      child: Container(
          margin: EdgeInsets.only(top: margin, bottom: margin),
          decoration: BoxDecoration(
            color: color == null ? halfSmoke : color,
          ),
          height: 1));
}

popupHandle() {
  return Container(
      decoration: BoxDecoration(
          color: halfSmoke, borderRadius: BorderRadius.all(Radius.circular(3))),
      width: 36,
      height: 5);
}

bottomRedBar(bool clear) {
  return Container(
      height: 4,
      decoration: BoxDecoration(
          color: !clear ? crimsonLight : Colors.transparent,
          borderRadius: BorderRadius.only(
              topRight: Radius.circular(2), topLeft: Radius.circular(2))));
}

actionButton(
    String label, String icon, double width, double height, Function onTap,
    {double? opacity, bool isLoading = false, int flex = 1}) {
  return Expanded(
      flex: flex,
      child: GestureDetector(
          onTap: onTap as void Function()?,
          child: Opacity(
              opacity: opacity != null ? opacity : 0.66,
              child: Container(
                  decoration: BoxDecoration(color: Colors.transparent),
                  margin: EdgeInsets.only(left: 12),
                  child: Row(children: [
                    Container(
                        width: width,
                        height: height,
                        child: isLoading != null && isLoading
                            ? CircularProgressIndicator()
                            : Image.asset("assets/icons/" + icon + ".png",
                                width: width, height: height)),
                    Text(" " + label,
                        style: TextStyle(
                            color: coal,
                            fontSize: 14,
                            fontWeight: FontWeight.w800))
                  ])))));
}

whiteForegroundBox() {
  return BoxDecoration(
      boxShadow: [thinShadowBorder()],
      borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8)),
      color: Colors.white);
}

thinShadowBorder() {
  return BoxShadow(
      color: translucentBlack(0.05), spreadRadius: 0.5, blurRadius: 0.5);
}

// for gesture detectors, containers need a decoration to be
// in the tappable area
clearBg() {
  return BoxDecoration(color: Colors.transparent);
}

lighten(Color color, int amount) {
  return color
      .withRed(max(0, min(color.red + amount, 255)))
      .withGreen(max(0, min(255, color.green + amount)))
      .withBlue(max(0, min(255, color.blue + amount)));
}

darken(Color color, int amount) {
  return lighten(color, 0 - amount);
}

raisedButtonBorder(Color color, {int? lightenAmount, int? darkenAmount}) {
  return BoxDecoration(
      boxShadow: [
        BoxShadow(
            color: translucentBlack(0.06),
            offset: Offset(0, 1),
            blurRadius: 1.93),
        BoxShadow(
            color: translucentBlack(0.1),
            offset: Offset(0, 3.5),
            blurRadius: 6.48)
      ],
      borderRadius: BorderRadius.all(Radius.circular(50)),
      color: color,
      gradient: LinearGradient(
        colors: [
          lighten(color, lightenAmount == null ? 80 : lightenAmount),
          darken(color, darkenAmount == null ? 30 : darkenAmount)
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ));
}
