import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PrinterConfig {
  const PrinterConfig({
    required this.target,
    required this.timeout,
    required this.model,
    required this.lang,
  });

  final String target;
  final int timeout;
  final String model;
  final String lang;

  static PrinterConfig? _cached;

  static Future<PrinterConfig?> load() async {
    if (_cached != null) {
      return _cached;
    }

    try {
      final jsonString =
          await rootBundle.loadString('assets/config/printer.json');
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final config = PrinterConfig(
        target: data['target'] as String,
        timeout: (data['timeout'] as num?)?.toInt() ?? 10000,
        model: data['model'] as String? ?? 'TM_M30',
        lang: data['lang'] as String? ?? 'MODEL_ANK',
      );
      _cached = config;
      return config;
    } on FlutterError catch (e) {
      debugPrint('Printer config asset missing: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Failed to load printer config: $e');
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'target': target,
      'timeout': timeout,
      'model': model,
      'lang': lang,
    };
  }
}
