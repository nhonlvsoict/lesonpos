import 'package:flutter/foundation.dart';

import '../models/menu_item.dart';
import '../models/order_item.dart';

class OrderProvider extends ChangeNotifier {
  String? tableNo;
  String? note;
  final List<OrderItem> _items = [];

  List<OrderItem> get items => List.unmodifiable(_items);

  int get totalPence =>
      _items.fold(0, (sum, oi) => sum + oi.item.pricePence * oi.quantity);

  void startOrder(String table, String? orderNote) {
    tableNo = table;
    note = orderNote;
    _items.clear();
    notifyListeners();
  }

  void addItem(MenuItem item, {String? customNote}) {
    // find same item & note
    for (final oi in _items) {
      if (oi.item.id == item.id && oi.note == customNote) {
        oi.quantity++;
        notifyListeners();
        return;
      }
    }
    _items.add(OrderItem(item: item, note: customNote));
    notifyListeners();
  }

  void updateQuantity(OrderItem oi, int qty) {
    oi.quantity = qty;
    if (oi.quantity <= 0) {
      _items.remove(oi);
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    tableNo = null;
    note = null;
    notifyListeners();
  }
}
