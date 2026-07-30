class PaymentModel {
  final String? id;
  final String voucherNo;
  final String customerId;
  final String? supplierId;
  final String? invoiceId;
  final String customerName;
  final String? partyName;
  final String? invoiceNo;
  final String paymentMode;
  final double amount;
  final String referenceNo;
  final String? chequeNo;
  final DateTime? chequeDate;
  final String remarks;
  final DateTime paymentDate;
  final String status;

  const PaymentModel({
    this.id,
    required this.voucherNo,
    required this.customerId,
    this.supplierId,
    this.invoiceId,
    required this.customerName,
    this.partyName,
    this.invoiceNo,
    required this.paymentMode,
    required this.amount,
    required this.referenceNo,
    this.chequeNo,
    this.chequeDate,
    required this.remarks,
    required this.paymentDate,
    required this.status,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id']?.toString(),
      voucherNo: json['voucher_no'] ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      supplierId: json['supplier_id']?.toString(),
      invoiceId: json['invoice_id']?.toString(),
      customerName: json['customer_name'] ?? '',
      partyName: json['party_name']?.toString() ?? json['customer_name'] ?? '',
      invoiceNo: json['invoice_no']?.toString() ?? '',
      paymentMode: json['payment_method'] ?? json['payment_mode'] ?? '',
      amount: double.tryParse(
            json['amount']?.toString() ?? '0',
          ) ??
          0,
      referenceNo: json['reference_no'] ?? '',
      chequeNo: json['cheque_no']?.toString(),
      chequeDate: json['cheque_date'] != null
          ? DateTime.tryParse(json['cheque_date'].toString())
          : null,
      remarks: json['remarks'] ?? json['notes'] ?? '',
      paymentDate:
          json['payment_date'] != null
              ? DateTime.parse(json['payment_date'])
              : DateTime.now(),
      status: json['status'] ?? 'Paid',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'voucher_no': voucherNo,
      'customer_id': customerId.isNotEmpty ? customerId : null,
      'supplier_id': supplierId,
      'invoice_id': invoiceId,
      'customer_name': customerName,
      'payment_method': paymentMode,
      'amount': amount,
      'reference_no': referenceNo,
      'cheque_no': chequeNo,
      'cheque_date': chequeDate?.toIso8601String(),
      'notes': remarks,
      'payment_date': paymentDate.toIso8601String(),
      'status': status,
    };
  }

  PaymentModel copyWith({
    String? id,
    String? voucherNo,
    String? customerId,
    String? supplierId,
    String? invoiceId,
    String? customerName,
    String? partyName,
    String? invoiceNo,
    String? paymentMode,
    double? amount,
    String? referenceNo,
    String? chequeNo,
    DateTime? chequeDate,
    String? remarks,
    DateTime? paymentDate,
    String? status,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      voucherNo: voucherNo ?? this.voucherNo,
      customerId: customerId ?? this.customerId,
      supplierId: supplierId ?? this.supplierId,
      invoiceId: invoiceId ?? this.invoiceId,
      customerName: customerName ?? this.customerName,
      partyName: partyName ?? this.partyName,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      paymentMode: paymentMode ?? this.paymentMode,
      amount: amount ?? this.amount,
      referenceNo: referenceNo ?? this.referenceNo,
      chequeNo: chequeNo ?? this.chequeNo,
      chequeDate: chequeDate ?? this.chequeDate,
      remarks: remarks ?? this.remarks,
      paymentDate: paymentDate ?? this.paymentDate,
      status: status ?? this.status,
    );
  }
}

class CustomerInvoiceModel {
  final String id;
  final String invoiceNo;
  final double amount;
  final double paidAmount;
  final double remainingAmount;
  final String status;
  final DateTime? invoiceDate;

  const CustomerInvoiceModel({
    required this.id,
    required this.invoiceNo,
    required this.amount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    this.invoiceDate,
  });

  factory CustomerInvoiceModel.fromJson(Map<String, dynamic> json) {
    final amount = double.tryParse(
          (json['amount'] ?? json['grand_total'] ?? '0').toString(),
        ) ??
        0;
    final paidAmount = double.tryParse(
          (json['paid_amount'] ?? '0').toString(),
        ) ??
        0;

    return CustomerInvoiceModel(
      id: json['id']?.toString() ?? '',
      invoiceNo:
          json['order_code']?.toString() ??
          json['invoice_no']?.toString() ??
          '',
      amount: amount,
      paidAmount: paidAmount,
      remainingAmount: double.tryParse(
            (json['remaining_amount'] ?? (amount - paidAmount)).toString(),
          ) ??
          0,
      status: json['status']?.toString() ?? '',
      invoiceDate: json['invoice_date'] != null
          ? DateTime.tryParse(json['invoice_date'].toString())
          : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : (json['invoice_date_raw'] != null
                  ? DateTime.tryParse(json['invoice_date_raw'].toString())
                  : null)),
    );
  }
}

class CustomerModel {
  final String id;
  final String name;

  const CustomerModel({
    required this.id,
    required this.name,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id']?.toString() ?? '',
      name: json['company_name']?.toString() ?? '',
    );
  }
}