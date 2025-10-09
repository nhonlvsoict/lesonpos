import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/order_item.dart';

class ReceiptPrinter {
  static Future<void> printReceipt({
    required String tableNo,
    required List<OrderItem> items,
    String? orderNote,
    int copies = 1,
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();

    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} ${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    pw.Widget _itemLine(OrderItem oi) {
      final priceText =
          '£${(oi.item.pricePence * oi.quantity / 100).toStringAsFixed(2)}';

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  '${oi.quantity} x ${oi.item.name}',
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
          if (oi.note != null && oi.note!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                '- ${oi.note}',
                style: const pw.TextStyle(fontSize: 26),
                softWrap: true,
              ),
            ),
        ],
      );
    }

    pw.Widget _section({
      required String header,
      required List<OrderItem> items,
      String? orderNote,
      required int totalPence,
    }) {
      final groups = <String, List<OrderItem>>{};
      for (final oi in items) {
        final cat = oi.item.category;
        groups.putIfAbsent(cat, () => []).add(oi);
      }

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '** $header **',
            style:
                pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 26)),
          pw.Text('Table: $tableNo', style: const pw.TextStyle(fontSize: 28)),
          if (orderNote != null && orderNote.isNotEmpty)
            pw.Text('Note: $orderNote', style: const pw.TextStyle(fontSize: 28)),
          pw.SizedBox(height: 8),
          ...groups.entries.map((entry) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(entry.key.toUpperCase(),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 28)),
                  pw.SizedBox(height: 4),
                  ...entry.value.map((oi) =>
                      pw.Padding(padding: const pw.EdgeInsets.only(bottom: 6), child: _itemLine(oi))),
                  pw.SizedBox(height: 4),
                ],
              )),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TOTAL',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 30)),
              pw.Text('£${(totalPence / 100).toStringAsFixed(2)}',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 30)),
            ],
          ),
        ],
      );
    }

    final total =
        items.fold<int>(0, (sum, oi) => sum + oi.item.pricePence * oi.quantity);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        build: (context) => [
          _section(
            header: 'Receipt',
            items: items,
            orderNote: orderNote,
            totalPence: total,
          ),
        ],
      ),
    );

    for (var i = 0; i < copies; i++) {
      await Printing.layoutPdf(onLayout: (format) async => doc.save());
    }
  }
}
