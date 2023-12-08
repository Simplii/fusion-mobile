import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

uuidFromString(String str) {
  if (str.length == 0)
    return Uuid().v4();

  else {
    List<int> numbers = [];
    int strIndex = 0;

    for (var i = 0; i < 16; i++) {
      if (strIndex > str.length)
        strIndex = 0;

      numbers.add(str.codeUnitAt(strIndex));
      strIndex += 1;
    }

    return Uuid().v4(options: {'random': numbers});
  }
}

intIdForString(String? str) {
  if (str == null)
    return 0;

  else {
    int id = 1;
    for (var i = 0; i < str.length; i++) {
      id += i * 256 + str.codeUnitAt(i);
    }
    return id;
  }
}

extension durations on int {
  String printDuration() {
    String duration = "";

    int seconds = this % 60;
    int minutes = (this / 60).floor();
    int hours = (this / (60 * 60)).floor();

    if (hours > 0) {
      return hours.toString() + ":"
          + (minutes < 10 ? "0" : "") + minutes.toString() + ":"
          + (seconds < 10 ? "0" : "") + seconds.toString();
    } else {
        return (minutes < 10 ? "0" : "") + minutes.toString() + ":"
          + (seconds < 10 ? "0" : "") + seconds.toString();
    }
  }
}

extension PhoneNumbers on String {
  String formatPhone() {
    if(this == null)return '';
    if (this.contains("@"))
      return this;
    else if (this.length < 10)
      return this;
    else
      return this.replaceAllMapped(RegExp(r'([02-9]\d{2})(\d{3})(\d{4})'), (match) {
        return '(${match.group(1)}) ${match.group(2)}-${match.group(3)}';
      });
  }

  String onlyNumbers() {
    return this.replaceAll(RegExp(r'[^0-9]+'), '');
  }
}

randomString(int len) {
  var random = Random.secure();
  var values = List<int>.generate(len, (i) => random.nextInt(255));
  return base64UrlEncode(values);
}

List<int> largeSizes = [
  1792, // 11, XR
  2436, // 11 pro, XS, X
  2532, // 13, 13 pro, 12, 12 pro
  2688, // 11 pro max, XS max
  2778, // 12, 13 pro max
];

bool iphoneIsLarge() {
  if (Platform.isIOS) {
    int phoneHeight = ui.window.physicalSize.height.toInt();
    return largeSizes.contains(phoneHeight);
  } else {
    return false;
  }
}

Map<String, dynamic>? checkDateObj(dynamic dateToCheck) {
  if (dateToCheck.runtimeType == String) {
    final date = DateTime.parse(dateToCheck).toLocal();
    return {"date": date, "timezone": "MST", "timezone_type": 3};
  } else {
    return dateToCheck;
  }
}

String avatarUrl(String? firstName, String? lastName) {
    return "https://fusioncom.co/api/v2/client/" +
        "nameAvatar/${firstName}/${lastName}";
}

extension Capitalize on String {
  String capitalize() => this.length > 0 
    ? "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}" 
    : this;
  String toTitleCase() => replaceAll(RegExp(' +'), ' ').split(' ').map((str) => str.capitalize()).join(' ');
}

class Debounce {
  Duration delay;
  Timer? _timer;

  Debounce(
    this.delay,
  );

  call(void Function() callback) {
    _timer?.cancel();
    _timer = Timer(delay, callback);
  }

  dispose() {
    _timer?.cancel();
  }
}

  Future<XFile> urlToXFile(Uri imageUrl) async {
    var rng = new Random();
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;
    File file  = new File('$tempPath'+ (rng.nextInt(100)).toString() +'.png');
    http.Response response = await http.get(imageUrl);
    await file.writeAsBytes(response.bodyBytes);
    XFile xfile = new XFile(file.path);
    return xfile;
  }

String generateMd5(String input) {
    return md5.convert(utf8.encode(input)).toString();
}

String fusionDataHelper = "299ea792cc17100390c7a4a1b6e6f909f0a1b7c725ad820bd54292ca111cfa30";

class InputPhoneFormatter extends TextInputFormatter {
  String inputPhoneFormat(String value) {
    String phoneFormatted = value.length >= 1
    ? (value.length >= 1 ? '(' : '') + value.substring(0, value.length >= 3 ? 3 : null) 
      + (value.length  > 3 ? ') ' : '') + (value.length > 3
        ? value.substring(3, value.length >= 6 ? 6 : null) + (value.length > 6
          ? '-' + value.substring(6, value.length >= 10 ? 10 : null)
          : '')
        : '')
    : value;
    return phoneFormatted;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue, TextEditingValue newValue) {
      String text = newValue.text;

      if (newValue.selection.baseOffset == 0) {
        return newValue;
      }

      return newValue.copyWith(
        text: inputPhoneFormat(text),
        selection: new TextSelection.collapsed(offset: inputPhoneFormat(text).length)
      );
  }
}

String getDateTime (DateTime dateTime) {
  DateTime now = DateTime.now().toLocal();
  DateTime localDateTime = dateTime.toLocal();

  if (localDateTime.difference(now).inDays == 0) {
    int differenceInHours = localDateTime.difference(now).inHours.abs();
    int differenceInMins = localDateTime.difference(now).inMinutes.abs();

    if (differenceInHours > 0) {
      return '$differenceInHours hours ago';
    } else { 
      return '$differenceInMins mins ago';
    }
  }

  String timeString = DateFormat('jm').format(dateTime);

  if (localDateTime.day == now.day &&
      localDateTime.month == now.month &&
      localDateTime.year == now.year) {
    return timeString;
  }

  DateTime yesterday = now.subtract(const Duration(days: 1));

  if (localDateTime.day == yesterday.day &&
      localDateTime.month == now.month &&
      localDateTime.year == now.year) {
    return 'Yesterday';
  }

  if (now.difference(localDateTime).inDays < 4) {
    String weekday = DateFormat(
      'EEE',
    ).format(localDateTime);

    return '$weekday, $timeString';
  }

  String month = DateFormat('MMM d').format(localDateTime);
  return "$month, $timeString";
}

Uint8List? getImageBinary(dynamicList) {
  if(dynamicList != null && dynamicList.runtimeType != String){
    List<dynamic>dy = dynamicList as List<dynamic>;
    List<int> intList = dy.cast<int>().toList();
    Uint8List data = Uint8List.fromList(intList);
    return data;
  }
  return null;
}
