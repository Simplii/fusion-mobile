import 'dart:io';
import 'package:sip_ua/sip_ua.dart';

class FusionSIPUAHelper extends SIPUAHelper {
  bool _settingVideo = false;

  setVideo(bool settingVideo) {
    _settingVideo = settingVideo;
  }


  @override
  Map<String, Object?> buildCallOptions([bool voiceonly = false]) {
    var options = super.buildCallOptions(voiceonly);
    // if this isn't set for a hold request, reinvites will not be sent out for holds on outbound calls
    // if it is seton makecall, the app crashes
    //if (_settingVideo == true) {
    if (Platform.isIOS) {
      ((options['rtcOfferConstraints'] as Map<String, Object>)['mandatory']
      as Map<String, dynamic>)['OfferToReceiveVideo'] = false;
    }
    //}
    return options;
  }
}