import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoHelper {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        var androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id; // unique ID on Android 8.0+
      } else if (Platform.isIOS) {
        var iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown_ios_id';
      }
      return 'unknown_device';
    } catch (e) {
      return 'error_getting_id';
    }
  }
}
