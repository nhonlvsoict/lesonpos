import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/order_item.dart';

class ReceiptPrinter {
  static Future<void> printReceipt({
    required String tableNo,
    required List<OrderItem> items,
    String? orderNote,
    int copies = 2,
  }) async {
    final doc = pw.Document();

    pw.Widget buildItemLine(OrderItem oi) {
      final linePrice =
          '£${(oi.item.pricePence * oi.quantity / 100).toStringAsFixed(2)}';

      // Two-line layout:
      // 1) "qty x name" wraps naturally within page width
      // 2) price on its own line, right-aligned
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${oi.quantity} x ${oi.item.name}',
            style: pw.TextStyle(fontSize: 30),
            softWrap: true,
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              linePrice,
              style: pw.TextStyle(fontSize: 30),
            ),
          ),
          if (oi.note != null && oi.note!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                '- ${oi.note}',
                style: pw.TextStyle(fontSize: 28),
                softWrap: true,
              ),
            ),
        ],
      );
    }

    pw.Widget buildSection(String header) {
      // group by category
      final groups = <String, List<OrderItem>>{};
      for (final oi in items) {
        final cat = oi.item.category;
        groups.putIfAbsent(cat, () => []).add(oi);
      }
      final total = items.fold<int>(
        0,
        (sum, oi) => sum + oi.item.pricePence * oi.quantity,
      );

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '** $header **',
            style: pw.TextStyle(fontSize: 36, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Table: $tableNo', style: pw.TextStyle(fontSize: 30)),
          if (orderNote != null && orderNote.isNotEmpty)
            pw.Text('Note: $orderNote', style: pw.TextStyle(fontSize: 30)),
          pw.SizedBox(height: 8),

          // categories
          ...groups.entries.map(
            (entry) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  entry.key.toUpperCase(),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 30),
                ),
                pw.SizedBox(height: 4),
                ...entry.value.map(
                  (oi) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: buildItemLine(oi),
                  ),
                ),
              ],
            ),
          ),

          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TOTAL',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 30),
              ),
              pw.Text(
                '£${(total / 100).toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 30),
              ),
            ],
          ),
        ],
      );
    }

    doc.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildSection('Receipt'),
            // pw.SizedBox(height: 12),
            // buildSection('Bar'),
            // pw.SizedBox(height: 12),
            // buildSection('Kitchen'),
          ],
        ),
      ),
    );

    for (var i = 0; i < copies; i++) {
      await Printing.layoutPdf(onLayout: (format) async => doc.save());
    }
  }
}
