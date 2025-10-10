import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/order_provider.dart';
import '../utils/receipt.dart';

class StartOrderScreen extends StatefulWidget {
  const StartOrderScreen({super.key});

  @override
  State<StartOrderScreen> createState() => _StartOrderScreenState();
}

class _StartOrderScreenState extends State<StartOrderScreen> {
  final _tableController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _tableController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Order')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _tableController,
              decoration: const InputDecoration(
                labelText: 'Table number',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Order note: (floor? number of people?)',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                String table = _tableController.text.trim();

                // Auto-generate a 3-digit table number if empty
                if (table.isEmpty) {
                  final randomNum = Random().nextInt(900) + 100; // 100–999
                  table = randomNum.toString();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Auto generated table number: $table'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }

                // Start new order
                context.read<OrderProvider>().startOrder(
                      table,
                      _noteController.text.trim(),
                    );

                // Clear now so when user returns, fields are empty
                _tableController.clear();
                _noteController.clear();
                FocusScope.of(context).unfocus();

                // Navigate, and also clear again when route pops back
                Navigator.of(context).pushNamed('/menu').then((_) {
                  if (!mounted) return;
                  _tableController.clear();
                  _noteController.clear();
                  setState(() {});
                });
              },
              child: const Text('Start Order'),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ReceiptPrinter.printTestReceipt();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Direct print test sent'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Direct print test failed: $e'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
                child: const Text('Test Direct Print (EPOS)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
