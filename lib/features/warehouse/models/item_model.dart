import 'category_model.dart';

class ItemModel {
  final int id;
  final int categoryId;

  final String name;
  final String code;

  final String unit;

  final double rate;
  final double gst;

  final String? hsnSac;

  final double stock;
  final bool isActive;

  final CategoryModel? category;

  const ItemModel({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.code,
    required this.unit,
    required this.rate,
    required this.gst,
    required this.stock,
    this.hsnSac,
    this.isActive = true,
    this.category,
  });

 factory ItemModel.fromJson(Map<String, dynamic> json) {
  double toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  int toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  return ItemModel(
    id: toInt(json['id']),
    categoryId: toInt(json['category_id']),
    name: json['item_name'] ?? '',
    code: json['item_code'] ?? '',
    unit: json['unit'] ?? '',
    rate: toDouble(json['rate']),
    gst: toDouble(json['gst']),
    stock: toDouble(json['stock']),
    hsnSac: json['hsn_sac'],
    isActive: json['is_active'] ?? true,
  );
}
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'name': name,
      'code': code,
      'unit': unit,
      'rate': rate,
      'gst': gst,
      'hsnSac': hsnSac,
      'stock': stock,
      'isActive': isActive,
    };
  }

  ItemModel copyWith({
    int? id,
    int? categoryId,
    String? name,
    String? code,
    String? unit,
    double? rate,
    double? gst,
    String? hsnSac,
    double? stock,
    bool? isActive,
    CategoryModel? category,
  }) {
    return ItemModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      code: code ?? this.code,
      unit: unit ?? this.unit,
      rate: rate ?? this.rate,
      gst: gst ?? this.gst,
      hsnSac: hsnSac ?? this.hsnSac,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
      category: category ?? this.category,
    );
  }

  @override
  String toString() => name;
}
