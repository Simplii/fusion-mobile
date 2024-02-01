import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'fusion_model.dart';
import 'fusion_store.dart';
import 'dart:convert' as convert;

class ContactField extends FusionModel {
  String? id;
  String? type;
  List<String> options = [];
  String? fieldLabel;
  String? fieldName;
  List<Map<String, dynamic>>? crmFields;

  ContactField(Map<String, dynamic> obj) {
    id = obj['id'].toString();
    type = obj['type'];
    if (type!.substring(0, 4).toLowerCase() == 'enum') {
      List<dynamic> optionsList = convert.jsonDecode(type!.substring(4));
      options = optionsList.cast<String>();
      type = type!.substring(0, 4);
    }
    type = type!.toLowerCase();
    fieldLabel = obj['field_label'];
    fieldName = obj['field_name'];
    crmFields = (obj['crm_fields'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  @override
  String? getId() => this.id;
}

class ContactFieldStore extends FusionStore<ContactField> {
  String id_field = "id";
  ContactFieldStore(FusionConnection fusionConnection) : super(fusionConnection);

  getFields(Function(List<ContactField>, bool) callback) {
    if (getRecords().length > 0) {
      callback(getRecords(), false);
    }
    else {
      fusionConnection.apiV1Call(
          "get",
          "/staging/fields",
          {},
          callback: (List<dynamic> datas) {
            List<ContactField> response = [];

            for (Map<String, dynamic> item in datas) {
              ContactField obj = ContactField(item);
              storeRecord(obj);
              response.add(obj);
            }

            callback(response, true);
          });
    }
  }
}