import 'package:desktop/core/widgets/app_snackbar.dart';
import 'package:desktop/features/accounts/payment_entry/models/payment_model.dart';
import 'package:desktop/features/accounts/payment_entry/services/payment_service.dart';
import 'package:desktop/features/supplier/model/supplier_model.dart';
import 'package:desktop/features/supplier/services/supplier_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum PaymentMode { cash, cheque, upi, bankTransfer }

class PaymentDialog extends StatefulWidget {
  final bool isSupplier;

  const PaymentDialog({super.key, required this.isSupplier});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime chequeDate = DateTime.now();
  final TextEditingController voucherController = TextEditingController();

  final TextEditingController amountController = TextEditingController();

  final TextEditingController invoiceAmountController = TextEditingController();

  final TextEditingController payableAmountController = TextEditingController();

  final TextEditingController referenceController = TextEditingController();

  final TextEditingController remarksController = TextEditingController();

  final TextEditingController chequeController = TextEditingController();

  final TextEditingController bankController = TextEditingController();

  final TextEditingController transactionController = TextEditingController();

  String? selectedParty;

  DateTime paymentDate = DateTime.now();

  PaymentMode paymentMode = PaymentMode.cash;
  List<CustomerModel> customers = [];

  CustomerModel? selectedCustomer;
  List<SupplierModel> suppliers = [];

  SupplierModel? selectedSupplier;
  List<SupplierInvoiceModel> supplierInvoices = [];

  SupplierInvoiceModel? selectedInvoice;
  List<CustomerInvoiceModel> customerInvoices = [];
  CustomerInvoiceModel? selectedCustomerInvoice;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    voucherController.text = _generateVoucherNo();
    _loadParties();
    print("Payment dialog");
  }

  String _generateVoucherNo() {
    final now = DateTime.now();
    final date = '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final sequence = now.millisecondsSinceEpoch.toString().substring(8);
    return 'RV-$date-$sequence';
  }

  Future<void> _loadParties() async {
    if (widget.isSupplier) {
      suppliers = await SupplierService.getSuppliers();
    } else {
      customers = await CustomerService.getCustomers();
    }

    setState(() {});
  }

  @override
  void dispose() {
    voucherController.dispose();
    amountController.dispose();
    invoiceAmountController.dispose();
    payableAmountController.dispose();
    referenceController.dispose();
    remarksController.dispose();
    chequeController.dispose();
    bankController.dispose();
    transactionController.dispose();
    super.dispose();
  }

  Future<void> _savePayment() async {
    if (!mounted) return;
    if (_isSaving) return;

    if (!(_formKey.currentState?.validate() ?? true)) {
      return;
    }

    if (!widget.isSupplier && selectedCustomer == null) {
      AppSnackBar.warning(message: 'Please select a customer.');
      return;
    }

    if (widget.isSupplier && selectedInvoice == null) {
      AppSnackBar.warning(message: 'Please select a supplier invoice.');
      return;
    }

    setState(() => _isSaving = true);

    final selectedInvoiceId = widget.isSupplier
        ? null
        : selectedCustomerInvoice?.id;

    final partyName = selectedCustomer?.name ?? selectedSupplier?.name ?? '';

    final createdPayment = PaymentModel(
      voucherNo: voucherController.text.trim(),
      customerId: widget.isSupplier ? '' : selectedCustomer?.id ?? '',
      supplierId: widget.isSupplier ? selectedInvoice?.id : null,
      invoiceId: selectedInvoiceId,
      customerName: partyName,
      partyName: partyName,
      invoiceNo: widget.isSupplier
          ? selectedInvoice?.invoiceNo ?? ''
          : selectedCustomerInvoice?.invoiceNo ?? '',
      paymentMode: paymentMode.toString().split('.').last,
      amount: double.tryParse(amountController.text.trim()) ?? 0,
      referenceNo: referenceController.text.trim(),
      chequeNo: paymentMode == PaymentMode.cheque ? chequeController.text.trim() : null,
      chequeDate: paymentMode == PaymentMode.cheque ? chequeDate : null,
      remarks: remarksController.text.trim(),
      paymentDate: paymentDate,
      status: 'Paid',
    );

    try {
      await PaymentService.createPayment(createdPayment);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      AppSnackBar.failed(message: 'Failed to save payment: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 620,
        height: 500,

        child: Column(
          children: [
            //------------------------------------------
            // Header
            //------------------------------------------
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(
                color: Color(0xff2563EB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),

              child: Row(
                children: [
                  const Icon(Icons.payments_outlined, color: Colors.white, size: 18),

                  const SizedBox(width: 8),

                  Text(
                    widget.isSupplier
                        ? "New Supplier Payment"
                        : "New Receipt Voucher",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  const Spacer(),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      voucherController.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            //------------------------------------------
            // Body
            //------------------------------------------
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      /// Payment Information Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Payment Information",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Row(
                              children: [
                                Expanded(
                                  child: widget.isSupplier
                                      ? DropdownSearch<SupplierModel>(
                                          selectedItem: selectedSupplier,
                                          items: (filter, _) => suppliers,
                                          itemAsString: (supplier) => supplier.name,
                                          compareFn: (item, selectedItem) =>
                                              selectedItem != null && item.name == selectedItem.name,
                                          popupProps: PopupProps.menu(
                                            showSearchBox: true,
                                            fit: FlexFit.loose,
                                            itemBuilder: (
                                              context,
                                              supplier,
                                              isDisabled,
                                              isSelected,
                                            ) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(
                                                  vertical: 12,
                                                  horizontal: 16,
                                                ),
                                                color: isSelected
                                                    ? Colors.blue.shade50
                                                    : null,
                                                child: Text(supplier.name),
                                              );
                                            },
                                          ),
                                          decoratorProps: DropDownDecoratorProps(
                                            decoration: _inputDecoration(
                                              "Supplier",
                                              Icons.business,
                                            ),
                                          ),
                                          onChanged: (supplier) async {
                                            if (supplier == null) {
                                              setState(() {
                                                selectedSupplier = null;
                                                supplierInvoices = [];
                                                selectedInvoice = null;
                                                amountController.clear();
                                                invoiceAmountController.clear();
                                                payableAmountController.clear();
                                              });
                                              return;
                                            }

                                            setState(() {
                                              selectedSupplier = supplier;
                                            });

                                            supplierInvoices =
                                                await SupplierService.getSupplierInvoices(
                                              supplier.name,
                                            );

                                            setState(() {
                                              selectedInvoice = null;
                                              amountController.clear();
                                              invoiceAmountController.clear();
                                              payableAmountController.clear();
                                            });
                                          },
                                        )
                                      : DropdownSearch<CustomerModel>(
                                          selectedItem: selectedCustomer,
                                          items: (filter, _) => customers,
                                          itemAsString: (customer) => customer.name,
                                          compareFn: (item, selectedItem) =>
                                              item.id == selectedItem?.id,
                                          popupProps: PopupProps.menu(
                                            showSearchBox: true,
                                            fit: FlexFit.loose,
                                            itemBuilder: (
                                              context,
                                              customer,
                                              isDisabled,
                                              isSelected,
                                            ) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(
                                                  vertical: 12,
                                                  horizontal: 16,
                                                ),
                                                color: isSelected
                                                    ? Colors.blue.shade50
                                                    : null,
                                                child: Text(customer.name),
                                              );
                                            },
                                          ),
                                          decoratorProps: DropDownDecoratorProps(
                                            decoration: _inputDecoration(
                                              "Customer",
                                              Icons.person_outline,
                                            ),
                                          ),
                                          onChanged: (customer) async {
                                            if (customer == null) {
                                              setState(() {
                                                selectedCustomer = null;
                                                customerInvoices = [];
                                                selectedCustomerInvoice = null;
                                                amountController.clear();
                                                invoiceAmountController.clear();
                                                payableAmountController.clear();
                                              });
                                              return;
                                            }

                                            setState(() {
                                              selectedCustomer = customer;
                                            });

                                            customerInvoices =
                                                await CustomerService.getCustomerInvoices(
                                              customer.id,
                                            );

                                            setState(() {
                                              selectedCustomerInvoice = null;
                                              amountController.clear();
                                              invoiceAmountController.clear();
                                              payableAmountController.clear();
                                            });
                                          },
                                        ),
                                ),
                                const SizedBox(width: 12),

                                Expanded(
                                  child: widget.isSupplier
                                    ? DropdownSearch<SupplierInvoiceModel>(
                                        selectedItem: selectedInvoice,
                                        items: (filter, _) => supplierInvoices,
                                        itemAsString: (invoice) => invoice.invoiceNo,
                                        popupProps: PopupProps.menu(
                                          showSearchBox: true,
                                          fit: FlexFit.loose,
                                          itemBuilder: (
                                            context,
                                            invoice,
                                            isDisabled,
                                            isSelected,
                                          ) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 12,
                                                horizontal: 16,
                                              ),
                                              color: isSelected ? Colors.blue.shade50 : null,
                                              child: Text(invoice.invoiceNo),
                                            );
                                          },
                                        ),
                                        compareFn: (item, selectedItem) =>
                                            item.id == selectedItem.id,
                                        decoratorProps: DropDownDecoratorProps(
                                          decoration: _inputDecoration(
                                            "Supplier Invoice",
                                            Icons.receipt_long,
                                          ),
                                        ),
                                        onChanged: (invoice) {
                                          setState(() {
                                            selectedInvoice = invoice;
                                            invoiceAmountController.text =
                                                (invoice?.grandTotal ?? 0)
                                                    .toStringAsFixed(2);
                                            payableAmountController.text =
                                                (invoice?.remainingAmount ??
                                                        invoice?.grandTotal ??
                                                    0)
                                                    .toStringAsFixed(2);
                                            amountController.text =
                                                (invoice?.remainingAmount ??
                                                        invoice?.grandTotal ??
                                                    0)
                                                    .toStringAsFixed(2);
                                          });
                                        },
                                      )
                                    : DropdownSearch<CustomerInvoiceModel>(
                                        selectedItem: selectedCustomerInvoice,
                                        items: (filter, _) => customerInvoices,
                                        itemAsString: (invoice) => invoice.invoiceNo,
                                        compareFn: (item, selectedItem) =>
                                            item.id == selectedItem.id,
                                        popupProps: PopupProps.menu(
                                          showSearchBox: true,
                                          fit: FlexFit.loose,
                                          itemBuilder: (
                                            context,
                                            invoice,
                                            isDisabled,
                                            isSelected,
                                          ) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 12,
                                                horizontal: 16,
                                              ),
                                              color: isSelected ? Colors.blue.shade50 : null,
                                              child: Text(invoice.invoiceNo),
                                            );
                                          },
                                        ),
                                        decoratorProps: DropDownDecoratorProps(
                                          decoration: _inputDecoration(
                                            "Customer Invoice",
                                            Icons.receipt_long,
                                          ),
                                        ),
                                        onChanged: (invoice) {
                                          setState(() {
                                            selectedCustomerInvoice = invoice;
                                            invoiceAmountController.text =
                                                (invoice?.amount ?? 0)
                                                    .toStringAsFixed(2);
                                            payableAmountController.text =
                                                (invoice?.remainingAmount ??
                                                        invoice?.amount ??
                                                    0)
                                                    .toStringAsFixed(2);
                                            amountController.text =
                                                (invoice?.remainingAmount ??
                                                        invoice?.amount ??
                                                    0)
                                                    .toStringAsFixed(2);
                                          });
                                        },
                                      ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: invoiceAmountController,
                                    readOnly: true,
                                    decoration: _inputDecoration(
                                      "Invoice Amount",
                                      Icons.account_balance_wallet_outlined,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: payableAmountController,
                                    readOnly: true,
                                    decoration: _inputDecoration(
                                      "Amount Payable",
                                      Icons.currency_rupee_outlined,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: amountController,
                                    decoration: _inputDecoration(
                                      "Amount",
                                      Icons.currency_rupee_outlined,
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      final entered = double.tryParse(
                                            value?.trim() ?? '',
                                          ) ??
                                          0;
                                      final payable = double.tryParse(
                                            payableAmountController.text,
                                          ) ??
                                          0;

                                      if (entered <= 0) {
                                        return 'Enter a valid payment amount';
                                      }
                                      if (entered > payable) {
                                        return 'Payment cannot exceed payable amount';
                                      }
                                      return null;
                                    },
                                  ),
                                ),

                                const SizedBox(width: 10),

                                Expanded(
                                  child: DropdownButtonFormField<PaymentMode>(
                                    value: paymentMode,
                                    decoration: InputDecoration(
                                      labelText: "Payment Mode",
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: PaymentMode.cash,
                                        child: Text("Cash"),
                                      ),
                                      DropdownMenuItem(
                                        value: PaymentMode.cheque,
                                        child: Text("Cheque"),
                                      ),
                                      DropdownMenuItem(
                                        value: PaymentMode.upi,
                                        child: Text("UPI"),
                                      ),
                                      DropdownMenuItem(
                                        value: PaymentMode.bankTransfer,
                                        child: Text("Bank Transfer"),
                                      ),
                                    ],
                                    onChanged: (v) {
                                      setState(() {
                                        paymentMode = v!;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    decoration: InputDecoration(
                                      labelText: "Reference No",
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            const Divider(height: 24),

                            const Text(
                              "Payment Details",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 12),

                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: _buildPaymentModeFields(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      /// Part 2
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Remarks",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 10),

                            TextFormField(
                              controller: remarksController,
                              maxLines: 4,
                              decoration: _inputDecoration(
                                "Enter remarks...",
                                Icons.notes_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            //------------------------------------------
            // Footer
            //------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),

              child: Row(
                children: [
                  SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        side: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Cancel",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  const SizedBox(width: 12),

                  primarySaveButton(
                    title: widget.isSupplier ? "Save Payment" : "Save Receipt",
                    onPressed: _isSaving ? null : () async {
                      await _savePayment();
                    },
                    isEnabled: !_isSaving,
                    isBusy: _isSaving,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget primarySaveButton({
    required String title,
    required VoidCallback? onPressed,
    bool isEnabled = true,
    bool isBusy = false,
  }) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
            ),

            const SizedBox(width: 6),

            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentModeFields() {
    switch (paymentMode) {
      case PaymentMode.cash:
        return Container(
          key: const ValueKey("cash"),
          padding: const EdgeInsets.all(14),
          decoration: _sectionDecoration(),
          child: Row(
            children: [
              Icon(Icons.payments_outlined, color: Colors.green.shade700),
              const SizedBox(width: 10),
              const Text(
                "Cash payment selected. No additional details required.",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );

      case PaymentMode.cheque:
        return Container(
          key: const ValueKey("cheque"),
          padding: const EdgeInsets.all(14),
          decoration: _sectionDecoration(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: chequeController,
                      decoration: _inputDecoration(
                        "Cheque Number",
                        Icons.receipt_long_outlined,
                      ),
                    ),
                  ),

                  const SizedBox(width: 18),

                  Expanded(
                    child: TextFormField(
                      controller: bankController,
                      decoration: _inputDecoration(
                        "Bank Name",
                        Icons.account_balance_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      controller: TextEditingController(
                        text: DateFormat("dd-MM-yyyy").format(chequeDate),
                      ),
                      decoration: _inputDecoration(
                        "Cheque Date",
                        Icons.calendar_today_outlined,
                      ).copyWith(suffixIcon: const Icon(Icons.arrow_drop_down)),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: chequeDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          helpText: "Select Cheque Date",
                        );

                        if (pickedDate != null) {
                          setState(() {
                            chequeDate = pickedDate;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
            ],
          ),
        );

      case PaymentMode.upi:
        return Container(
          key: const ValueKey("upi"),
          padding: const EdgeInsets.all(14),
          decoration: _sectionDecoration(),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: bankController,
                  decoration: _inputDecoration("UPI ID", Icons.qr_code_2),
                ),
              ),

              const SizedBox(width: 18),

              Expanded(
                child: TextFormField(
                  controller: transactionController,
                  decoration: _inputDecoration(
                    "Transaction ID",
                    Icons.confirmation_number_outlined,
                  ),
                ),
              ),
            ],
          ),
        );

      case PaymentMode.bankTransfer:
        return Container(
          key: const ValueKey("bank"),
          padding: const EdgeInsets.all(18),
          decoration: _sectionDecoration(),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: bankController,
                  decoration: _inputDecoration(
                    "Bank Name",
                    Icons.account_balance,
                  ),
                ),
              ),

              const SizedBox(width: 18),

              Expanded(
                child: TextFormField(
                  controller: transactionController,
                  decoration: _inputDecoration(
                    "Transaction Reference",
                    Icons.tag_outlined,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  InputDecoration _inputDecoration(String title, IconData icon) {
    return InputDecoration(
      labelText: title,

      prefixIcon: Icon(icon, size: 18),

      filled: true,
      fillColor: Colors.white,

      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),

      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),

      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0xff2563EB), width: 1.5),
      ),
    );
  }

  BoxDecoration _sectionDecoration() {
    return BoxDecoration(
      color: const Color(0xffF8FAFC),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade300),
    );
  }
}
