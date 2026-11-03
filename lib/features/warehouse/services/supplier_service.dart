import 'dart:convert';

import 'package:desktop/core/network/backend_api.dart';
import 'package:http/http.dart' as http;

import '../models/supplier_model.dart';

class SupplierService {
  SupplierService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse('${BackendApi.baseUrl}$path').replace(
      queryParameters: queryParameters,
    );
  }

  Future<List<SupplierModel>> getSuppliers({String? search}) async {
    final query = search?.trim();
    final response = await _client.get(
      _uri('/suppliers', query == null || query.isEmpty ? null : {'q': query}),
    );
    if (response.statusCode != 200) {
      throw _responseException(response, 'Unable to load suppliers');
    }

    final data = jsonDecode(response.body);
    if (data is! List) {
      throw const FormatException('Supplier response must be a list');
    }
    return data
        .whereType<Map>()
        .map((item) => SupplierModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<SupplierModel> getSupplierById(int id) async {
    final suppliers = await getSuppliers();
    return suppliers.firstWhere(
      (supplier) => supplier.id == id.toString(),
      orElse: () => throw Exception('Supplier not found'),
    );
  }

  Future<SupplierModel> getSupplierByName(String name) async {
    final suppliers = await getSuppliers(search: name);
    return suppliers.firstWhere(
      (supplier) => supplier.name.toLowerCase() == name.trim().toLowerCase(),
      orElse: () => throw Exception('Supplier not found'),
    );
  }

  Future<SupplierModel> addSupplier({
    required String name,
    required String code,
    required String phone,
    required String gstin,
    required String address,
    required String location,
    String contact = '',
  }) async {
    final response = await _client.post(
      _uri('/suppliers'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name.trim(),
        'code': code.trim(),
        'contact': contact.trim(),
        'phone': phone.trim(),
        'gstin': gstin.trim(),
        'address': address.trim(),
        'location': location.trim(),
      }),
    );
    if (response.statusCode != 201) {
      throw _responseException(response, 'Unable to create supplier');
    }
    final data = jsonDecode(response.body);
    if (data is! Map) {
      throw const FormatException('Supplier response must be an object');
    }
    return SupplierModel.fromJson(Map<String, dynamic>.from(data));
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
