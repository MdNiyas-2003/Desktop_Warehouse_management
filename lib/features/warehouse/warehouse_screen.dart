import 'package:desktop/core/widgets/app_snackbar.dart';
import 'package:desktop/features/warehouse/models/category_model.dart';
import 'package:desktop/features/warehouse/models/item_model.dart';
import 'package:desktop/features/warehouse/models/supplier_model.dart';
import 'package:desktop/features/warehouse/services/category_service.dart';
import 'package:desktop/features/warehouse/services/item_service.dart';
import 'package:desktop/features/warehouse/services/supplier_service.dart';
import 'package:desktop/features/warehouse/widgets/erp_search_dropdown.dart';
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
  final _supplierCodeController = TextEditingController();
  final _invoiceNoController = TextEditingController();
  final _invoiceDateController = TextEditingController(text: '15/07/2026');
  final _referenceController = TextEditingController();
  final _poNumberController = TextEditingController();
  final _deliveryNoteController = TextEditingController();
  final _receivingDateController = TextEditingController(text: '15/07/2026');
  final _receivedByController = TextEditingController();
  final _warehouseController = TextEditingController();
  final _rackBinController = TextEditingController();
  final _receivingLocationController = TextEditingController();
  final _billAmountController = TextEditingController(text: '0.00');
  final _taxAmountController = TextEditingController(text: '0.00');
  final _discountAmountController = TextEditingController(text: '0.00');
  final _freightController = TextEditingController(text: '0.00');
  final _otherChargesController = TextEditingController(text: '0.00');
  final _roundOffController = TextEditingController(text: '0.00');
  final _grandTotalController = TextEditingController(text: '0.00');
  final _paidAmountController = TextEditingController(text: '0.00');
  final _balanceAmountController = TextEditingController(text: '0.00');
  final _paymentTermsController = TextEditingController();
  final _paymentModeController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _referenceNumberController = TextEditingController();
  final _notesController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _supplierPhoneController = TextEditingController();
  final _supplierGstinController = TextEditingController();
  final _supplierAddressController = TextEditingController();
  final _supplierLocationController = TextEditingController();
  final _outstandingBalanceController = TextEditingController(text: '0.00');
  final _transportController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _itemCodeController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _rateController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');
  final _taxController = TextEditingController(text: '0');
  final _unitController = TextEditingController();
  final CategoryService _categoryService = CategoryService();
  final SupplierService _supplierService = SupplierService();
  final ItemService _itemService = ItemService();
int _dropdownRefreshKey = 0;
  List<CategoryModel> _categories = [];
  List<ItemModel> _itemsList = [];
  List<SupplierModel> _suppliers = [];
  SupplierModel? _selectedSupplier;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _loadCategories();
    _loadItems();
  }

  Future<void> _loadSuppliers() async {
    try {
      final data = await _supplierService.getSuppliers();
      print("Supplier Count: ${data.length}");
      setState(() => _suppliers = data);
    } catch (e) {
      print('Error loading suppliers: $e');
    }
  }

  Future<void> _fetchSupplierDetails(SupplierModel supplier) async {
    _supplierController.text = supplier.name;
    _supplierCodeController.text = supplier.code;
    _supplierPhoneController.text = supplier.phone;
    _supplierGstinController.text = supplier.gstin;
    _supplierAddressController.text = supplier.address;
    _supplierLocationController.text = supplier.location;
    _outstandingBalanceController.text = supplier.outstandingBalance
        .toStringAsFixed(2);
  }

  Future<void> _onSupplierSelected(SupplierModel supplier) async {
    _selectedSupplier = supplier;
    await _fetchSupplierDetails(supplier);
    setState(() {
      _items.clear();
      _itemNameController.clear();
      _itemCodeController.clear();
      _categoryController.clear();
      _unitController.clear();
      _qtyController.text = '1';
      _rateController.text = '0';
      _discountController.text = '0';
      _taxController.text = '0';
      _billAmountController.text = '0.00';
      _taxAmountController.text = '0.00';
      _grandTotalController.text = '0.00';
    });
  }

  void _addItem() {
    print("Item Name: ${_itemNameController.text}");
    print("Category: ${_categoryController.text}");

    if (_itemNameController.text.trim().isEmpty) {
      print("Item name is empty");
      return;
    }

    setState(() {
      _items.add(
        _ReceiveItemRowData(
          category: _categoryController.text.trim(),
          itemName: _itemNameController.text.trim(),
          itemCode: _itemCodeController.text.trim(),
          hsnSac: '',
          qty: double.tryParse(_qtyController.text) ?? 0,
          unit: _unitController.text.trim(),
          rate: double.tryParse(_rateController.text) ?? 0,
          discount: double.tryParse(_discountController.text) ?? 0,
          tax: double.tryParse(_taxController.text) ?? 0,
        ),
      );

      print("Items Count: ${_items.length}");
      
      // Clear form fields after adding
      _categoryController.clear();
      _itemNameController.clear();
      _itemCodeController.clear();
      _unitController.clear();
      _qtyController.text = '1';
      _rateController.text = '0';
      _discountController.text = '0';
      _taxController.text = '0';
      
      // Auto-update financial totals
      _billAmountController.text = _itemsSubTotal.toStringAsFixed(2);
      _taxAmountController.text = _itemsTaxTotal.toStringAsFixed(2);
      _grandTotalController.text = (_itemsSubTotal + _itemsTaxTotal).toStringAsFixed(2);
    });
  }

  void _removeItemRow(int index) {
    setState(() {
      _items.removeAt(index);
      
      // Auto-update financial totals after removal
      _billAmountController.text = _itemsSubTotal.toStringAsFixed(2);
      _taxAmountController.text = _itemsTaxTotal.toStringAsFixed(2);
      _grandTotalController.text = (_itemsSubTotal + _itemsTaxTotal).toStringAsFixed(2);
    });
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
      AppSnackBar.warning(message: 'Add at least one item before submit.');
      return;
    }
    if (_supplierController.text.trim().isEmpty ||
        _invoiceNoController.text.trim().isEmpty) {
      AppSnackBar.warning(message: 'Supplier and Invoice No. are required.');
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

    _clearForm();

      AppSnackBar.success(
        message: 'Invoice saved to PostgreSQL and stock quantity updated.',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.failed(message: 'Submit failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

 void _clearForm() {
  _supplierController.clear();
  _supplierCodeController.clear();
  _invoiceNoController.clear();
  _invoiceDateController.text = '';
  _referenceController.clear();
  _poNumberController.clear();
  _deliveryNoteController.clear();
  _receivingDateController.text = '';
  _receivedByController.clear();

  _warehouseController.clear();
  _rackBinController.clear();
  _receivingLocationController.clear();

  _billAmountController.text = '0.00';
  _taxAmountController.text = '0.00';
  _discountAmountController.text = '0.00';
  _freightController.text = '0.00';
  _otherChargesController.text = '0.00';
  _roundOffController.text = '0.00';
  _grandTotalController.text = '0.00';
  _paidAmountController.text = '0.00';
  _balanceAmountController.text = '0.00';

  _paymentTermsController.clear();
  _paymentModeController.clear();
  _dueDateController.clear();
  _referenceNumberController.clear();

  _notesController.clear();

  _contactPersonController.clear();
  _supplierPhoneController.clear();
  _supplierGstinController.clear();
  _supplierAddressController.clear();
  _supplierLocationController.clear();
  _outstandingBalanceController.text = '0.00';

  _transportController.clear();
  _vehicleController.clear();

  _categoryController.clear();
  _itemNameController.clear();
  _itemCodeController.clear();
  _qtyController.text = '1';
  _unitController.clear();
  _rateController.text = '0';
  _discountController.text = '0';
  _taxController.text = '0';

  setState(() {
    _items.clear();
    _dropdownRefreshKey++;
  });
}
  Future<void> _saveDraft() async {
    AppSnackBar.success(message: 'Draft saved locally.');
  }

  void _printReceipt() {
    AppSnackBar.success(message: 'Print preview opened.');
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _supplierCodeController.dispose();
    _invoiceNoController.dispose();
    _invoiceDateController.dispose();
    _referenceController.dispose();
    _poNumberController.dispose();
    _deliveryNoteController.dispose();
    _receivingDateController.dispose();
    _receivedByController.dispose();
    _warehouseController.dispose();
    _rackBinController.dispose();
    _receivingLocationController.dispose();
    _billAmountController.dispose();
    _taxAmountController.dispose();
    _discountAmountController.dispose();
    _freightController.dispose();
    _otherChargesController.dispose();
    _roundOffController.dispose();
    _grandTotalController.dispose();
    _paidAmountController.dispose();
    _balanceAmountController.dispose();
    _paymentTermsController.dispose();
    _paymentModeController.dispose();
    _dueDateController.dispose();
    _referenceNumberController.dispose();
    _notesController.dispose();
    _contactPersonController.dispose();
    _supplierPhoneController.dispose();
    _supplierGstinController.dispose();
    _supplierAddressController.dispose();
    _supplierLocationController.dispose();
    _outstandingBalanceController.dispose();
    _transportController.dispose();
    _vehicleController.dispose();
    _categoryController.dispose();
    _itemNameController.dispose();
    _itemCodeController.dispose();
    _qtyController.dispose();
    _unitController.dispose();
    _rateController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await _categoryService.getCategories();

      print("Category Count: ${data.length}");
      print(data);

      setState(() {
        _categories = data;
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _loadItems({int? categoryId}) async {
    try {
      final data = await _itemService.getItems(categoryId: categoryId);

      print("Item Count : ${data.length}");

      setState(() {
        _itemsList = data;
      });
    } catch (e) {
      print('Error loading items: $e');
    }
  }

  void _onCategorySelected(CategoryModel category) {
    _loadItems(categoryId: category.id);
    _itemNameController.clear();
    _itemCodeController.clear();
    _unitController.clear();
    _rateController.text = '0';
    _taxController.text = '0';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('warehouse'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  onSelected: (value) =>
                      setState(() => _selectedTab = value),
                ),
                const SizedBox(height: 12),
                if (_selectedTab == 0)
                  _ReceiveItemsPanel(
                        itemsList: _itemsList,
                        categories: _categories,
                        suppliers: _suppliers,
                        items: _items,
                        onAddItem: _addItem,
                        onRemoveRow: _removeItemRow,
                        onSubmit: _submitReceiveToStore,
                        onClear: _clearForm,
                        onSaveDraft: _saveDraft,
                        onPrint: _printReceipt,
                        onFetchSupplierDetails: _onSupplierSelected,
                        onCategorySelected: _onCategorySelected,
                        isSubmitting: _isSubmitting,
                        supplierController: _supplierController,
                        supplierCodeController: _supplierCodeController,
                        invoiceNoController: _invoiceNoController,
                        invoiceDateController: _invoiceDateController,
                        referenceController: _referenceController,
                        poNumberController: _poNumberController,
                        deliveryNoteController: _deliveryNoteController,
                        receivingDateController: _receivingDateController,
                        receivedByController: _receivedByController,
                        warehouseController: _warehouseController,
                        rackBinController: _rackBinController,
                        receivingLocationController:
                            _receivingLocationController,
                        billAmountController: _billAmountController,
                        taxAmountController: _taxAmountController,
                        discountAmountController: _discountAmountController,
                        freightController: _freightController,
                        otherChargesController: _otherChargesController,
                        roundOffController: _roundOffController,
                        grandTotalController: _grandTotalController,
                        paidAmountController: _paidAmountController,
                        balanceAmountController: _balanceAmountController,
                        paymentTermsController: _paymentTermsController,
                        paymentModeController: _paymentModeController,
                        dueDateController: _dueDateController,
                        referenceNumberController: _referenceNumberController,
                        notesController: _notesController,
                        contactPersonController: _contactPersonController,
                        supplierPhoneController: _supplierPhoneController,
                        supplierGstinController: _supplierGstinController,
                        supplierAddressController: _supplierAddressController,
                        supplierLocationController: _supplierLocationController,
                        outstandingBalanceController:
                            _outstandingBalanceController,
                        transportController: _transportController,
                        vehicleController: _vehicleController,
                        categoryController: _categoryController,
                        itemNameController: _itemNameController,
                        itemCodeController: _itemCodeController,
                        qtyController: _qtyController,
                        unitController: _unitController,
                        rateController: _rateController,
                        discountController: _discountController,
                        taxController: _taxController,
                      )
                  ],
                ),
              ),
            ],
      ));
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
    required this.categories,
    required this.suppliers,
    required this.items,
    required this.onAddItem,
    required this.onRemoveRow,
    required this.onSubmit,
    required this.onClear,
    required this.onSaveDraft,
    required this.onPrint,
    required this.onFetchSupplierDetails,
    required this.onCategorySelected,
    required this.isSubmitting,
    required this.supplierController,
    required this.supplierCodeController,
    required this.invoiceNoController,
    required this.invoiceDateController,
    required this.referenceController,
    required this.poNumberController,
    required this.deliveryNoteController,
    required this.receivingDateController,
    required this.receivedByController,
    required this.warehouseController,
    required this.rackBinController,
    required this.receivingLocationController,
    required this.billAmountController,
    required this.taxAmountController,
    required this.discountAmountController,
    required this.freightController,
    required this.otherChargesController,
    required this.roundOffController,
    required this.grandTotalController,
    required this.paidAmountController,
    required this.balanceAmountController,
    required this.paymentTermsController,
    required this.paymentModeController,
    required this.dueDateController,
    required this.referenceNumberController,
    required this.notesController,
    required this.contactPersonController,
    required this.supplierPhoneController,
    required this.supplierGstinController,
    required this.supplierAddressController,
    required this.supplierLocationController,
    required this.outstandingBalanceController,
    required this.transportController,
    required this.vehicleController,
    required this.categoryController,
    required this.itemNameController,
    required this.itemCodeController,
    required this.qtyController,
    required this.unitController,
    required this.rateController,
    required this.discountController,
    required this.taxController,
    required this.itemsList,
  });

  final List<_ReceiveItemRowData> items;
  final VoidCallback onAddItem;
  final ValueChanged<int> onRemoveRow;
  final Future<void> Function() onSubmit;
  final VoidCallback onClear;
  final Future<void> Function() onSaveDraft;
  final VoidCallback onPrint;
  final Function(SupplierModel) onFetchSupplierDetails;
  final ValueChanged<CategoryModel> onCategorySelected;
  final bool isSubmitting;
  final List<SupplierModel> suppliers;
  final List<CategoryModel> categories;
  final TextEditingController supplierController;
  final TextEditingController supplierCodeController;
  final TextEditingController invoiceNoController;
  final TextEditingController invoiceDateController;
  final TextEditingController referenceController;
  final TextEditingController poNumberController;
  final TextEditingController deliveryNoteController;
  final TextEditingController receivingDateController;
  final TextEditingController receivedByController;
  final TextEditingController warehouseController;
  final TextEditingController rackBinController;
  final TextEditingController receivingLocationController;
  final TextEditingController billAmountController;
  final TextEditingController taxAmountController;
  final TextEditingController discountAmountController;
  final TextEditingController freightController;
  final TextEditingController otherChargesController;
  final TextEditingController roundOffController;
  final TextEditingController grandTotalController;
  final TextEditingController paidAmountController;
  final TextEditingController balanceAmountController;
  final TextEditingController paymentTermsController;
  final TextEditingController paymentModeController;
  final TextEditingController dueDateController;
  final TextEditingController referenceNumberController;
  final TextEditingController notesController;
  final TextEditingController contactPersonController;
  final TextEditingController supplierPhoneController;
  final TextEditingController supplierGstinController;
  final TextEditingController supplierAddressController;
  final TextEditingController supplierLocationController;
  final TextEditingController outstandingBalanceController;
  final TextEditingController transportController;
  final TextEditingController vehicleController;
  final TextEditingController categoryController;
  final TextEditingController itemNameController;
  final TextEditingController itemCodeController;
  final TextEditingController qtyController;
  final TextEditingController unitController;
  final TextEditingController rateController;
  final TextEditingController discountController;
  final TextEditingController taxController;
  final List<ItemModel> itemsList;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card 1: Supply Receipt Form (Supplier, Invoice, Warehouse Details)
          _FormSectionCard(
            title: 'Supply Receipt Form',
            icon: Icons.receipt_long_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeading('Supplier Information'),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: _SupplierDropdownCompact(
  controller: supplierController,
  suppliers: suppliers,
  onSelected: onFetchSupplierDetails,
),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CompactInput(
                        label: 'Supplier Code',
                        hint: 'Code',
                        controller: supplierCodeController,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CompactInput(
                        label: 'Supplier Location',
                        hint: 'Location',
                        controller: supplierLocationController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: _CompactInput(
                        label: 'Outstanding Balance',
                        hint: '0.00',
                        controller: outstandingBalanceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CompactInput(
                        label: 'GSTIN',
                        hint: 'GSTIN',
                        controller: supplierGstinController,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CompactInput(
                        label: 'Contact Number',
                        hint: 'Phone',
                        controller: supplierPhoneController,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SectionHeading('Invoice Details'),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: _CompactInput(
                        label: 'Invoice Number',
                        hint: 'INV-001',
                        controller: invoiceNoController,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CompactInput(
                        label: 'Invoice Date',
                        hint: '15/07/2026',
                        controller: invoiceDateController,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CompactInput(
                        label: 'PO Number',
                        hint: 'PO-001',
                        controller: poNumberController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: _CompactInput(
                        label: 'Delivery Note',
                        hint: 'DN-001',
                        controller: deliveryNoteController,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CompactInput(
                        label: 'Receiving Date',
                        hint: '15/07/2026',
                        controller: receivingDateController,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CompactInput(
                        label: 'Received By',
                        hint: 'Name',
                        controller: receivedByController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SectionHeading('Warehouse Details'),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: _CompactInput(
                        label: 'Warehouse',
                        hint: 'Main Warehouse',
                        controller: warehouseController,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CompactInput(
                        label: 'Rack/Bin',
                        hint: 'A-01',
                        controller: rackBinController,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CompactInput(
                        label: 'Receiving Location',
                        hint: 'Receiving Point',
                        controller: receivingLocationController,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Card 2: Items Section (Entry Form + Items Table)
          _FormSectionCard(
            title: 'Items',
            icon: Icons.inventory_2_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item Entry Form
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Category, Item Name, Item Code
                     Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Flexible(
      flex: 1,
      child: ErpSearchDropdown<CategoryModel>(

        label: 'Category',
        hint: 'Search Category',
        items: categories,
        selectedItem: categories
            .where((e) => e.name == categoryController.text)
            .cast<CategoryModel?>()
            .firstOrNull,
        itemText: (e) => e.name,
        onSelected: (category) {
          categoryController.text = category.name;
          onCategorySelected(category);
        },
        onAddNew: (name) async {
          try {
            final newCategory = await CategoryService().addCategory(
              name: name.trim(),
            );
            categoryController.text = newCategory.name;
          } catch (e) {
            debugPrint("Category Error: $e");
          }
        },
      ),
    ),

    const SizedBox(width: 12),

    Flexible(
      flex: 1,
      child: ErpSearchDropdown<ItemModel>(
        label: 'Item Name',
        hint: 'Search or Enter Item',
        items: itemsList,
        selectedItem: itemsList
            .where((e) => e.name == itemNameController.text)
            .cast<ItemModel?>()
            .firstOrNull,
        itemText: (e) => e.name,
        onSelected: (item) {
          itemNameController.text = item.name;
          itemCodeController.text = item.code;
          unitController.text = item.unit;
          rateController.text = item.rate.toString();
          taxController.text = item.gst.toString();
        },
        onAddNew: (name) {
          itemNameController.text = name;
          itemCodeController.text = name
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
        },
      ),
    ),

    const SizedBox(width: 12),

    Flexible(
      flex: 1,
      child: _CompactInput(
        label: 'Item Code',
        hint: 'Code',
        controller: itemCodeController,
      ),
    ),
  ],
),
                      const SizedBox(height: 10),
                      // Row 2: Qty, Unit, Rate
                      Row(
                        children: [
                          Expanded(
                            child: _CompactInput(
                              label: 'Qty',
                              hint: '1',
                              controller: qtyController,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CompactInput(
                              label: 'Unit',
                              hint: 'PCS',
                              controller: unitController,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CompactInput(
                              label: 'Rate',
                              hint: '0.00',
                              controller: rateController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Row 3: GST %, Discount, Add Item button
                      Row(
                        children: [
                          Expanded(
                            child: _CompactInput(
                              label: 'GST %',
                              hint: '0',
                              controller: taxController,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CompactInput(
                              label: 'Discount',
                              hint: '0',
                              controller: discountController,
                            ),
                          ),
                          const SizedBox(width: 175),
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: FilledButton.icon(
                              onPressed: onAddItem,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add Item'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Items Table
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    children: [
                      _CompactItemHeaderRow(),
                      const Divider(height: 1),
                      _ItemsEditorTable(items: items, onRemoveRow: onRemoveRow),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Card 3: Financial & Payment Details
          _FormSectionCard(
            title: 'Financial & Payment Details',
            icon: Icons.payments_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
_SectionHeading('Financial Details'),
const SizedBox(height: 8),

_CompactThreeFieldRow(
  first: _CompactInput(
    label: 'Subtotal',
    hint: '0.00',
    controller: billAmountController,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
  ),
  second: _CompactInput(
    label: 'Discount',
    hint: '0.00',
    controller: discountAmountController,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
  ),
  third: _CompactInput(
    label: 'Tax',
    hint: '0.00',
    controller: taxAmountController,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
  ),
),

const SizedBox(height: 8),

_CompactThreeFieldRow(
  first: _CompactInput(
    label: 'Freight',
    hint: '0.00',
    controller: freightController,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
  ),
  second: _CompactInput(
    label: 'Other Charges',
    hint: '0.00',
    controller: otherChargesController,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
  ),
  third: _CompactInput(
    label: 'Round Off',
    hint: '0.00',
    controller: roundOffController,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
  ),
),

const SizedBox(height: 8),

_CompactThreeFieldRow(
  first: _CompactInput(
    label: 'Grand Total',
    hint: '0.00',
    controller: grandTotalController,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
  ),
  second: _CompactInput(
    label: 'Paid Amount',
    hint: '0.00',
    controller: paidAmountController,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
  ),
  third: _CompactInput(
    label: 'Balance Amount',
    hint: '0.00',
    controller: balanceAmountController,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
  ),
),
                const SizedBox(height: 12),
              _SectionHeading('Payment Details'),
const SizedBox(height: 8),

_CompactFourFieldRow(
  first: _CompactInput(
    label: 'Payment Terms',
    hint: 'Credit 30 Days',
    controller: paymentTermsController,
  ),
  second: _CompactInput(
    label: 'Payment Mode',
    hint: 'Cash / Card / Bank',
    controller: paymentModeController,
  ),
  third: _CompactInput(
    label: 'Due Date',
    hint: '15/07/2026',
    controller: dueDateController,
  ),
  fourth: _CompactInput(
    label: 'Reference Number',
    hint: 'REF-001',
    controller: referenceNumberController,
  ),
),
                const SizedBox(height: 12),
                _SectionHeading('Notes'),
                const SizedBox(height: 8),
                _CompactInput(
                  label: 'Notes',
                  hint: 'Enter notes here...',
                  controller: notesController,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // _GlossyButton(
                      //   label: 'Clear',
                      //   icon: Icons.clear_all_rounded,
                      //   onPressed: onClear,
                      //   tone: _GlossyTone.silver,
                      // ),
                      // _GlossyButton(
                      //   label: 'Save Draft',
                      //   icon: Icons.save_alt_rounded,
                      //   onPressed: () async => onSaveDraft(),
                      //   tone: _GlossyTone.steel,
                      // ),
                      _GlossyButton(
                        label: isSubmitting ? 'Receiving' : 'Receive Stock',
                        icon: isSubmitting ? null : Icons.inventory_2_outlined,
                        onPressed: isSubmitting ? null : () => onSubmit(),
                        tone: _GlossyTone.navy,
                        loading: isSubmitting,
                      ),
                      _GlossyButton(
                        label: 'Print',
                        icon: Icons.print_outlined,
                        onPressed: onPrint,
                        tone: _GlossyTone.steel,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _CompactThreeFieldRow extends StatelessWidget {
  const _CompactThreeFieldRow({
    required this.first,
    required this.second,
    required this.third,
  });

  final Widget first;
  final Widget second;
  final Widget third;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: 10),
        Expanded(child: second),
        const SizedBox(width: 10),
        Expanded(child: third),
      ],
    );
  }
}
class _CompactFourFieldRow extends StatelessWidget {
  const _CompactFourFieldRow({
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
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    );
  }
}

class _CompactFieldRow extends StatelessWidget {
  const _CompactFieldRow({required this.left, required this.right, super.key});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }
}

class _CompactInput extends StatelessWidget {
  const _CompactInput({
    required this.label,
    required this.hint,
    this.controller,
    this.keyboardType,
    this.maxLines = 1,
    super.key,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.blue, width: 1.0),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactItemHeaderRow extends StatelessWidget {
  const _CompactItemHeaderRow({super.key});

  @override
  Widget build(BuildContext context) {
    final headers = [
      '#',
      'Category',
      'Item Name',
      'Item Code',
      'Unit',
      'Qty',
      'Rate',
      'GST %',
      'Disc.',
      'Action',
    ];
    return Row(
      children: List.generate(headers.length, (index) {
        final flex = [1, 2, 3, 2, 1, 1, 1, 1, 1, 1][index];
        return Expanded(
          flex: flex,
          child: Text(
            headers[index],
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.text,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }),
    );
  }
}

class _InlineItemEntry extends StatelessWidget {
  const _InlineItemEntry({
    super.key,
    required this.categories,
    required this.categoryController,
    required this.itemNameController,
    required this.itemCodeController,
    required this.qtyController,
    required this.unitController,
    required this.rateController,
    required this.discountController,
    required this.taxController,
    required this.onAddItem,
    required this.itemsList,
  });

  final TextEditingController categoryController;
  final TextEditingController itemNameController;
  final TextEditingController itemCodeController;
  final TextEditingController qtyController;
  final TextEditingController unitController;
  final TextEditingController rateController;
  final TextEditingController discountController;
  final TextEditingController taxController;

  final VoidCallback onAddItem;
  final List<CategoryModel> categories;
  final List<ItemModel> itemsList;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFF),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ErpSearchDropdown<CategoryModel>(
                  label: 'Category',
                  hint: 'Search Category',

                  items: categories,

                  selectedItem: categories
                      .where((e) => e.name == categoryController.text)
                      .cast<CategoryModel?>()
                      .firstOrNull,

                  itemText: (e) => e.name,

                  onSelected: (category) {
                    categoryController.text = category.name;
                  },

                  onAddNew: (name) async {
                    print("Typed Name = $name");

                    try {
                      final newCategory = await CategoryService().addCategory(
                        name: name.trim(),
                      );

                      print("Added = ${newCategory.name}");

                      categoryController.text = newCategory.name;
                    } catch (e) {
                      print("ERROR: $e");
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ErpSearchDropdown<ItemModel>(
                  label: 'Item Name',
                  hint: 'Search or Enter Item',
                  items: itemsList,
                  selectedItem: itemsList
                      .where((e) => e.name == itemNameController.text)
                      .cast<ItemModel?>()
                      .firstOrNull,
                  itemText: (e) => e.name,
                  onSelected: (item) {
                    itemNameController.text = item.name;
                    itemCodeController.text = item.code;
                    unitController.text = item.unit;
                    rateController.text = item.rate.toString();
                    taxController.text = item.gst.toString();
                  },
                  onAddNew: (name) {
                    itemNameController.text = name;
                    itemCodeController.text = name.toLowerCase().replaceAll(
                      RegExp(r'[^a-z0-9]+'),
                      '_',
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LabeledInput(
                  label: 'Item Code',
                  hint: 'Code',
                  controller: itemCodeController,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LabeledInput(
                  label: 'Unit',
                  hint: 'PCS',
                  controller: unitController,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _LabeledInput(
                  label: 'Qty',
                  hint: '1',
                  controller: qtyController,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LabeledInput(
                  label: 'Rate',
                  hint: '0.00',
                  controller: rateController,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LabeledInput(
                  label: 'GST %',
                  hint: '0',
                  controller: taxController,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LabeledInput(
                  label: 'Discount',
                  hint: '0',
                  controller: discountController,
                ),
              ),
            ],
          ),
        ],
      ),
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 1.5),
              ),
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
    final total = (row.qty * row.rate - row.discount).clamp(0, double.infinity);

    Widget cell(Widget child, {int flex = 1}) {
      return Expanded(flex: flex, child: child);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFFCFDFF),
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.55)),
        ),
      ),
      child: Row(
        children: [
          cell(Text('${index + 1}', style: const TextStyle(fontSize: 12)), flex: 1),
          cell(
            Text(row.category, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
            flex: 2,
          ),
          cell(
            Text(
              row.itemName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            flex: 3,
          ),
          cell(
            Text(row.itemCode, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
            flex: 2,
          ),
          cell(Text(row.unit, style: const TextStyle(fontSize: 12)), flex: 1),
          cell(
            Text(row.qty.toStringAsFixed(2), style: const TextStyle(fontSize: 12)),
            flex: 1,
          ),
          cell(
            Text(row.rate.toStringAsFixed(2), style: const TextStyle(fontSize: 12)),
            flex: 1,
          ),
          cell(
            Text(row.tax.toStringAsFixed(0), style: const TextStyle(fontSize: 12)),
            flex: 1,
          ),
          cell(
            Text(row.discount.toStringAsFixed(2), style: const TextStyle(fontSize: 12)),
            flex: 1,
          ),
          cell(
            IconButton(
              onPressed: onRemove,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
                size: 16,
              ),
              tooltip: 'Delete row',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
            flex: 1,
          ),
        ],
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
  top = const Color(0xFF2F5CC8);
  mid = const Color(0xFF2F5CC8);
  bottom = const Color(0xFF2F5CC8);
  border = const Color(0xFF254DAA);
  text = Colors.white;
  break;
     case _GlossyTone.steel:
  top = const Color(0xFFF8FAFC);
  mid = const Color(0xFFF8FAFC);
  bottom = const Color(0xFFF8FAFC);
  border = const Color(0xFFD1D5DB);
  text = const Color(0xFF374151);
  break;
      case _GlossyTone.silver:
        top = const Color.fromARGB(255, 28, 186, 117);
        mid = const Color.fromARGB(255, 15, 196, 120);
        bottom = const Color.fromARGB(255, 17, 160, 48);
        border = const Color.fromARGB(255, 25, 206, 91);
        text = const Color.fromARGB(255, 185, 187, 190);
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
            height: 37,
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

class _SupplierDropdownCompact extends StatefulWidget {
  const _SupplierDropdownCompact({
    super.key,
    required this.controller,
    required this.suppliers,
    required this.onSelected,
  });

  final TextEditingController controller;
  final List<SupplierModel> suppliers;
  final Function(SupplierModel) onSelected;

  @override
  State<_SupplierDropdownCompact> createState() =>
      _SupplierDropdownCompactState();
}

class _SupplierDropdownCompactState extends State<_SupplierDropdownCompact> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _targetKey = GlobalKey();
  OverlayEntry? _overlay;
  late FocusNode _focusNode;
  bool _ignoreFocusLoss = false;
  List<SupplierModel> _filteredSuppliers = [];

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _filteredSuppliers = widget.suppliers;
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _filterSuppliers(widget.controller.text);
        _showOverlay();
      } else if (!_ignoreFocusLoss) {
        _hideOverlay();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _SupplierDropdownCompact oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suppliers != widget.suppliers) {
      _filteredSuppliers = widget.suppliers;
      _overlay?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _hideOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  void _filterSuppliers(String query) {
    _filteredSuppliers = query.trim().isEmpty
        ? widget.suppliers
        : widget.suppliers
            .where((s) => s.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
    _overlay?.markNeedsBuild();
    setState(() {});
  }

  void _showOverlay() {
    if (_overlay != null) {
      _overlay!.markNeedsBuild();
      return;
    }

    _overlay = OverlayEntry(builder: (context) {
      final renderBox = _targetKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) {
        return const SizedBox.shrink();
      }
      final size = renderBox.size;

      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideOverlay,
              child: const SizedBox(),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 10),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: size.width,
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _filteredSuppliers.isEmpty
                    ? widget.controller.text.trim().isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'No suppliers found',
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          )
                        : InkWell(
                            onTapDown: (_) {
                              _ignoreFocusLoss = true;
                            },
                            onTap: () {
                              final typedName = widget.controller.text.trim();
                              setState(() {
                                widget.controller.text = typedName;
                                widget.controller.selection = TextSelection.collapsed(
                                  offset: typedName.length,
                                );
                              });
                              widget.onSelected(
                                SupplierModel(
                                  name: typedName,
                                  code: '',
                                  phone: '',
                                  gstin: '',
                                  address: '',
                                  location: '',
                                  outstandingBalance: 0.0,
                                ),
                              );
                              _hideOverlay();
                              _focusNode.unfocus();
                              _ignoreFocusLoss = false;
                            },
                            child: Container(
                              width: size.width,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              child: Text(
                                'Add new supplier "${widget.controller.text.trim()}"',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _filteredSuppliers.length,
                        itemBuilder: (context, index) {
                          final supplier = _filteredSuppliers[index];
                          final subtitleText = [supplier.code, supplier.location]
                              .where((value) => value.trim().isNotEmpty)
                              .join(' · ');
                          return InkWell(
                            onTapDown: (_) {
                              _ignoreFocusLoss = true;
                            },
                            onTap: () {
                              setState(() {
                                widget.controller.text = supplier.name;
                                widget.controller.selection = TextSelection.collapsed(
                                  offset: supplier.name.length,
                                );
                              });
                              widget.onSelected(supplier);
                              _hideOverlay();
                              _focusNode.unfocus();
                              _ignoreFocusLoss = false;
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          supplier.name,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        if (subtitleText.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              subtitleText,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    supplier.outstandingBalance.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      );
    });

    Overlay.of(context).insert(_overlay!);
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Supplier Name *',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            key: _targetKey,
            height: 42,
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onTap: () {
                _filterSuppliers(widget.controller.text);
                _showOverlay();
              },
              onChanged: (value) {
                _filterSuppliers(value);
              },
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search supplier',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: Colors.grey.shade300,
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.blue, width: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierDropdown extends StatefulWidget {
  const _SupplierDropdown({
    required this.controller,
    required this.suppliers,
    required this.selectedName,
    required this.onSelected,
  });
  final TextEditingController controller;
  final List<SupplierModel> suppliers;
  final String selectedName;
  final Function(SupplierModel) onSelected;

  @override
  State<_SupplierDropdown> createState() => _SupplierDropdownState();
}

class _SupplierDropdownState extends State<_SupplierDropdown> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  List<SupplierModel> _filteredSuppliers = [];
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _filteredSuppliers = widget.suppliers;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _filterSuppliers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSuppliers = widget.suppliers;
        _showDropdown = false;
      } else {
        _filteredSuppliers = widget.suppliers
            .where((s) => s.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
        _showDropdown = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supplier Name *',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Focus(
          onFocusChange: (hasFocus) {
            setState(
              () => _showDropdown = hasFocus && _controller.text.isNotEmpty,
            );
          },
          child: Column(
            children: [
              SizedBox(
                height: 42,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: _filterSuppliers,
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                    hintText: 'Search or add supplier',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                        width: 0.8,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Colors.blue, width: 1),
                    ),
                  ),
                ),
              ),
              if (_showDropdown && _filteredSuppliers.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 0.8),
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredSuppliers.length,
                    itemBuilder: (context, index) {
                      final supplier = _filteredSuppliers[index];
                      return ListTile(
                        title: Text(
                          supplier.name,
                          style: const TextStyle(fontSize: 11),
                        ),
                        subtitle: Text(
                          supplier.code,
                          style: const TextStyle(fontSize: 9),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        dense: true,
                        onTap: () {
                          _controller.text = supplier.name;
                          widget.onSelected(supplier);
                          setState(() => _showDropdown = false);
                          _focusNode.unfocus();
                        },
                      );
                    },
                  ),
                ),
              if (_showDropdown &&
                  _filteredSuppliers.isEmpty &&
                  _controller.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: GestureDetector(
                    onTap: () {
                      AppSnackBar.warning(
                        message: 'Add new supplier feature coming soon',
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        color: const Color(0xFFF0F8FF),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add, size: 14, color: Colors.blue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Add \"${_controller.text}\" as new supplier',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
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
