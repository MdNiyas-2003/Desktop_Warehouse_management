class SupplierModel {
  final String name;
  final String contact;
  final String phone;
  final String gstin;
  final String address;

  const SupplierModel({
    required this.name,
    required this.contact,
    required this.phone,
    required this.gstin,
    required this.address,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      name: json['supplier_name'] ?? '',
      contact: json['supplier_contact'] ?? '',
      phone: json['supplier_phone'] ?? '',
      gstin: json['supplier_gstin'] ?? '',
      address: json['supplier_address'] ?? '',
    );
  }
}
class SupplierInvoiceModel {
  final String id;
  final String invoiceNo;
  final double grandTotal;
  final double paidAmount;
  final double remainingAmount;
  final DateTime? invoiceDate;

  SupplierInvoiceModel({
    required this.id,
    required this.invoiceNo,
    required this.grandTotal,
    required this.paidAmount,
    required this.remainingAmount,
    this.invoiceDate,
  });

  factory SupplierInvoiceModel.fromJson(Map<String, dynamic> json) {
    final grandTotal = double.tryParse(
          (json['grand_total'] ?? '0').toString(),
        ) ??
        0;
    final paidAmount = double.tryParse(
          (json['paid_amount'] ?? '0').toString(),
        ) ??
        0;

    return SupplierInvoiceModel(
      id: json['id']?.toString() ?? '',
      invoiceNo: json['invoice_no'] ?? '',
      grandTotal: grandTotal,
      paidAmount: paidAmount,
      remainingAmount: double.tryParse(
            (json['remaining_amount'] ?? (grandTotal - paidAmount)).toString(),
          ) ??
          0,
      invoiceDate: json['invoice_date'] != null
          ? DateTime.tryParse(json['invoice_date'].toString())
          : null,
    );
  }
}