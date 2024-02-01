import 'dart:convert' as convert;

class CarbonDate {
  String? date;
  String? timezone;
  int? timezone_type;

  serialize() {
    return convert.jsonEncode({
      'date': date,
      'timezone': timezone,
      'timezone_type': timezone_type
    });
  }

  CarbonDate.fromDate(String? date) {
    this.date = date;
    this.timezone = 'UTC';
    this.timezone_type = 1;
  }

  CarbonDate.unserialize(String data) {
    Map<String, dynamic> obj = convert.jsonDecode(data);
    this.date = obj['date'];
    this.timezone = obj['timezone'];
    this.timezone_type = obj['timezone_type'];
  }

  CarbonDate(Map<String, dynamic> obj) {
    try {
      this.date = obj['date'];
      this.timezone = obj['timezone'];
      this.timezone_type = obj['timezone_type'];
    } catch (e) {}
  }
}
