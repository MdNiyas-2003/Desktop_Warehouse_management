import 'dart:convert';

import 'package:desktop/core/network/backend_api.dart';
import 'package:http/http.dart' as http;

import '../models/category_model.dart';

class CategoryService {
  Future<List<CategoryModel>> getCategories() async {
    final response = await http.get(
      Uri.parse('${BackendApi.baseUrl}/categories'),
    );

    print("Status Code: ${response.statusCode}");
    print("Response: ${response.body}");

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);

      return data.map((e) => CategoryModel.fromJson(e)).toList();
    }

    throw Exception('Failed to load categories');
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

    throw Exception('Unable to add category');
  }

  Future<void> deleteCategory(int id) async {
    final response = await http.delete(
      Uri.parse('${BackendApi.baseUrl}/categories/$id'),
    );

    if (response.statusCode != 200) {
      throw Exception('Delete failed');
    }
  }
}
