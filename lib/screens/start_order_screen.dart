import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/order_provider.dart';

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
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Order note (optional)',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final table = _tableController.text.trim();
                if (table.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter a table number')));
                  return;
                }
                context.read<OrderProvider>().startOrder(
                      table,
                      _noteController.text.trim(),
                    );
                Navigator.of(context).pushNamed('/menu');
              },
              child: const Text('Start Order'),
            ),
          ],
        ),
      ),
    );
  }
}
