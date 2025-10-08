import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';

import '../db/menu_database.dart';
import '../models/menu_item.dart';

class MenuProvider extends ChangeNotifier {
  final MenuDatabase _database = MenuDatabase.instance;
  List<MenuItem> _items = [];
  bool _loaded = false;

  List<MenuItem> get items => _items;

Future<void> load() async {
  if (_loaded) return;

  // Load existing active items
  _items = await _database.getActiveItems();

  // If empty, import default menu from assets
  if (_items.isEmpty) {
    debugPrint('[MenuProvider] No menu items found. Importing seed JSON...');
    await importFromJson();
    _items = await _database.getActiveItems();
  }

  // Sort the final list
  _sortItems();

  _loaded = true;
  notifyListeners();
}


  /// Add a single new menu item
  Future<void> addItem(MenuItem item) async {
    final id = await _database.insertItem(item);
    final newItem = item.copyWith(id: id);
    _items.add(newItem);
    _sortItems();
    notifyListeners();
  }

  /// Update an existing menu item
  Future<void> updateItem(MenuItem item) async {
    await _database.updateItem(item);
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      _items[index] = item;
      _sortItems();
      notifyListeners();
    }
  }

  /// Delete a menu item
  Future<void> deleteItem(MenuItem item) async {
    if (item.id != null) {
      await _database.deleteItem(item.id!);
    }
    _items.removeWhere((e) => e.id == item.id);
    notifyListeners();
  }

  /// Import seed menu from JSON into DB (run once for setup)
  Future<void> importFromJson() async {
    try {
      final raw = await rootBundle.loadString('assets/menu/menu_seed.json');
      final data = jsonDecode(raw) as List<dynamic>;

      final menuItems = data.map((e) => MenuItem(
            name: e['name'] as String,
            category: e['category'] as String,
            pricePence: e['pricePence'] as int,
          ));

      for (final item in menuItems) {
        // Avoid duplicates by checking existing items
        final existing = _items.firstWhere(
          (m) => m.name == item.name && m.category == item.category,
          orElse: () => MenuItem(id: null, name: '', category: '', pricePence: 0),
        );
        if (existing.name.isEmpty) {
          await _database.insertItem(item);
        }
      }

      // Reload from DB after import
      _items = await _database.getActiveItems();
      _sortItems();

      _loaded = true;
      notifyListeners();
    } catch (e, st) {
      debugPrint('Error importing menu: $e\n$st');
    }
  }

  /// Internal sorting helper
  void _sortItems() {
    _items.sort((a, b) {
      final c = _catRank(a.category).compareTo(_catRank(b.category));
      return c != 0 ? c : a.name.compareTo(b.name);
    });
  }

  /// Preferred manual category order for nicer UI
  static const _categoryOrder = [
    'Starters',
    'Noodle Soup',
    'Salad Noodle',
    'Banh Mi / Baguette',
    'Rice / Sticky Rice',
    'Vietnamese Coffee',
    'Matcha • Tea',
    'Smoothie',
    'Beer',
  ];

  static int _catRank(String c) {
    final idx = _categoryOrder.indexOf(c);
    return idx == -1 ? 9999 : idx;
  }
}
