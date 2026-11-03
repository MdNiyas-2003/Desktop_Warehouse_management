part of 'counter_billing_screen.dart';

mixin _CounterBillingMethods on _CounterBillingScreenStateBase {
  // ============================================================
  // REAL ITEM CALCULATION
  // ============================================================

  @override
  @override
  void _calculateEntryAmount() {
    final q = double.tryParse(qtyController.text) ?? 0;
    final r = double.tryParse(rateController.text) ?? 0;

    amountController.text = q > 0 && r > 0 ? money(q * r) : '';
  }

  // ============================================================
  // ADD ITEM BELOW TABLE
  // ============================================================

  @override
  @override
  void _addItem() {
    final code = itemCodeController.text.trim();
    final name = itemNameController.text.trim();

    final itemQty = int.tryParse(qtyController.text.trim()) ?? 0;

    final itemRate = double.tryParse(rateController.text.trim()) ?? 0;

    if (code.isEmpty) {
      _showMessage('Enter Item Code');
      return;
    }

    if (name.isEmpty) {
      _showMessage('Enter Item Name');
      return;
    }

    if (itemQty <= 0) {
      _showMessage('Enter valid Quantity');
      return;
    }

    if (itemRate <= 0) {
      _showMessage('Enter valid Rate');
      return;
    }

    setState(() {
      items.add({
        'code': code,
        'name': name,
        'qty': itemQty,
        'unit': unit,
        'rate': itemRate,
      });

      itemCodeController.clear();
      itemNameController.clear();
      qtyController.text = '1';
      rateController.clear();
      amountController.clear();
    });
  }

  @override
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  void _saveBill() {
    _showMessage('Bill saved successfully');
  }

  @override
  @override
  void _resetBill() {
    setState(() {
      items.clear();

      mobileController.text = '9829500343';
      customerController.text = 'RISHI ACHARYA';
      addressController.text = 'BIKANER';
      billNoController.text = '2';
      discountController.text = '10';
      receivedController.clear();
      cardController.clear();
      upiController.clear();
      givenByController.clear();

      itemCodeController.clear();
      itemNameController.clear();
      qtyController.text = '1';
      rateController.clear();
      amountController.clear();

      salesman = 'Select Salesman...';
      invoiceType = 'Sale Invoice';
      unit = 'PCS';
      discountReason = 'Select Reason';
      discountEnabled = true;
    });
  }
}
