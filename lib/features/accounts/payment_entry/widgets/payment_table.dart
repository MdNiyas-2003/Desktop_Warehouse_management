  import 'package:flutter/material.dart';

  import '../models/payment_model.dart';

  class PaymentTable extends StatelessWidget {
    const PaymentTable({
      super.key,
      required this.payments,
      this.onEdit,
      this.onDelete,
    });

    final List<PaymentModel> payments;
    final ValueChanged<PaymentModel>? onEdit;
    final ValueChanged<PaymentModel>? onDelete;

    @override
    Widget build(BuildContext context) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 52,
            dataRowMinHeight: 58,
            dataRowMaxHeight: 58,
            columnSpacing: 26,
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            columns: const [
              DataColumn(label: Text("Voucher")),
              DataColumn(label: Text("Customer")),
              DataColumn(label: Text("Mode")),
              DataColumn(label: Text("Reference")),
              DataColumn(label: Text("Amount")),
              DataColumn(label: Text("Date")),
              DataColumn(label: Text("Status")),
              DataColumn(label: Text("Action")),
            ],
            rows: payments.map((payment) {
              return DataRow(
                cells: [
                  DataCell(Text(payment.voucherNo)),
                  DataCell(Text(payment.customerName)),
                  DataCell(Text(payment.paymentMode)),
                  DataCell(Text(payment.referenceNo)),
                  DataCell(
                    Text(
                      "\$${payment.amount.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      "${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}",
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        payment.status,
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.blue,
                          ),
                          onPressed: () {
                            if (onEdit != null) {
                              onEdit!(payment);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            if (onDelete != null) {
                              onDelete!(payment);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      );
    }
  }