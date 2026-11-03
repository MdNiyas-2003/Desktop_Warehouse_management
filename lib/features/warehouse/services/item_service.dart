import 'dart:convert';

import 'package:desktop/core/network/backend_api.dart';
import 'package:http/http.dart' as http;

import '../models/item_model.dart';

class ItemService {
  ItemService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _itemsUri({int? categoryId, String? search}) {
    final parameters = <String, String>{};
    if (categoryId != null) parameters['categoryId'] = categoryId.toString();
    if (search != null && search.trim().isNotEmpty) {
      parameters['q'] = search.trim();
    }
    return Uri.parse(
      '${BackendApi.baseUrl}/items',
    ).replace(queryParameters: parameters.isEmpty ? null : parameters);
  }

  /// Get all items or items filtered by category and/or name.
  Future<List<ItemModel>> getItems({int? categoryId, String? search}) async {
    final response = await _client.get(
      _itemsUri(categoryId: categoryId, search: search),
    );
    if (response.statusCode != 200) {
      throw _responseException(response, 'Failed to load items');
    }

    final data = jsonDecode(response.body);
    if (data is! List) {
      throw const FormatException('Item response must be a list');
    }
    return data
        .whereType<Map>()
        .map((item) => ItemModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Add a new item without changing existing stock.
  Future<ItemModel> addItem({
    required int categoryId,
    required String itemName,
    required String unit,
    required double rate,
    required double gst,
    required double stock,
  }) async {
    final response = await _client.post(
      Uri.parse('${BackendApi.baseUrl}/items'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'categoryId': categoryId,
        'itemName': itemName.trim(),
        'unit': unit.trim(),
        'rate': rate,
        'gst': gst,
        'stock': stock,
      }),
    );

    if (response.statusCode != 201) {
      throw _responseException(response, 'Unable to add item');
    }
    final data = jsonDecode(response.body);
    if (data is! Map) {
      throw const FormatException('Item response must be an object');
    }
    return ItemModel.fromJson(Map<String, dynamic>.from(data));
  }

  /// Delete item.
  Future<void> deleteItem(int id) async {
    final response = await _client.delete(
      Uri.parse('${BackendApi.baseUrl}/items/$id'),
    );
    if (response.statusCode != 200) {
      throw _responseException(response, 'Delete failed');
    }
  }

  Exception _responseException(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) {
        return Exception(body['message'].toString());
      }
    } on FormatException {
      // Use the status-based message for non-JSON responses.
    }
    return Exception('$fallback (HTTP ${response.statusCode})');
  }
}
