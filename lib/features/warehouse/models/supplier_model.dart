class SupplierModel {
  final String? id;
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
      id: json['id']?.toString(),
      name: json['supplier_name'] ?? json['name'] ?? '',
      code:
          json['supplier_code'] ??
          json['code'] ??
          json['supplier_contact'] ??
          json['supplier_phone'] ??
          '',
      phone: (json['supplier_phone'] ?? json['phone'] ?? '').toString(),
      gstin: (json['supplier_gstin'] ?? json['gstin'] ?? '').toString(),
      address: (json['supplier_address'] ?? json['address'] ?? '').toString(),
      location:
          (json['supplier_location'] ??
                  json['location'] ??
                  json['supplier_address'] ??
                  '')
              .toString(),
      outstandingBalance:
          double.tryParse(
            (json['outstanding_balance'] ?? json['outstandingBalance'] ?? '0')
                .toString(),
          ) ??
          0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'contact': code,
      'phone': phone,
      'gstin': gstin,
      'address': address,
      'location': location,
      'outstandingBalance': outstandingBalance,
    };
  }
}
