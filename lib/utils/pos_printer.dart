import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const bool kUseEpsonDirectPrint =
    String.fromEnvironment('USE_EPSON_DIRECT', defaultValue: 'false') == 'true';

class PosPrinter {
  static const _channel = MethodChannel('leson.pos/printer');

  static Future<Map<String, dynamic>> printReceipt(
      Map<String, dynamic> payload) async {
    if (kUseEpsonDirectPrint) {
      try {
        final result = await _channel.invokeMethod('printDirect', payload);
        if (result is Map) {
          return result.cast<String, dynamic>();
        }
        return {'ok': false, 'error': 'Unexpected response'};
      } on PlatformException catch (e) {
        return {'ok': false, 'error': e.message};
      }
    } else {
      final copies = (payload['copies'] as int?) ?? 1;
      for (var i = 0; i < copies; i++) {
        await Printing.layoutPdf(
            onLayout: (format) async => await _buildPdfDoc(payload));
      }
      return {'ok': true, 'copiesPrinted': copies};
    }
  }

  static Future<Uint8List> buildPdfDoc(Map<String, dynamic> payload) async {
    return _buildPdfDoc(payload);
  }

  static Future<Uint8List> _buildPdfDoc(Map<String, dynamic> payload) async {
    final doc = pw.Document();

    final store = (payload['store'] as Map?)?.cast<String, dynamic>() ?? {};
    final receipt =
        (payload['receipt'] as Map?)?.cast<String, dynamic>() ?? {};

    final createdAtStr = receipt['createdAt'] as String?;
    DateTime? createdAt;
    if (createdAtStr != null) {
      createdAt = DateTime.tryParse(createdAtStr)?.toLocal();
    }
    createdAt ??= DateTime.now();

    final dateStr =
        '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} '
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    final items =
        (receipt['items'] as List?)?.cast<Map>() ?? const <Map<dynamic, dynamic>>[];
    final tableNo = receipt['table']?.toString() ?? '';
    final orderNote = receipt['note']?.toString();

    final currency = receipt['currency']?.toString() ?? 'GBP';
    final currencySymbol = currency == 'GBP' ? '£' : currency;

    final totalPence = (receipt['totalPence'] as num?)?.toInt() ??
        items.fold<int>(0, (sum, item) {
          final unit = (item['unitPricePence'] as num?)?.toInt() ?? 0;
          final qty = (item['qty'] as num?)?.toInt() ?? 0;
          return sum + unit * qty;
        });

    pw.Widget _itemLine(Map<dynamic, dynamic> item) {
      final qty = (item['qty'] as num?)?.toInt() ?? 0;
      final name = item['name']?.toString() ?? '';
      final note = item['note']?.toString();
      final unitPricePence = (item['unitPricePence'] as num?)?.toInt() ??
          ((item['unitPrice'] as num?) != null
              ? ((item['unitPrice'] as num) * 100).round()
              : 0);
      final totalPrice = unitPricePence * qty / 100;
      final priceText = '$currencySymbol${totalPrice.toStringAsFixed(2)}';

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  '$qty x $name',
                  style: const pw.TextStyle(fontSize: 28),
                  softWrap: true,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                flex: 1,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    priceText,
                    style: const pw.TextStyle(fontSize: 28),
                  ),
                ),
              ),
            ],
          ),
          if (note != null && note.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                '- $note',
                style: const pw.TextStyle(fontSize: 26),
                softWrap: true,
              ),
            ),
        ],
      );
    }

    final grouped = <String, List<Map<dynamic, dynamic>>>{};
    for (final item in items) {
      final map = item.cast<dynamic, dynamic>();
      final cat = map['category']?.toString() ?? 'OTHERS';
      grouped.putIfAbsent(cat, () => []).add(map);
    }

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        build: (context) {
          return [
            if (store.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (store['name'] != null)
                    pw.Text(
                      store['name'].toString(),
                      style: pw.TextStyle(
                        fontSize: 34,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  if (store['address'] != null)
                    pw.Text(store['address'].toString(),
                        style: const pw.TextStyle(fontSize: 24)),
                  if (store['phone'] != null)
                    pw.Text('Tel: ${store['phone']}',
                        style: const pw.TextStyle(fontSize: 24)),
                  pw.SizedBox(height: 12),
                ],
              ),
            pw.Text(
              '** Receipt **',
              style: pw.TextStyle(
                fontSize: 32,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 26)),
            pw.Text('Table: $tableNo', style: const pw.TextStyle(fontSize: 28)),
            if (orderNote != null && orderNote.isNotEmpty)
              pw.Text('Note: $orderNote',
                  style: const pw.TextStyle(fontSize: 28)),
            pw.SizedBox(height: 8),
            ...grouped.entries.map(
              (entry) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    entry.key.toUpperCase(),
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  ...entry.value.map(
                    (item) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 6),
                      child: _itemLine(item),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                ],
              ),
            ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 30,
                  ),
                ),
                pw.Text(
                  '$currencySymbol${(totalPence / 100).toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 30,
                  ),
                ),
              ],
            ),
            if (receipt['footerLines'] is List)
              pw.Column(
                children: [
                  pw.SizedBox(height: 12),
                  ...List.castFrom<dynamic, dynamic>(
                          receipt['footerLines'] as List)
                      .map(
                    (line) => pw.Text(
                      line.toString(),
                      style: const pw.TextStyle(fontSize: 24),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              ),
          ];
        },
      ),
    );

    return doc.save();
  }
}
