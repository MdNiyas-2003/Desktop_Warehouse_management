import 'package:desktop/features/supplier/model/supplier_model.dart';

import '../../../core/network/backend_api.dart';

class SupplierService {
  SupplierService._();

  static final BackendApi _api = BackendApi();

  static Future<List<SupplierModel>> getSuppliers() async {
    final response = await _api.getSuppliers();

    return response
        .map((e) => SupplierModel.fromJson(e))
        .toList();
  }

  static Future<List<SupplierInvoiceModel>> getSupplierInvoices(
    String supplierName,
  ) async {
    return await _api.getSupplierInvoices(supplierName);
  }
}