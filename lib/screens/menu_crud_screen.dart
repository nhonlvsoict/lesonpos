import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/menu_item.dart';
import '../providers/menu_provider.dart';

class MenuCrudScreen extends StatefulWidget {
  const MenuCrudScreen({super.key});

  @override
  State<MenuCrudScreen> createState() => _MenuCrudScreenState();
}

class _MenuCrudScreenState extends State<MenuCrudScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        context.read<MenuProvider>().load());
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Management'),
      ),
      body: ListView.builder(
        itemCount: menuProvider.items.length,
        itemBuilder: (context, index) {
          final item = menuProvider.items[index];
          return ListTile(
            title: Text(item.name),
            subtitle: Text(
                '${item.category} • £${(item.pricePence / 100).toStringAsFixed(2)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      _showAddEditDialog(context, menuProvider, item);
                    }),
                IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      menuProvider.deleteItem(item);
                    }),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          _showAddEditDialog(context, menuProvider, null);
        },
      ),
    );
  }

  void _showAddEditDialog(
      BuildContext context, MenuProvider provider, MenuItem? item) {
    final nameController =
        TextEditingController(text: item?.name ?? '');
    final categoryController =
        TextEditingController(text: item?.category ?? '');
    final priceController =
        TextEditingController(
            text: item != null
                ? (item.pricePence / 100).toStringAsFixed(2)
                : '');
    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title:
                Text(item == null ? 'Add Menu Item' : 'Edit Menu Item'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration:
                      const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: categoryController,
                  decoration:
                      const InputDecoration(labelText: 'Category'),
                ),
                TextField(
                  controller: priceController,
                  decoration:
                      const InputDecoration(labelText: 'Price (£)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final category =
                        categoryController.text.trim();
                    final priceDouble =
                        double.tryParse(priceController.text) ?? 0.0;
                    final pricePence = (priceDouble * 100).round();
                    if (item == null) {
                      await provider.addItem(MenuItem(
                          name: name,
                          category: category,
                          pricePence: pricePence));
                    } else {
                      final updated = item.copyWith(
                          name: name,
                          category: category,
                          pricePence: pricePence);
                      await provider.updateItem(updated);
                    }
                    if (context.mounted) {
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('Save')),
            ],
          );
        });
  }
}
