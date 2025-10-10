import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order_item.dart';
import '../providers/order_provider.dart';
import '../utils/receipt.dart';

class OrderReviewScreen extends StatefulWidget {
  const OrderReviewScreen({super.key});

  @override
  State<OrderReviewScreen> createState() => _OrderReviewScreenState();
}

class _OrderReviewScreenState extends State<OrderReviewScreen> {
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final items = orderProvider.items;

    // group items by category
    final groups = <String, List<OrderItem>>{};
    for (final oi in items) {
      groups.putIfAbsent(oi.item.category, () => []).add(oi);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Review Order')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: groups.entries
                    .map((entry) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.key.toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            ...entry.value.map(
                              (oi) => ListTile(
                                title: Text('${oi.quantity} x ${oi.item.name}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '£${(oi.item.pricePence * oi.quantity / 100).toStringAsFixed(2)}'),
                                    if (oi.note != null && oi.note!.isNotEmpty)
                                      Text(
                                        'Note: ${oi.note}',
                                        style:
                                            const TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        icon: const Icon(Icons.remove),
                                        onPressed: _isPrinting
                                            ? null
                                            : () {
                                                orderProvider.updateQuantity(
                                                    oi, oi.quantity - 1);
                                              }),
                                    IconButton(
                                        icon: const Icon(Icons.add),
                                        onPressed: _isPrinting
                                            ? null
                                            : () {
                                                orderProvider.updateQuantity(
                                                    oi, oi.quantity + 1);
                                              }),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ))
                    .toList(),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  '£${(orderProvider.totalPence / 100).toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isPrinting
                  ? null
                  : () async {
                      int copies = 1;
                      final controller =
                          TextEditingController(text: copies.toString());
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Print Receipts'),
                          content: TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Number of copies'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Print'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        setState(() => _isPrinting = true);
                        var printedSuccessfully = false;
                        try {
                          final numCopies =
                              int.tryParse(controller.text) ?? 1;

                          await ReceiptPrinter.printReceipt(
                            tableNo: orderProvider.tableNo ?? '',
                            items: items,
                            orderNote: orderProvider.note,
                            copies: numCopies,
                          );
                          printedSuccessfully = true;
                        } on DirectPrintException catch (e) {
                          if (!mounted) return;
                          final fallback = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Direct print failed'),
                              content: Text(e.message),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Use Android Print'),
                                ),
                              ],
                            ),
                          );

                          if (fallback == true) {
                            try {
                              await e.fallback();
                              printedSuccessfully = true;
                            } catch (fallbackError) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Fallback printing failed: $fallbackError'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Printing cancelled: ${e.message}'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Printing failed: $e'),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        }

                        if (printedSuccessfully && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  const Text('Order printed successfully!'),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.only(
                                bottom: 80,
                                left: 16,
                                right: 16,
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }

                        if (printedSuccessfully) {
                          // clear order and go home
                          orderProvider.clear();
                          if (mounted) {
                            Navigator.of(context).popUntil(
                                (route) => route.settings.name == '/');
                          }
                        }
                      } finally {
                          if (mounted) setState(() => _isPrinting = false);
                        }
                      }
                    },
              child: _isPrinting
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 8),
                        Text('Printing...'),
                      ],
                    )
                  : const Text('Print Receipts'),
            ),
          ],
        ),
      ),
    );
  }
}
