import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/order_item.dart';
import 'pos_printer.dart';

class ReceiptPrintResult {
  ReceiptPrintResult({
    required this.payload,
    required this.response,
  });

  final Map<String, dynamic> payload;
  final Map<String, dynamic> response;

  bool get ok => response['ok'] == true;
  String? get error => response['error'] as String?;
}

class ReceiptPrinter {
  static Map<String, dynamic>? _profileCache;

  static Future<Map<String, dynamic>> _loadProfile() async {
    if (_profileCache != null) {
      return _profileCache!;
    }
    try {
      final raw = await rootBundle.loadString('assets/config/printer.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _profileCache = decoded;
      } else {
        _profileCache = {};
      }
    } catch (_) {
      _profileCache = {};
    }
    return _profileCache!;
  }

  static Future<Map<String, dynamic>> buildReceiptPayload({
    required String tableNo,
    required List<OrderItem> items,
    String? orderNote,
    int copies = 1,
  }) async {
    final profile = await _loadProfile();
    final sanitizedCopies = copies <= 0 ? 1 : copies;

    final configDefaults = <String, dynamic>{
      'target': 'TCP:192.168.0.100',
      'timeout': 10000,
      'model': 'TM_M30',
      'lang': 'MODEL_ANK',
    };
    final configOverride =
        (profile['config'] as Map?)?.cast<String, dynamic>() ?? {};
    final config = {...configDefaults, ...configOverride};

    final storeDefaults = <String, dynamic>{
      'name': 'LeSon Restaurant',
      'address': '95 Kirkgate, Leeds LS2 7DJ',
      'phone': '+44 1234 567890',
    };
    final storeOverride =
        (profile['store'] as Map?)?.cast<String, dynamic>() ?? {};
    final store = {...storeDefaults, ...storeOverride};

    final printOptionsDefaults = <String, dynamic>{
      'cutType': 'CUT_FEED',
      'openDrawer': false,
      'printQr': null,
      'printBarcode': null,
    };
    final printOptionsOverride =
        (profile['printOptions'] as Map?)?.cast<String, dynamic>() ?? {};
    final printOptions = {...printOptionsDefaults, ...printOptionsOverride};

    final now = DateTime.now();
    final orderId = 'ORD-${now.millisecondsSinceEpoch}';
    final totalPence =
        items.fold<int>(0, (sum, oi) => sum + oi.item.pricePence * oi.quantity);

    final groupedItems = items
        .map((oi) => {
              'category': oi.item.category,
              'name': oi.item.name,
              'qty': oi.quantity,
              'unitPrice': oi.item.pricePence / 100,
              'unitPricePence': oi.item.pricePence,
              if (oi.note != null && oi.note!.isNotEmpty) 'note': oi.note,
            })
        .toList();

    final qrConfig = printOptions['printQr'];
    if (qrConfig is Map<String, dynamic> &&
        (qrConfig['data'] == null ||
            (qrConfig['data'] as String?)?.isEmpty == true)) {
      qrConfig['data'] = 'https://leson.rest/ord/$orderId';
    }

    final payload = <String, dynamic>{
      'config': config,
      'copies': sanitizedCopies,
      'store': store,
      'receipt': {
        'orderId': orderId,
        'table': tableNo,
        'note': orderNote,
        'server': profile['server'] ?? 'Waiter',
        'createdAt': now.toUtc().toIso8601String(),
        'currency': 'GBP',
        'items': groupedItems,
        'subTotal': totalPence / 100,
        'subTotalPence': totalPence,
        'discount': 0,
        'serviceCharge': 0,
        'tax': 0,
        'total': totalPence / 100,
        'totalPence': totalPence,
        'footerLines': profile['footerLines'] ??
            <String>['Thank you!', 'Follow us @leson'],
      },
      'printOptions': printOptions,
    };

    final barcodeConfig = printOptions['printBarcode'];
    if (barcodeConfig is Map<String, dynamic> &&
        (barcodeConfig['data'] == null ||
            (barcodeConfig['data'] as String?)?.isEmpty == true)) {
      barcodeConfig['data'] = orderId;
    }

    return payload;
  }

  static Future<ReceiptPrintResult> printReceipt({
    required String tableNo,
    required List<OrderItem> items,
    String? orderNote,
    int copies = 1,
  }) async {
    final payload = await buildReceiptPayload(
      tableNo: tableNo,
      items: items,
      orderNote: orderNote,
      copies: copies,
    );
    final response = await PosPrinter.printReceipt(payload);
    return ReceiptPrintResult(payload: payload, response: response);
  }
}
