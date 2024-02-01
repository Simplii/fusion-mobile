import 'dart:convert';

import 'package:flutter/material.dart';

class Disposition {
  String? id;
  int? order;
  String? domain;
  String? label;
  List? triggers = [];
  int? groupId;
  String? customDispositionsCrmId;
  String? createdAt;
  String? updatedAt;
  Disposition({
    this.id,
    this.label,
    this.groupId,
    this.domain,
    this.order,
    this.triggers,
    this.updatedAt,
    this.customDispositionsCrmId,
    this.createdAt,
    Key = Key
  });
  serialize(){
    return {
      "id": id,
      "label": label,
      "groupId": groupId,
      "order": order,
      "domain": domain,
      "triggers": triggers,
      "customDispositionsCrmId": customDispositionsCrmId,
      "createdAt" : createdAt,
      "updatedAt" : updatedAt,
    };
  }

  Disposition.fromJson(Map<String,dynamic> data){
    label     = data["label"];
    id        = data["id"];
    groupId   = data["group_id"];
    order     = data["order"];
    domain    = data["domain"];
    triggers  = jsonDecode(data["triggers"]);
    createdAt = data["created_at"];
    updatedAt = data["updated_at"];
    customDispositionsCrmId = data["custom_dispositions_crm_id"] ?? "";
  }
}

class DispositionCustomField {
  int? id;
  String? createdAt;
  String? updatedAt;
  String? name;
  String? label;
  int? groupId;
  String? type;
  DispositionCustomFieldOption? options;
  DispositionCustomField({
    this.id,
    this.createdAt,
    this.groupId,
    this.label,
    this.name,
    this.options,
    this.type,
    this.updatedAt,
    Key = Key
  });

  DispositionCustomField.fromJson(Map<String,dynamic> data){
    id        = data['id'];
    type      = data['type'];
    name      = data['field_name'];
    label     = data['field_label'];
    groupId   = data['field_group_id'];
    options   = DispositionCustomFieldOption.fromJson(data);
    createdAt = data['created_at'];
    updatedAt = data['updated_at'];
  }
}

class DispositionCustomFieldOption {
  List? displayFor;
  List? requireFor;
  dynamic validationWebhook;
  List<String>? dropdownChoices;
  DispositionCustomFieldOption({
    this.displayFor,
    this.requireFor,
    this.validationWebhook,
    this.dropdownChoices,
    Key = Key
  });

  DispositionCustomFieldOption.fromJson(Map<String,dynamic> data){
    List<dynamic> choices = data['options']['dropdown_choices'] ?? [];
    displayFor = data['options']['display_for'];
    requireFor = data['options']['require_for'];
    validationWebhook = data['options']['validation_webhook'];
    dropdownChoices = data['type'] == "dropdown" ? choices.cast<String>() : [];
  }
}

abstract class DispositionCustomFieldTypes {
  static const String Text = "text";
  static const String Dropdown = "dropdown";
  static const String Textarea = "textarea";
}

class CallType {
  int? id;
  String? label;
  int? groupId;
  String? createdAt;
  String? updatedAt;
  List? crmAssociations = [];
  CallType({
    this.id,
    this.groupId,
    this.label,
    this.updatedAt,
    this.createdAt,
    this.crmAssociations,
    Key = Key
  });
  toJson(){
    return {
      "id": id,
      "label": label,
      "crm_associations": crmAssociations,
      "created_at": createdAt,
      "updated_at": updatedAt,
      "dispositionGroupId": groupId
    };
  }
  CallType.fromJson(Map<String,dynamic> data){
    id        = data['id'];
    label     = data['label'];
    groupId   = data['dispositionGroupId'];
    createdAt = data['createdAt'];
    updatedAt = data['updatedAt'];
  }
}

class SetDispositionPayload {
  String? phoneNumber;
  String? dispositionId;
  String? notes;
  CallType? callType;
  Map<String,dynamic>? fieldValues;
  SetDispositionPayload({
    required this.phoneNumber,
    this.callType,
    this.dispositionId,
    required this.fieldValues,
    required this.notes
  });
  toJson(){
    Map<String,dynamic> data = {
      "phoneNumber": phoneNumber,
      "fieldValues": fieldValues,
      "notes": notes
    };
    if(callType != null) data["callType"] = callType!.toJson();
    if(dispositionId != null) data["dispositionId"] = dispositionId;
    return data;
  }
}
class DispositionGroup {
  String? id;
  String? name;
  List<Disposition> dispositions = [];
  DispositionGroup({
    this.id,
    this.name,
    Key = Key
  });

  serialize(){
    return {
      "id": id,
      "name": name,
      "dispositions": dispositions
    };
  }
}