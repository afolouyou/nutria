class PantryItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final String category;
  final bool lowStock;

  const PantryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    required this.lowStock,
  });

  factory PantryItem.fromJson(Map<String, dynamic> json) {
    return PantryItem(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      name: (json['name'] ?? '').toString(),
      quantity: _toDouble(json['quantity']),
      unit: (json['unit'] ?? '').toString(),
      category: (json['category'] ?? 'other').toString(),
      lowStock: json['low_stock'] == true || json['lowStock'] == true,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'low_stock': lowStock,
    };
  }

  PantryItem copyWith({double? quantity, bool? lowStock}) {
    return PantryItem(
      id: id,
      name: name,
      quantity: quantity ?? this.quantity,
      unit: unit,
      category: category,
      lowStock: lowStock ?? this.lowStock,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PantryItem && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PantryItem($name: $quantity $unit)';
}
