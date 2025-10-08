import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/menu_provider.dart';
import '../providers/order_provider.dart';
import '../models/menu_item.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String? _selectedCategory;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Load the menu when the screen appears
    Future.microtask(() =>
        context.read<MenuProvider>().load());
  }

@override
Widget build(BuildContext context) {
  final menuProvider = context.watch<MenuProvider>();
  final orderProvider = context.watch<OrderProvider>(); // 👈 watch instead of read
  final items = menuProvider.items.where((item) {
    final matchesCategory = _selectedCategory == null ||
        item.category == _selectedCategory;
    final matchesQuery = _query.isEmpty ||
        item.name.toLowerCase().contains(_query.toLowerCase());
    return matchesCategory && matchesQuery;
  }).toList();
  final categories =
      menuProvider.items.map((e) => e.category).toSet().toList();

  return Scaffold(
    appBar: AppBar(
      title: const Text('Menu'),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            Navigator.of(context).pushNamed('/menu-crud');
          },
        )
      ],
    ),
    body: SafeArea( // 👈 prevent overlap with system UI
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  hint: const Text('Category'),
                  value: _selectedCategory,
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('All')),
                    ...categories.map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        ))
                  ],
                  onChanged: (val) => setState(() => _selectedCategory = val),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text(item.name),
                    subtitle: Text(
                        '${item.category} • £${(item.pricePence / 100).toStringAsFixed(2)}'),
                    onTap: () async {
                      String? customNote;
                      final noteController = TextEditingController();
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Add ${item.name}'),
                          content: TextField(
                            controller: noteController,
                            decoration: const InputDecoration(
                                labelText: 'Custom note (optional)'),
                          ),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.of(ctx).pop(false),
                                child: const Text('Cancel')),
                            ElevatedButton(
                                onPressed: () {
                                  customNote = noteController.text.trim();
                                  Navigator.of(ctx).pop(true);
                                },
                                child: const Text('Add')),
                          ],
                        ),
                      );
                      if (result == true) {
                        orderProvider.addItem(item, customNote: customNote);
                        if (context.mounted) {
                          // 👇 Use floating SnackBar so it doesn’t cover bottom button
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${item.name} added to order'),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.only(
                                bottom: 80, // space above the button
                                left: 16,
                                right: 16,
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                  );
                },
              ),
            ),
            ElevatedButton(
              // 👇 watch() ensures this updates when order changes
              onPressed: orderProvider.items.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).pushNamed('/review');
                    },
              child: const Text('Review Order'),
            ),
          ],
        ),
      ),
    ),
  );
}
}
