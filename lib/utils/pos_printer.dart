import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const bool kUseEpsonDirectPrint =
    String.fromEnvironment('USE_EPSON_DIRECT', defaultValue: 'false') == 'true';

class PosPrinter {
  static const _channel = MethodChannel('leson.pos/printer');
  static const double _pointsPerMillimetre = 72.0 / 25.4;
  static bool? _epsonPluginAvailability;

  static Future<Map<String, dynamic>> printReceipt(
      Map<String, dynamic> payload) async {
    if (await _shouldUseDirectPrinting()) {
      try {
        final result = await _channel.invokeMethod('printDirect', payload);
        if (result is Map) {
          return result.cast<String, dynamic>();
        }
        return {'ok': false, 'error': 'Unexpected response'};
      } on MissingPluginException catch (e) {
        debugPrint('Epson direct plugin unexpectedly unavailable: $e');
        _epsonPluginAvailability = false;
      } on PlatformException catch (e) {
        return {'ok': false, 'error': e.message};
      }
    }

    return _printWithPdfFallback(payload);
  }

  static Future<Uint8List> buildPdfDoc(Map<String, dynamic> payload) async {
    return _buildPdfDoc(payload);
  }

  static Future<bool> _shouldUseDirectPrinting() async {
    if (!kUseEpsonDirectPrint) {
      return false;
    }
    if (kIsWeb) {
      debugPrint('Epson direct printing not supported on web; using PDF.');
      return false;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      debugPrint(
          'Epson direct printing only supported on Android; using PDF path.');
      return false;
    }

    final cached = _epsonPluginAvailability;
    if (cached != null) {
      if (!cached) {
        debugPrint(
            'Epson direct plugin is not registered; using PDF printing path.');
      }
      return cached;
    }

    final available = await _queryEpsonDirectPluginPresence();
    _epsonPluginAvailability = available;
    if (!available) {
      debugPrint(
          'Epson direct plugin is not registered; using PDF printing path.');
    }
    return available;
  }

  static Future<bool> _queryEpsonDirectPluginPresence() async {
    try {
      final response = await _channel.invokeMethod<dynamic>('isAvailable');
      if (response is bool) {
        return response;
      }
      if (response is Map) {
        final available = response['available'];
        if (available is bool) {
          return available;
        }
      }
    } on MissingPluginException catch (e) {
      debugPrint('Epson direct plugin missing: $e');
      return false;
    } on PlatformException catch (e) {
      debugPrint('Failed to query Epson plugin availability: ${e.message}');
      return false;
    } catch (error) {
      debugPrint('Unexpected Epson plugin availability error: $error');
      return false;
    }

    return false;
  }

  static Future<Map<String, dynamic>> _printWithPdfFallback(
      Map<String, dynamic> payload) async {
    final copies = (payload['copies'] as int?) ?? 1;
    for (var i = 0; i < copies; i++) {
      await Printing.layoutPdf(
          onLayout: (format) async => await _buildPdfDoc(payload));
    }
    return {'ok': true, 'copiesPrinted': copies};
  }

  static Future<Uint8List> _buildPdfDoc(Map<String, dynamic> payload) async {
    final doc = pw.Document();

    final config = (payload['config'] as Map?)?.cast<String, dynamic>() ?? {};
    final paperSize = _parsePaperSize(config['paperSize']);
    final pageFormat = _pageFormatForPaperSize(paperSize);

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
          pageFormat: pageFormat,
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

  static PdfPageFormat _pageFormatForPaperSize(_PaperSize size) {
    final widthMm = size == _PaperSize.mm58 ? 58.0 : 80.0;
    final width = widthMm * _pointsPerMillimetre;
    return PdfPageFormat(width, double.infinity);
  }

  static _PaperSize _parsePaperSize(dynamic raw) {
    if (raw == null) {
      return _PaperSize.mm80;
    }
    final text = raw.toString().trim();
    if (text.isEmpty) {
      return _PaperSize.mm80;
    }
    final upper = text.toUpperCase();
    final digits = RegExp(r'\d+').allMatches(upper).map((match) => match.group(0)!).join();

    if (digits == '57' || digits == '58') {
      return _PaperSize.mm58;
    }
    if (digits == '79' || digits == '80') {
      return _PaperSize.mm80;
    }
    if (upper.contains('2IN')) {
      return _PaperSize.mm58;
    }
    if (upper.contains('3IN')) {
      return _PaperSize.mm80;
    }
    if (upper.contains('58') || upper.contains('57')) {
      return _PaperSize.mm58;
    }
    if (upper.contains('80') || upper.contains('79')) {
      return _PaperSize.mm80;
    }

    debugPrint('Unknown printer paper size "$text", defaulting to 80mm');
    return _PaperSize.mm80;
  }
}

enum _PaperSize {
  mm58,
  mm80,
}
