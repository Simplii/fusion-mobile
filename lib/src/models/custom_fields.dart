import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'fusion_model.dart';
import 'fusion_store.dart';

enum CustomFieldModule { contacts, companies, tasks }

class CustomFieldOptions {
  final String prefilledValue;
  CustomFieldOptions(this.prefilledValue);
}

class CustomFieldCrmRef {
  final String fieldId;
  final String crmName;
  final String module;
  CustomFieldCrmRef(this.fieldId, this.crmName, this.module);
}

class CustomField extends FusionModel {
  final String fieldName;
  final String label;
  final CustomFieldModule module;
  final String type;
  final CustomFieldOptions options;
  final List<CustomFieldCrmRef> crmReferences;
  final bool generatedByFusion;
  final bool readOnly;
  final bool visible;

  CustomField(
    this.fieldName,
    this.label,
    this.module,
    this.type,
    this.options,
    this.crmReferences,
    this.generatedByFusion,
    this.readOnly,
    this.visible,
  );
  factory CustomField.fromJson(Map<String, dynamic> data) {
    List crmReferences = data['crmReferences'] ?? [];
    print("MDBM CustomField fromJson ${data['module']}");
    return CustomField(
      data['fieldName'] ?? "",
      data['label'] ?? "",
      CustomFieldModule.values.byName(data['module']),
      data['type'] ?? "",
      CustomFieldOptions(data['options']['prefilledValue'] ?? ""),
      crmReferences
          .map(
              (e) => CustomFieldCrmRef(e['fieldId'], e['crmName'], e['module']))
          .toList(),
      data['generatedByFusion'],
      data['readOnly'],
      data['visible'],
    );
  }

  @override
  String getId() => this.fieldName;
}

class CustomFieldStore extends FusionStore<CustomField> {
  String id_field = "fieldName";
  CustomFieldStore(FusionConnection fusionConnection) : super(fusionConnection);
  // Right now we only care about contacts custom field module, but the setup is there for future
  // expansion.
  fetchFields({CustomFieldModule module = CustomFieldModule.contacts}) {
    fusionConnection.apiV2Call(
      "get",
      "/clients/customFields/${module.name}",
      {},
      callback: (Map<String, dynamic> data) {
        for (var item in data['items']) {
          CustomField customField = CustomField.fromJson(item);
          storeRecord(customField);
        }
      },
    );
  }

  List<CustomField> getCustomFields() {
    return getRecords();
  }

  List<String> customFieldsNames() {
    List<CustomField> fields = getRecords() ?? [];
    return fields.map((e) => e.fieldName).toList();
  }
}
