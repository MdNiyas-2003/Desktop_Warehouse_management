import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/backend_api.dart';
import '../models/item_model.dart';

class ItemService {
  /// Get all items or items by category
  Future<List<ItemModel>> getItems({int? categoryId}) async {
    final uri = Uri.parse('${BackendApi.baseUrl}/items').replace(
      queryParameters: categoryId != null
          ? {'categoryId': categoryId.toString()}
          : null,
    );

    final response = await http.get(uri);
print("Status Code: ${response.statusCode}");
print("Items Response: ${response.body}");
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);

      return data.map((e) => ItemModel.fromJson(e)).toList();
    }

    throw Exception('Failed to load items');
  }

  /// Add new item
  Future<ItemModel> addItem({
    required int categoryId,
    required String itemName,
    required String itemCode,
    required String unit,
    required double rate,
    required double gst,
    required double stock,
  }) async {
    final response = await http.post(
      Uri.parse('${BackendApi.baseUrl}/items'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'categoryId': categoryId,
        'itemName': itemName,
        'itemCode': itemCode,
        'unit': unit,
        'rate': rate,
        'gst': gst,
        'stock': stock,
      }),
    );

    if (response.statusCode == 201) {
      return ItemModel.fromJson(jsonDecode(response.body));
    }

    throw Exception('Unable to add item');
  }

  /// Delete item
  Future<void> deleteItem(int id) async {
    final response = await http.delete(
      Uri.parse('${BackendApi.baseUrl}/items/$id'),
    );

    if (response.statusCode != 200) {
      throw Exception('Delete failed');
    }
  }
}
