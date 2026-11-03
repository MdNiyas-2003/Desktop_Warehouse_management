import 'dart:convert';

import 'package:desktop/core/network/backend_api.dart';
import 'package:http/http.dart' as http;

import '../models/category_model.dart';

class CategoryService {
  Future<List<CategoryModel>> getCategories({String? search}) async {
    final trimmedSearch = search?.trim();
    final uri = Uri.parse('${BackendApi.baseUrl}/categories').replace(
      queryParameters: trimmedSearch == null || trimmedSearch.isEmpty
          ? null
          : {'q': trimmedSearch},
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw _responseException(response, 'Failed to load categories');
    }

    final data = jsonDecode(response.body);
    if (data is! List) {
      throw const FormatException('Category response must be a list');
    }
    return data
        .whereType<Map>()
        .map((item) => CategoryModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<CategoryModel> addCategory({
    required String name,
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse('${BackendApi.baseUrl}/categories'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"name": name, "description": description}),
    );

    if (response.statusCode == 201) {
      return CategoryModel.fromJson(jsonDecode(response.body));
    }

    throw _responseException(response, 'Unable to add category');
  }

  Future<void> deleteCategory(int id) async {
    final response = await http.delete(
      Uri.parse('${BackendApi.baseUrl}/categories/$id'),
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
