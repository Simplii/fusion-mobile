class AudioDevice {
  final AudioDeviceType deviceType;
  final String deviceName;
  final String deviceDriverName;
  final String deviceId;

  AudioDevice({
    required this.deviceType,
    required this.deviceName,
    required this.deviceDriverName,
    required this.deviceId,
  });

  factory AudioDevice.fromDictionary(Map<dynamic, dynamic> data) {
    AudioDeviceType type = data["deviceType"] == "Speaker"
        ? AudioDeviceType.Speaker
        : data["deviceType"] == "Bluetooth"
            ? AudioDeviceType.Bluetooth
            : AudioDeviceType.Earpiece;
    return AudioDevice(
      deviceDriverName: data["deviceDriverName"] ?? "",
      deviceId: data["deviceId"] ?? "",
      deviceName: data["deviceName"] ?? "",
      deviceType: type,
    );
  }
}

enum AudioDeviceType { Speaker, Earpiece, Bluetooth }
