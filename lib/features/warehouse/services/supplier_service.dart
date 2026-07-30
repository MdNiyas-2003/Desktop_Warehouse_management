import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/supplier_model.dart';

class SupplierService {
  final _client = http.Client();
  static const String baseUrl = 'http://localhost:4000/api';

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<List<SupplierModel>> getSuppliers() async {
    try {
      final response = await _client.get(_uri('/suppliers'));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      if (data is! List) return [];
      return data
          .map((item) => SupplierModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching suppliers: $e');
      return [];
    }
  }

  Future<SupplierModel> getSupplierById(int id) async {
    try {
      final response = await _client.get(_uri('/suppliers/$id'));
      if (response.statusCode != 200)
        throw Exception('Failed to fetch supplier');
      final data = jsonDecode(response.body);
      return SupplierModel.fromJson(data is Map<String, dynamic> ? data : {});
    } catch (e) {
      print('Error fetching supplier: $e');
      rethrow;
    }
  }

  Future<SupplierModel> getSupplierByName(String name) async {
    try {
      final response = await _client.get(_uri('/suppliers/search?name=$name'));
      if (response.statusCode != 200) throw Exception('Supplier not found');
      final data = jsonDecode(response.body);
      return SupplierModel.fromJson(data is Map<String, dynamic> ? data : {});
    } catch (e) {
      print('Error fetching supplier by name: $e');
      rethrow;
    }
  }

  Future<SupplierModel> addSupplier({
    required String name,
    required String code,
    required String phone,
    required String gstin,
    required String address,
    required String location,
  }) async {
    try {
      final response = await _client.post(
        _uri('/suppliers'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'code': code,
          'phone': phone,
          'gstin': gstin,
          'address': address,
          'location': location,
          'outstandingBalance': 0.0,
        }),
      );
      if (response.statusCode != 201) throw Exception('Failed to add supplier');
      final data = jsonDecode(response.body);
      return SupplierModel.fromJson(data is Map<String, dynamic> ? data : {});
    } catch (e) {
      print('Error adding supplier: $e');
      rethrow;
    }
  }
}
