import 'package:flutter/material.dart';

import '../../core/network/backend_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  int _selectedTab = 0;
  bool _isSubmitting = false;
  final _api = BackendApi();
  final List<_ReceiveItemRowData> _items = [];
  final _supplierController = TextEditingController();
  final _invoiceNoController = TextEditingController();
  final _invoiceDateController = TextEditingController(text: '15/07/2026');
  final _referenceController = TextEditingController();
  final _billAmountController = TextEditingController(text: '0.00');
  final _taxAmountController = TextEditingController(text: '0.00');
  final _notesController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _supplierPhoneController = TextEditingController();
  final _supplierGstinController = TextEditingController();
  final _supplierAddressController = TextEditingController();
  final _transportController = TextEditingController();
  final _vehicleController = TextEditingController();

  Future<void> _addItemRow() async {
    final row = await showDialog<_ReceiveItemRowData>(
      context: context,
      builder: (context) => const _AddItemDialog(),
    );
    if (row == null) return;
    setState(() => _items.add(row));
  }

  void _removeItemRow(int index) {
    setState(() => _items.removeAt(index));
  }

  double get _itemsSubTotal => _items.fold(
    0,
    (sum, row) =>
        sum + (row.qty * row.rate - row.discount).clamp(0, double.infinity),
  );

  double get _itemsTaxTotal => _items.fold(0, (sum, row) {
    final base = (row.qty * row.rate - row.discount).clamp(0, double.infinity);
    return sum + (base * (row.tax / 100));
  });

  String _safeInventoryCode(_ReceiveItemRowData item) {
    final code = item.itemCode.trim().toLowerCase();
    if (code.isNotEmpty && code != 'auto') {
      return code.replaceAll(RegExp(r'[^a-z0-9_-]+'), '_');
    }
    return item.itemName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  Future<void> _submitReceiveToStore() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item before submit.')),
      );
      return;
    }
    if (_supplierController.text.trim().isEmpty ||
        _invoiceNoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier and Invoice No. are required.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final subTotal = _itemsSubTotal;
      final taxTotal = _itemsTaxTotal;
      final grandTotal = subTotal + taxTotal;

      await _api.createWarehouseReceipt({
        'supplier': _supplierController.text.trim(),
        'invoiceNo': _invoiceNoController.text.trim(),
        'invoiceDate': _invoiceDateController.text.trim(),
        'referencePoNo': _referenceController.text.trim(),
        'billAmount':
            double.tryParse(_billAmountController.text.trim()) ?? subTotal,
        'taxAmount':
            double.tryParse(_taxAmountController.text.trim()) ?? taxTotal,
        'notes': _notesController.text.trim(),
        'supplierContact': _contactPersonController.text.trim(),
        'supplierPhone': _supplierPhoneController.text.trim(),
        'supplierGstin': _supplierGstinController.text.trim(),
        'supplierAddress': _supplierAddressController.text.trim(),
        'transportName': _transportController.text.trim(),
        'vehicleNo': _vehicleController.text.trim(),
        'subTotal': subTotal,
        'taxTotal': taxTotal,
        'grandTotal': grandTotal,
        'status': 'Received',
        'items': _items
            .map(
              (e) => {
                'category': e.category,
                'itemName': e.itemName,
                'itemCode': _safeInventoryCode(e),
                'hsnSac': e.hsnSac,
                'qty': e.qty,
                'unit': e.unit,
                'rate': e.rate,
                'discount': e.discount,
                'tax': e.tax,
              },
            )
            .toList(),
      });
      if (!mounted) return;

      setState(() {
        _items.clear();
      });
      _invoiceNoController.clear();
      _referenceController.clear();
      _billAmountController.text = '0.00';
      _taxAmountController.text = '0.00';
      _notesController.clear();
      _contactPersonController.clear();
      _supplierPhoneController.clear();
      _supplierGstinController.clear();
      _supplierAddressController.clear();
      _transportController.clear();
      _vehicleController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invoice saved to PostgreSQL and stock quantity updated.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _invoiceNoController.dispose();
    _invoiceDateController.dispose();
    _referenceController.dispose();
    _billAmountController.dispose();
    _taxAmountController.dispose();
    _notesController.dispose();
    _contactPersonController.dispose();
    _supplierPhoneController.dispose();
    _supplierGstinController.dispose();
    _supplierAddressController.dispose();
    _transportController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('warehouse'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Warehouse / Inward & Dispatch',
            subtitle:
                'Receive supplier items into store stock, allocate, dispatch, and track delivery.',
            action: const ActionButton(
              label: 'Receive Items',
              icon: Icons.add_business_rounded,
              primary: true,
            ),
          ),
          const SizedBox(height: 18),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PillTabBar(
                  labels: const [
                    'Receive Items',
                    // 'Allocate Stock',
                    // 'Dispatch',
                    // 'Delivery Status',
                  ],
                  selectedIndex: _selectedTab,
                  onSelected: (value) => setState(() => _selectedTab = value),
                ),
                const SizedBox(height: 18),
                if (_selectedTab == 0)
                  _ReceiveItemsPanel(
                    items: _items,
                    onAddRow: _addItemRow,
                    onRemoveRow: _removeItemRow,
                    onSubmit: _submitReceiveToStore,
                    isSubmitting: _isSubmitting,
                    supplierController: _supplierController,
                    invoiceNoController: _invoiceNoController,
                    invoiceDateController: _invoiceDateController,
                    referenceController: _referenceController,
                    billAmountController: _billAmountController,
                    taxAmountController: _taxAmountController,
                    notesController: _notesController,
                    contactPersonController: _contactPersonController,
                    supplierPhoneController: _supplierPhoneController,
                    supplierGstinController: _supplierGstinController,
                    supplierAddressController: _supplierAddressController,
                    transportController: _transportController,
                    vehicleController: _vehicleController,
                  )
                else
                  SimpleTable(
                    headers: const [
                      'Order ID',
                      'Shop Name',
                      'Dispatch Date',
                      'Status',
                      'Action',
                    ],
                    rows: const [
                      [
                        TableTextCell('ORD-1001'),
                        TableTextCell('Gupta General Store'),
                        TableTextCell('15 May 2024'),
                        _DispatchStatus('Dispatched', AppColors.success),
                        _RowActions(),
                      ],
                      [
                        TableTextCell('ORD-1002'),
                        TableTextCell('Kumar Provision'),
                        TableTextCell('15 May 2024'),
                        _DispatchStatus('Pending', AppColors.warning),
                        _RowActions(),
                      ],
                      [
                        TableTextCell('ORD-1003'),
                        TableTextCell('Royal Mart'),
                        TableTextCell('14 May 2024'),
                        _DispatchStatus('Ready', AppColors.primary),
                        _RowActions(),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DispatchStatus extends StatelessWidget {
  const _DispatchStatus(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => StatusBadge(label: label, color: color);
}

class _RowActions extends StatelessWidget {
  const _RowActions();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.visibility_outlined, size: 18),
        SizedBox(width: 10),
        Icon(Icons.print_outlined, size: 18),
      ],
    );
  }
}

class _ReceiveItemsPanel extends StatelessWidget {
  const _ReceiveItemsPanel({
    required this.items,
    required this.onAddRow,
    required this.onRemoveRow,
    required this.onSubmit,
    required this.isSubmitting,
    required this.supplierController,
    required this.invoiceNoController,
    required this.invoiceDateController,
    required this.referenceController,
    required this.billAmountController,
    required this.taxAmountController,
    required this.notesController,
    required this.contactPersonController,
    required this.supplierPhoneController,
    required this.supplierGstinController,
    required this.supplierAddressController,
    required this.transportController,
    required this.vehicleController,
  });

  final List<_ReceiveItemRowData> items;
  final VoidCallback onAddRow;
  final ValueChanged<int> onRemoveRow;
  final Future<void> Function() onSubmit;
  final bool isSubmitting;
  final TextEditingController supplierController;
  final TextEditingController invoiceNoController;
  final TextEditingController invoiceDateController;
  final TextEditingController referenceController;
  final TextEditingController billAmountController;
  final TextEditingController taxAmountController;
  final TextEditingController notesController;
  final TextEditingController contactPersonController;
  final TextEditingController supplierPhoneController;
  final TextEditingController supplierGstinController;
  final TextEditingController supplierAddressController;
  final TextEditingController transportController;
  final TextEditingController vehicleController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormSectionCard(
          title: 'Invoice & Supplier Details',
          icon: Icons.receipt_long_rounded,
          child: Column(
            children: [
              _FourColumnFields(
                first: _LabeledInput(
                  label: 'Supplier *',
                  hint: 'Select Supplier',
                  controller: supplierController,
                ),
                second: _LabeledInput(
                  label: 'Invoice No. *',
                  hint: 'Enter Invoice Number',
                  controller: invoiceNoController,
                ),
                third: _LabeledInput(
                  label: 'Contact Person',
                  hint: 'Enter Contact Name',
                  controller: contactPersonController,
                ),
                fourth: _LabeledInput(
                  label: 'Supplier Mobile',
                  hint: 'Enter Mobile Number',
                  controller: supplierPhoneController,
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(height: 10),
              _FourColumnFields(
                first: _LabeledInput(
                  label: 'Invoice Date *',
                  hint: '15/07/2026',
                  controller: invoiceDateController,
                ),
                second: _LabeledInput(
                  label: 'Reference / PO No.',
                  hint: 'Enter PO / Reference No.',
                  controller: referenceController,
                ),
                third: _LabeledInput(
                  label: 'Supplier GSTIN',
                  hint: 'Enter GST Number',
                  controller: supplierGstinController,
                ),
                fourth: _LabeledInput(
                  label: 'Transport / Courier',
                  hint: 'Enter Transport Name',
                  controller: transportController,
                ),
              ),
              const SizedBox(height: 10),
              _FourColumnFields(
                first: _LabeledInput(
                  label: 'Bill Amount (Rs) *',
                  hint: '0.00',
                  controller: billAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                second: _LabeledInput(
                  label: 'Tax Amount (Rs)',
                  hint: '0.00',
                  controller: taxAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                third: _LabeledInput(
                  label: 'Vehicle / LR No.',
                  hint: 'Enter LR / Vehicle No.',
                  controller: vehicleController,
                ),
                fourth: const SizedBox.shrink(),
              ),
              const SizedBox(height: 10),
              _TwoColumnFields(
                left: _LabeledInput(
                  label: 'Notes (Optional)',
                  hint: 'Enter notes if any...',
                  maxLines: 2,
                  controller: notesController,
                ),
                right: _LabeledInput(
                  label: 'Supplier Address',
                  hint: 'Enter Supplier Address',
                  controller: supplierAddressController,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _FormSectionCard(
          title: 'Items',
          icon: Icons.inventory_2_outlined,
          child: Column(
            children: [
              _ItemsEditorTable(items: items, onRemoveRow: onRemoveRow),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _GlossyButton(
                        label: 'Add Item',
                        icon: Icons.add_rounded,
                        onPressed: onAddRow,
                        tone: _GlossyTone.silver,
                      ),
                      _GlossyButton(
                        label: 'Scan',
                        icon: Icons.qr_code_scanner_rounded,
                        onPressed: () {},
                        tone: _GlossyTone.steel,
                      ),
                      _GlossyButton(
                        label: isSubmitting ? 'Saving' : 'Submit',
                        icon: isSubmitting ? null : Icons.save_rounded,
                        onPressed: isSubmitting ? null : () => onSubmit(),
                        tone: _GlossyTone.navy,
                        loading: isSubmitting,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormSectionCard extends StatelessWidget {
  const _FormSectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _TwoColumnFields extends StatelessWidget {
  const _TwoColumnFields({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }
}

class _FourColumnFields extends StatelessWidget {
  const _FourColumnFields({
    required this.first,
    required this.second,
    required this.third,
    required this.fourth,
  });

  final Widget first;
  final Widget second;
  final Widget third;
  final Widget fourth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: 10),
        Expanded(child: second),
        const SizedBox(width: 10),
        Expanded(child: third),
        const SizedBox(width: 10),
        Expanded(child: fourth),
      ],
    );
  }
}

class _LabeledInput extends StatelessWidget {
  const _LabeledInput({
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.controller,
    this.keyboardType,
  });

  final String label;
  final String hint;
  final int maxLines;
  final TextEditingController? controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemsEditorTable extends StatefulWidget {
  const _ItemsEditorTable({required this.items, required this.onRemoveRow});

  final List<_ReceiveItemRowData> items;
  final ValueChanged<int> onRemoveRow;

  @override
  State<_ItemsEditorTable> createState() => _ItemsEditorTableState();
}

class _ItemsEditorTableState extends State<_ItemsEditorTable> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _ItemsHeaderRow(),
        const Divider(height: 1),
        if (widget.items.isEmpty)
          Container(
            height: 96,
            alignment: Alignment.center,
            child: Text(
              'No items added yet. Click Add Item Row to enter item details.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          )
        else
          Column(
            children: List.generate(widget.items.length, (index) {
              return _ItemDisplayRow(
                index: index,
                row: widget.items[index],
                onRemove: () => widget.onRemoveRow(index),
              );
            }),
          ),
      ],
    );
  }
}

class _ItemsHeaderRow extends StatelessWidget {
  const _ItemsHeaderRow();

  @override
  Widget build(BuildContext context) {
    Widget cell(String text, {int flex = 1}) {
      return Expanded(flex: flex, child: _HeaderLabel(text));
    }

    return Container(
      color: const Color(0xFFF8FAFF),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          cell('#', flex: 4),
          cell('Item Name', flex: 20),
          cell('Category', flex: 14),
          cell('Item Code', flex: 14),
          cell('HSN / SAC', flex: 12),
          cell('Qty', flex: 10),
          cell('Unit', flex: 9),
          cell('Rate', flex: 10),
          cell('Action', flex: 7),
        ],
      ),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    );
  }
}

class _ItemDisplayRow extends StatelessWidget {
  const _ItemDisplayRow({
    required this.index,
    required this.row,
    required this.onRemove,
  });

  final int index;
  final _ReceiveItemRowData row;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final row = this.row;

    Widget cell(Widget child, {int flex = 1}) {
      return Expanded(flex: flex, child: child);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFFCFDFF),
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.55)),
        ),
      ),
      child: Row(
        children: [
          cell(Text('${index + 1}'), flex: 4),
          cell(
            Text(
              row.itemName,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            flex: 20,
          ),
          cell(Text(row.category, overflow: TextOverflow.ellipsis), flex: 14),
          cell(Text(row.itemCode, overflow: TextOverflow.ellipsis), flex: 14),
          cell(Text(row.hsnSac, overflow: TextOverflow.ellipsis), flex: 12),
          cell(Text(row.qty.toStringAsFixed(2)), flex: 10),
          cell(Text(row.unit), flex: 9),
          cell(Text(row.rate.toStringAsFixed(2)), flex: 10),
          cell(
            IconButton(
              onPressed: onRemove,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
                size: 18,
              ),
              tooltip: 'Delete row',
            ),
            flex: 8,
          ),
        ],
      ),
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog();

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _itemCodeController = TextEditingController();
  final _hsnController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _rateController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');
  final _taxController = TextEditingController(text: '0');

  String? _itemName;
  String? _category;
  String? _unit;

  double _readNumber(TextEditingController controller) {
    return double.tryParse(controller.text.trim()) ?? 0;
  }

  double get _previewSubTotal {
    final qty = _readNumber(_qtyController);
    final rate = _readNumber(_rateController);
    final discount = _readNumber(_discountController);
    return (qty * rate - discount).clamp(0, double.infinity);
  }

  double get _previewTaxAmount {
    final tax = _readNumber(_taxController);
    return _previewSubTotal * (tax / 100);
  }

  double get _previewTotal => _previewSubTotal + _previewTaxAmount;

  @override
  void dispose() {
    _itemCodeController.dispose();
    _hsnController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  InputDecoration _dialogInputDecoration({required String label}) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF7FAFF),
      labelStyle: const TextStyle(
        color: Color(0xFF6A7C9D),
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD8E0ED)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD8E0ED)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF314B79),
            fontWeight: FontWeight.w700,
            fontSize: 12.8,
          ),
        ),
      ],
    );
  }

  Widget _moneyChip({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7E1F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6E7F9E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF20325A),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 660,
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 560),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFC8D4EA)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFCFEFF), Color(0xFFEFF4FF)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2B1E2E49),
              blurRadius: 32,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 14, 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: const Color(0xFFD6E0F0)),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFEDF3FF), Color(0xFFDDE9FF)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E9FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          size: 18,
                          color: Color(0xFF2D4678),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Inventory Item',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1B2844),
                                ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Capture item details for inward stock entry',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF617496),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFF6B7FA4),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('Product Details'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _itemName,
                                decoration: _dialogInputDecoration(
                                  label: 'Item Name *',
                                ),
                                dropdownColor: const Color(0xFFF7FAFF),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Cotton Shirt - Men',
                                    child: Text('Cotton Shirt - Men'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'T-Shirt - Round Neck',
                                    child: Text('T-Shirt - Round Neck'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Denim Jeans - Men',
                                    child: Text('Denim Jeans - Men'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Kurti - Women',
                                    child: Text('Kurti - Women'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Leggings - Women',
                                    child: Text('Leggings - Women'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Kids Frock',
                                    child: Text('Kids Frock'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'School Uniform Set',
                                    child: Text('School Uniform Set'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Track Pant - Unisex',
                                    child: Text('Track Pant - Unisex'),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _itemName = value),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Select item'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _category,
                                decoration: _dialogInputDecoration(
                                  label: 'Category *',
                                ),
                                dropdownColor: const Color(0xFFF7FAFF),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Men Wear',
                                    child: Text('Men Wear'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Women Wear',
                                    child: Text('Women Wear'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Kids Wear',
                                    child: Text('Kids Wear'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Uniform',
                                    child: Text('Uniform'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Accessories',
                                    child: Text('Accessories'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Ready Mades',
                                    child: Text('Ready Mades'),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _category = value),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Select category'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _itemCodeController,
                                decoration: _dialogInputDecoration(
                                  label: 'Item Code',
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
                                controller: _hsnController,
                                decoration: _dialogInputDecoration(
                                  label: 'HSN / SAC',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _unit,
                                decoration: _dialogInputDecoration(
                                  label: 'Unit *',
                                ),
                                dropdownColor: const Color(0xFFF7FAFF),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'pcs',
                                    child: Text('pcs'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'box',
                                    child: Text('box'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'kg',
                                    child: Text('kg'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'ltr',
                                    child: Text('ltr'),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _unit = value),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Select unit'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _sectionLabel('Pricing & Quantity'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _qtyController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _dialogInputDecoration(
                                  label: 'Quantity *',
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (value) {
                                  final qty = double.tryParse(
                                    (value ?? '').trim(),
                                  );
                                  if (qty == null || qty <= 0) {
                                    return 'Enter valid qty';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _rateController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _dialogInputDecoration(
                                  label: 'Rate *',
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (value) {
                                  final rate = double.tryParse(
                                    (value ?? '').trim(),
                                  );
                                  if (rate == null || rate < 0) {
                                    return 'Enter valid rate';
                                  }
                                  return null;
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
                                controller: _discountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _dialogInputDecoration(
                                  label: 'Discount',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _taxController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _dialogInputDecoration(
                                  label: 'Tax %',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEAF2FF), Color(0xFFF4F8FF)],
                            ),
                            border: Border.all(color: const Color(0xFFD4E0F4)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _moneyChip(
                                  label: 'Sub Total',
                                  value: _previewSubTotal.toStringAsFixed(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _moneyChip(
                                  label: 'Tax Amount',
                                  value: _previewTaxAmount.toStringAsFixed(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _moneyChip(
                                  label: 'Line Total',
                                  value: _previewTotal.toStringAsFixed(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFD6E0F0))),
                    color: Color(0xFFF7FAFF),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _GlossyButton(
                        label: 'Cancel',
                        onPressed: () => Navigator.of(context).pop(),
                        tone: _GlossyTone.silver,
                      ),
                      const SizedBox(width: 10),
                      _GlossyButton(
                        label: 'Add Item',
                        icon: Icons.add_rounded,
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          Navigator.of(context).pop(
                            _ReceiveItemRowData(
                              category: _category!,
                              itemName: _itemName!,
                              itemCode: _itemCodeController.text.trim().isEmpty
                                  ? 'Auto'
                                  : _itemCodeController.text.trim(),
                              hsnSac: _hsnController.text.trim(),
                              qty:
                                  double.tryParse(_qtyController.text.trim()) ??
                                  0,
                              unit: _unit!,
                              rate:
                                  double.tryParse(
                                    _rateController.text.trim(),
                                  ) ??
                                  0,
                              discount:
                                  double.tryParse(
                                    _discountController.text.trim(),
                                  ) ??
                                  0,
                              tax:
                                  double.tryParse(_taxController.text.trim()) ??
                                  0,
                            ),
                          );
                        },
                        tone: _GlossyTone.navy,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _GlossyTone { silver, steel, navy }

class _GlossyButton extends StatelessWidget {
  const _GlossyButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = _GlossyTone.silver,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final _GlossyTone tone;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    final Color top;
    final Color mid;
    final Color bottom;
    final Color border;
    final Color text;

    switch (tone) {
      case _GlossyTone.navy:
        top = const Color(0xFF5A73BC);
        mid = const Color(0xFF3D5187);
        bottom = const Color(0xFF2D3E68);
        border = const Color(0xFF223153);
        text = Colors.white;
        break;
      case _GlossyTone.steel:
        top = const Color(0xFFDEE5F1);
        mid = const Color(0xFFABB7CD);
        bottom = const Color(0xFF8D9AB3);
        border = const Color(0xFF7D889E);
        text = const Color(0xFF21314B);
        break;
      case _GlossyTone.silver:
        top = const Color(0xFFF9FBFF);
        mid = const Color(0xFFE9EEF7);
        bottom = const Color(0xFFDCE4F1);
        border = const Color(0xFFBFC9DA);
        text = const Color(0xFF2A3954);
        break;
    }

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: enabled ? onPressed : null,
          child: Ink(
            height: 27,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [top, mid, bottom],
                stops: const [0, 0.5, 1],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x16000000),
                  blurRadius: 3,
                  offset: Offset(0, 1.5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation<Color>(text),
                    ),
                  )
                else if (icon != null)
                  Icon(icon, size: 11, color: text),
                if (icon != null || loading) const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: text,
                    fontSize: 10.6,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(color: Color(0x22000000), offset: Offset(0, 1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiveItemRowData {
  const _ReceiveItemRowData({
    required this.category,
    required this.itemName,
    required this.itemCode,
    required this.hsnSac,
    required this.qty,
    required this.unit,
    required this.rate,
    required this.discount,
    required this.tax,
  });

  final String category;
  final String itemName;
  final String itemCode;
  final String hsnSac;
  final double qty;
  final String unit;
  final double rate;
  final double discount;
  final double tax;
}
