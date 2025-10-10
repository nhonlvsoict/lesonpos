import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const bool kDirectEpos =
    String.fromEnvironment('DIRECT_EPOS', defaultValue: 'false') == 'true';

bool get _isAndroidPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Returns true when the direct Epson ePOS path is enabled and supported on
/// this platform.
bool get shouldUseDirectEpos => kDirectEpos && _isAndroidPlatform;

class PosPrinter {
  static const MethodChannel _channel = MethodChannel('leson.pos/printer');

  static Future<Map<String, dynamic>> printReceipt(
      Map<String, dynamic> payload) async {
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('printDirect', payload);
      if (result == null) {
        return {'ok': false, 'error': 'No response from printer channel'};
      }
      return Map<String, dynamic>.from(result);
    } on MissingPluginException {
      return {
        'ok': false,
        'error': 'Direct printing not supported on this platform',
      };
    } on PlatformException catch (e) {
      return {
        'ok': false,
        'error': e.message ?? e.code,
      };
    } catch (e) {
      return {
        'ok': false,
        'error': e.toString(),
      };
    }
  }
}
