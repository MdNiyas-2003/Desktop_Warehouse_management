import 'package:desktop/core/network/backend_api.dart';
import 'package:desktop/features/orders/model/order_model.dart';

class OrderService {
  static final BackendApi _api = BackendApi();

  static Future<List<OrderModel>> getCustomerOrders(
  String customerId,
) async {
  final response =
      await _api.getCustomerOrders(customerId);

  return response
      .map((e) => OrderModel.fromJson(e))
      .toList();
}
}