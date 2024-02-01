import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';

import 'fusion_model.dart';
import 'fusion_store.dart';

class Did extends FusionModel {
  String? callRoutingUser;
  String? did;
  // bool mmsCapable;
  String? notes;
  String? groupName;
  bool? favorite;
  String? id;
  // smsRouting: null OR {groupId, type} OR {uid, type}

  Did(Map<String, dynamic> obj) {
    // this.callRoutingUser = obj['callRoutingUser'];
    this.callRoutingUser = obj['to_user'];
    this.did = obj['did'];
    // this.mmsCapable = obj['mmsCapable'];
    // this.mmsCapable = false;
    // this.notes = obj['notes'];
    this.id = obj['did'];
    this.notes = obj['plan_description'].runtimeType == String 
      ? obj['plan_description']
      : "";
    this.groupName = obj.containsKey("groupName") ? obj["groupName"] : null;
    this.favorite = obj['favorite'];
  }

  @override
  String getId() => this.id.toString();

}

class DidStore extends FusionStore<Did> {
  String id_field = "did";

  DidStore(FusionConnection fusionConnection) : super(fusionConnection);

  getDids(Function(List<Did>, bool) callback) {
    List<Did> dids = getRecords();
    if(dids.isNotEmpty){
      callback(dids,false);
    } else {
      fusionConnection.apiV2Call("get", "/client/dids", {},
          callback: (Map<String, dynamic> datas) {
        List<Did> response = [];

        for (Map<String, dynamic> item in datas['items']) {
          Did obj = Did(item);
          storeRecord(obj);
          response.add(obj);
        }

        callback(response, true);
      });
    }
  }
}
