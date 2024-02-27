import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/models/phone_contact.dart';
import 'package:permission_handler/permission_handler.dart';
import 'contact.dart';
import 'coworkers.dart';
import 'crm_contact.dart';
import 'fusion_model.dart';
import 'fusion_store.dart';
import 'messages.dart';

class Voicemail extends FusionModel {
  String? id;
  String? path;
  late DateTime time;
  String? phoneNumber;
  int? duration;
  List<Contact>? contacts;
  Coworker? coworker;

  Voicemail(Map<String, dynamic> obj) {
    this.id = obj['index'];
    this.path = obj['audioSrc'];
    this.phoneNumber = obj['callerNumber'];
    this.duration = obj['duration'];
    this.time = DateTime.parse(obj['callTime']).toLocal();
    this.contacts = obj['fusionContact'] == null ? [] : [Contact.fromV2(obj['fusionContact'])];
  }

  contactName() {
    if (coworker != null)
      return coworker!.getName();

    for (Contact c in contacts!) {
      if (c.fullName() != "Unknown") {
        return c.fullName();
      }
    }
    return "Unknown";
  }

  @override
  String? getId() => this.id;
}

class VoicemailStore extends FusionStore<Voicemail> {
  String id_field = "id";

  VoicemailStore(FusionConnection fusionConnection) : super(fusionConnection);

  getVoicemails(Function(List<Voicemail>, bool) callback) async {
    final PermissionStatus status = await Permission.contacts.status;
    List<PhoneContact> phoneContacts = [];
    if(status.isGranted){
      phoneContacts = await fusionConnection.phoneContacts.getAddressBookContacts("");
    }
    fusionConnection
        .apiV2Call("get", "/user/voicemails", {"limit": 200, "start": 0},
            callback: (Map<String, dynamic> datas) {
      List<Voicemail> response = [];

      for (Map<String, dynamic> item in datas['items']) {
        Voicemail obj = Voicemail(item);

        if (obj.phoneNumber!.length <= 6) {
          obj.coworker = fusionConnection.coworkers.lookupCoworker(
          obj.phoneNumber! + '@' + fusionConnection.getDomain());
        }
        if(phoneContacts.isNotEmpty && obj.contacts!.isEmpty){
          for (PhoneContact phoneContact in phoneContacts) {
            List<String> numbers = 
              phoneContact.phoneNumbers.map((e) => e["number"]).toList().cast<String>();
            if(numbers.contains(obj.phoneNumber)){
              obj.contacts = [phoneContact.toContact()];
            }
          }
        }
        storeRecord(obj);
        response.add(obj);
      }

      callback(response, true);
    });
  }

  Future<bool> deleteVoicemail(Voicemail vm) async {
    bool deleteRes = false;
    try {
      await fusionConnection.apiV2Call("post", "/user/voicemails/delete", {
        "index" : "${vm.id}.wav",
        "owner" : fusionConnection.getUid(),
        "type"  : "vmail/new"
      }, callback: (res){
        deleteRes = res;
      });
    } catch (e) {
      print("MDBM error deleting vm ${e}");
    }
    return deleteRes;
  }
}
