class OrderModel {
  final String id;
  final String orderCode;
  final double amount;
  final String status;

  const OrderModel({
    required this.id,
    required this.orderCode,
    required this.amount,
    required this.status,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'].toString(),
      orderCode: json['order_code'],
      amount: double.parse(json['amount'].toString()),
      status: json['status'],
    );
  }
}