import 'package:flutter/foundation.dart';

import '../db/menu_database.dart';
import '../models/menu_item.dart';

class MenuProvider extends ChangeNotifier {
  final MenuDatabase _database = MenuDatabase.instance;
  List<MenuItem> _items = [];
  bool _loaded = false;

  List<MenuItem> get items => _items;

  Future<void> load() async {
    if (!_loaded) {
      _items = await _database.getActiveItems();
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> addItem(MenuItem item) async {
    final id = await _database.insertItem(item);
    final newItem = item.copyWith(id: id);
    _items.add(newItem);
    notifyListeners();
  }

  Future<void> updateItem(MenuItem item) async {
    await _database.updateItem(item);
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      _items[index] = item;
      notifyListeners();
    }
  }

  Future<void> deleteItem(MenuItem item) async {
    if (item.id != null) {
      await _database.deleteItem(item.id!);
    }
    _items.removeWhere((e) => e.id == item.id);
    notifyListeners();
  }
}
