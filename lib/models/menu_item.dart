class MenuItem {
  final int? id;
  final String name;
  final String category;
  final int pricePence;
  final bool isActive;

  MenuItem({
    this.id,
    required this.name,
    required this.category,
    required this.pricePence,
    this.isActive = true,
  });

  MenuItem copyWith({
    int? id,
    String? name,
    String? category,
    int? pricePence,
    bool? isActive,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      pricePence: pricePence ?? this.pricePence,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price_pence': pricePence,
      'is_active': isActive ? 1 : 0,
    };
  }

  static MenuItem fromMap(Map<String, Object?> map) {
    return MenuItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: map['category'] as String,
      pricePence: map['price_pence'] as int,
      isActive: (map['is_active'] as int) == 1,
    );
  }
}
