import 'dart:convert';

import 'package:desktop/features/accounts/payment_entry/models/payment_model.dart';
import 'package:desktop/features/supplier/model/supplier_model.dart';
import 'package:http/http.dart' as http;

class BackendApi {
  BackendApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000/api',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /////////////////////////////////// Customers-Methods //////////////////////////////////////

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final response = await _client.get(_uri('/customers'));
    _throwIfNotOk(response);
    final data = jsonDecode(response.body);
    print("Customers Response: ${data}");
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> createCustomer(
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.post(
      _uri('/customers'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    _throwIfNotOk(response, expectedStatus: 201);
    final data = jsonDecode(response.body);
    return data is Map<String, dynamic>
        ? data
        : Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateCustomer(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.put(
      _uri('/customers/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    _throwIfNotOk(response);

    final data = jsonDecode(response.body);

    return data is Map<String, dynamic>
        ? data
        : Map<String, dynamic>.from(data as Map);
  }

  Future<void> deleteCustomer(String id) async {
    final response = await _client.delete(_uri('/customers/$id'));

    _throwIfNotOk(response);
  }

  Future<List<Map<String, dynamic>>> getCatalog() async {
    final response = await _client.get(_uri('/catalog'));
    _throwIfNotOk(response);
    final data = jsonDecode(response.body);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  /////////////////////////////////// Orders-Methods //////////////////////////////////////

  Future<List<Map<String, dynamic>>> getOrders() async {
    final response = await _client.get(_uri('/orders'));
    _throwIfNotOk(response);
    final data = jsonDecode(response.body);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> payload) async {
    final response = await _client.post(
      _uri('/orders'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    _throwIfNotOk(response, expectedStatus: 201);
    final data = jsonDecode(response.body);
    return data is Map<String, dynamic>
        ? data
        : Map<String, dynamic>.from(data as Map);
  }

  Future<void> updateOrderStatus(
    String idOrCode,
    String status, {
    String? transportName,
    String? dispatchAssignee,
    DateTime? dispatchTime,
    DateTime? expectedDeliveryTime,
    DateTime? deliveredTime,
  }) async {
    final response = await _client.patch(
      _uri('/orders/$idOrCode/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'status': status,
        'transportName': transportName,
        'dispatchAssignee': dispatchAssignee,
        'dispatchTime': dispatchTime?.toIso8601String(),
        'expectedDeliveryTime': expectedDeliveryTime?.toIso8601String(),
        'deliveredTime': deliveredTime?.toIso8601String(),
      }),
    );
    _throwIfNotOk(response);
  }

  Future<List<dynamic>> getDraftOrders() async {
    final response = await http.get(Uri.parse('$baseUrl/orders/drafts'));

    if (response.statusCode != 200) {
      throw Exception('Failed to load draft orders');
    }

    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getDraftOrderById(String id) async {
    final response = await _client.get(_uri('/orders/$id'));

    print(response.body);

    _throwIfNotOk(response);

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  Future<void> deleteDraft(String id) async {
    final response = await _client.delete(_uri('/orders/$id'));

    _throwIfNotOk(response);
  }
Future<List<Map<String, dynamic>>> getCustomerOrders(
  String customerId,
) async {
  final response = await _client.get(
    _uri('/orders/customer/$customerId'),
  );

  _throwIfNotOk(response);

  final data = jsonDecode(response.body);

  if (data is! List) return const [];

  return data
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}
Future<List<Map<String, dynamic>>> getSuppliers() async {
  final response = await _client.get(
    _uri('/suppliers'),
  );

  _throwIfNotOk(response);

  final data = jsonDecode(response.body);

  if (data is! List) return const [];

  return data
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}
  Future<Map<String, dynamic>> createWarehouseReceipt(
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.post(
      _uri('/warehouse/receipts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    _throwIfNotOk(response, expectedStatus: 201);
    final data = jsonDecode(response.body);
    return data is Map<String, dynamic>
        ? data
        : Map<String, dynamic>.from(data as Map);
  }
  Future<List<SupplierInvoiceModel>> getSupplierInvoices(
  String supplierName,
) async {
  final response = await _client.get(
    _uri('/supplier-invoices/$supplierName'),
  );

  if (response.statusCode != 200) {
    return [];
  }

  final data = jsonDecode(response.body);

  return (data as List)
      .map(
        (e) => SupplierInvoiceModel.fromJson(e),
      )
      .toList();
}

  Future<List<CustomerInvoiceModel>> getCustomerInvoices(
    String customerId,
  ) async {
    final response = await _client.get(_uri('/orders/customer/$customerId'));

    if (response.statusCode != 200) {
      return [];
    }

    if (response.body.isEmpty) {
      return [];
    }

    final data = jsonDecode(response.body);

    if (data is! List) return [];

    return (data as List)
        .map(
          (e) => CustomerInvoiceModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }
Future<List<Map<String, dynamic>>> getPayments() async {
  final response = await _client.get(_uri('/payments'));

  _throwIfNotOk(response);

  final data = jsonDecode(response.body);

  if (data is! List) return const [];

  return data
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

Future<Map<String, dynamic>> createPayment(
  Map<String, dynamic> payload,
) async {
  final response = await _client.post(
    _uri('/payments'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  );

  _throwIfNotOk(response, expectedStatus: 201);

  final data = jsonDecode(response.body);

  return data is Map<String, dynamic>
      ? data
      : Map<String, dynamic>.from(data as Map);
}
Future<Map<String, dynamic>> updatePayment(
  String id,
  Map<String, dynamic> payload,
) async {
  final response = await _client.put(
    _uri('/payments/$id'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  );

  _throwIfNotOk(response);

  final data = jsonDecode(response.body);

  return data is Map<String, dynamic>
      ? data
      : Map<String, dynamic>.from(data as Map);
}
Future<void> deletePayment(String id) async {
  final response = await _client.delete(
    _uri('/payments/$id'),
  );

  _throwIfNotOk(response);
}
  void _throwIfNotOk(http.Response response, {int expectedStatus = 200}) {
    if (response.statusCode == expectedStatus) return;
    if (expectedStatus == 200 &&
        response.statusCode >= 200 &&
        response.statusCode < 300) {
      return;
    }
    final message = _extractError(response.body);
    throw Exception('API ${response.statusCode}: $message');
  }

  String _extractError(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return body;
    } catch (_) {
      return body;
    }
  }
}
