class SupplierModel {
  final int? id;
  final String name;
  final String code;
  final String phone;
  final String gstin;
  final String address;
  final String location;
  final double outstandingBalance;

  SupplierModel({
    this.id,
    required this.name,
    required this.code,
    required this.phone,
    required this.gstin,
    required this.address,
    required this.location,
    required this.outstandingBalance,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: json['id'],
      name: json['supplier_name'] ?? json['name'] ?? '',
      code:
          json['supplier_code'] ??
          json['code'] ??
          json['supplier_contact'] ??
          json['supplier_phone'] ??
          '',
      phone: json['supplier_phone'] ?? json['phone'] ?? '',
      gstin: json['supplier_gstin'] ?? json['gstin'] ?? '',
      address: json['supplier_address'] ?? json['address'] ?? '',
      location:
          json['supplier_location'] ??
          json['location'] ??
          json['supplier_address'] ??
          '',
      outstandingBalance:
          double.tryParse(json['outstandingBalance']?.toString() ?? "0") ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'phone': phone,
      'gstin': gstin,
      'address': address,
      'location': location,
      'outstandingBalance': outstandingBalance,
    };
  }
}
