import 'menu_item.dart';

class OrderItem {
  final MenuItem item;
  int quantity;
  String? note;

  OrderItem({
    required this.item,
    this.quantity = 1,
    this.note,
  });
}
