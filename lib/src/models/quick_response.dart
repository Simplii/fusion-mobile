
import 'dart:convert' as convert;
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';

import 'fusion_model.dart';
import 'fusion_store.dart';

class QuickResponse extends FusionModel {
  String createdAt;
  String domain;
  int groupId;
  int id;
  String message;
  String uid;
  String updatedAt;

  QuickResponse(Map<String,dynamic>obj){
    this.createdAt = obj['created_at'];
    this.domain = obj['domain'];
    this.groupId = obj['group_id'];
    this.id = obj['id'];
    this.message = obj['message'];
    this.uid = obj['uid'];
    this.updatedAt = obj['updated_at'];
  }
  
  serialize() {
    return convert.jsonEncode({
      'createdAt': createdAt,
      'domain': domain,
      'groupId': groupId,
      'id': id,
      'message': message,
      'uid': uid
    });
  }

  QuickResponse.unserialize(String data){
    Map<String, dynamic> obj = convert.jsonDecode(data);
    this.createdAt = obj['created_at'];
    this.domain = obj['domain'];
    this.groupId = obj['group_id'];
    this.id = obj['id'];
    this.message = obj['message'];
    this.uid = obj['uid'];
    this.updatedAt = obj['updated_at'];
  }
}

class QuickResponsesStore extends FusionStore<QuickResponse> {
  QuickResponsesStore(FusionConnection fusionConnection) : super(fusionConnection);

  void getQuickResponses(String departmentId, Function(List<QuickResponse>) quickResponses){
    fusionConnection.apiV2Call("get", 
    "/messaging/group/$departmentId/quickMessages", 
    {}, 
    callback: (Map<String,dynamic>data){
      List<QuickResponse> quickResps = [];
      if(data.containsKey('items')){
        for (Map<String,dynamic> item in data['items']) {
          QuickResponse quickRes = QuickResponse(item);
          storeRecord(quickRes);
          quickResps.add(quickRes);
        }
      }
      quickResponses(quickResps);
    });
  }
}