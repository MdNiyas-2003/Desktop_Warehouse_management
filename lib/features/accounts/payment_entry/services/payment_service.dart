import '../../../../core/network/backend_api.dart';
import '../models/payment_model.dart';

class PaymentService {
  PaymentService._();

  static final BackendApi _api = BackendApi();

  static Future<List<PaymentModel>> getPayments() async {
    final response = await _api.getPayments();

    return response
        .map((e) => PaymentModel.fromJson(e))
        .toList();
  }

  static Future<void> createPayment(PaymentModel payment) async {
    await _api.createPayment(payment.toJson());
  }

  static Future<void> updatePayment(
    String id,
    PaymentModel payment,
  ) async {
    await _api.updatePayment(id, payment.toJson());
  }

  static Future<void> deletePayment(String id) async {
    await _api.deletePayment(id);
  }
}

class CustomerService {
  CustomerService._();

  static final BackendApi _api = BackendApi();

  static Future<List<CustomerModel>> getCustomers() async {
    final response = await _api.getCustomers();

    return response
        .map((e) => CustomerModel.fromJson(e))
        .toList();
  }

  static Future<List<CustomerInvoiceModel>> getCustomerInvoices(
    String customerId,
  ) async {
    return await _api.getCustomerInvoices(customerId);
  }
}