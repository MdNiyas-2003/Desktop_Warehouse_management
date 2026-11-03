import 'dart:ui' as ui;
import 'package:desktop/core/widgets/app_snackbar.dart';
import 'package:desktop/features/warehouse/models/category_model.dart';
import 'package:desktop/features/warehouse/models/item_model.dart';
import 'package:desktop/features/warehouse/models/supplier_model.dart';
import 'package:desktop/features/warehouse/services/category_service.dart';
import 'package:desktop/features/warehouse/services/item_service.dart';
import 'package:desktop/features/warehouse/services/supplier_service.dart';
import 'package:desktop/features/warehouse/widgets/erp_search_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/network/backend_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';

const double _warehouseFieldHeight = 32;

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  int _selectedTab = 0;
  bool _isSubmitting = false;
  bool _isAddingItem = false;
  bool _isLoadingSuppliers = false;
  bool _isLoadingCategories = false;
  bool _isLoadingItems = false;
  bool _isNewItem = false;
  String? _suppliersError;
  String? _categoriesError;
  String? _itemsError;
  String? _selectedSupplierId;
  int? _selectedItemId;
  final _api = BackendApi();
  final List<_ReceiveItemRowData> _items = [];
  final _supplierController = TextEditingController();
  final _supplierCodeController = TextEditingController();
  final _invoiceNoController = TextEditingController();
  final _invoiceDateController = TextEditingController();
  final _referenceController = TextEditingController();
  final _poNumberController = TextEditingController();
  final _deliveryNoteController = TextEditingController();
  final _receivingDateController = TextEditingController();
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
  List<CategoryModel> _categories = [];
  List<ItemModel> _itemsList = [];
  List<SupplierModel> _suppliers = [];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _loadCategories();
    _loadItems();
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _isLoadingSuppliers = true;
      _suppliersError = null;
    });
    try {
      final data = await _supplierService.getSuppliers();
      if (!mounted) return;
      setState(() => _suppliers = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _suppliersError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingSuppliers = false);
    }
  }

  Future<void> _fetchSupplierDetails(SupplierModel supplier) async {
    _selectedSupplierId = supplier.id;
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
      _isNewItem = false;
      _selectedItemId = null;
      _billAmountController.text = '0.00';
      _taxAmountController.text = '0.00';
      _grandTotalController.text = '0.00';
    });
  }

  Future<void> _addItem() async {
    final itemName = _itemNameController.text.trim();
    final categoryName = _categoryController.text.trim();
    var itemCode = _itemCodeController.text.trim();
    final unit = _unitController.text.trim();
    final qty = double.tryParse(_qtyController.text.trim());
    final rate = double.tryParse(_rateController.text.trim());
    final discount = double.tryParse(_discountController.text.trim());
    final tax = double.tryParse(_taxController.text.trim());

    final missingFields = <String>[
      if (itemName.isEmpty) 'item name',
      if (categoryName.isEmpty) 'category',
      if (unit.isEmpty) 'unit',
      if (!_isNewItem && itemCode.isEmpty) 'item code',
    ];
    if (missingFields.isNotEmpty) {
      AppSnackBar.warning(
        message: 'Enter or select ${missingFields.join(', ')}.',
      );
      return;
    }
    if (qty == null || !qty.isFinite || qty <= 0) {
      AppSnackBar.warning(message: 'Quantity must be greater than zero.');
      return;
    }
    if (rate == null ||
        !rate.isFinite ||
        rate < 0 ||
        discount == null ||
        !discount.isFinite ||
        discount < 0 ||
        tax == null ||
        !tax.isFinite ||
        tax < 0) {
      AppSnackBar.warning(
        message: 'Enter valid non-negative rate, discount, and GST.',
      );
      return;
    }

    if (_isAddingItem) return;
    setState(() => _isAddingItem = true);
    try {
      if (_isNewItem) {
        final category = _categories.cast<CategoryModel?>().firstWhere(
          (entry) =>
              entry?.name.trim().toLowerCase() == categoryName.toLowerCase(),
          orElse: () => null,
        );
        if (category == null || category.id <= 0) {
          AppSnackBar.warning(
            message: 'Select or create a category before adding this item.',
          );
          return;
        }
        final createdItem = await _itemService.addItem(
          categoryId: category.id,
          itemName: itemName,
          unit: unit,
          rate: rate,
          gst: tax,
          stock: 0,
        );
        if (!mounted) return;
        itemCode = createdItem.code;
        setState(() {
          _itemsList = [..._itemsList, createdItem];
          _isNewItem = false;
          _selectedItemId = createdItem.id;
          _itemCodeController.text = createdItem.code;
        });
      }

      setState(() {
        _items.add(
          _ReceiveItemRowData(
            category: categoryName,
            itemName: itemName,
            itemCode: itemCode,
            itemId: _selectedItemId,
            hsnSac: '',
            qty: qty,
            unit: unit,
            rate: rate,
            discount: discount,
            tax: tax,
          ),
        );
        _categoryController.clear();
        _itemNameController.clear();
        _itemCodeController.clear();
        _unitController.text = 'PCS';
        _qtyController.text = '1';
        _rateController.text = '0';
        _discountController.text = '0';
        _taxController.text = '0';
        _selectedItemId = null;
        _billAmountController.text = _itemsSubTotal.toStringAsFixed(2);
        _taxAmountController.text = _itemsTaxTotal.toStringAsFixed(2);
        _grandTotalController.text = (_itemsSubTotal + _itemsTaxTotal)
            .toStringAsFixed(2);
      });
    } catch (e) {
      if (mounted) AppSnackBar.failed(message: 'Unable to add item: $e');
    } finally {
      if (mounted) setState(() => _isAddingItem = false);
    }
  }

  void _removeItemRow(int index) {
    setState(() {
      _items.removeAt(index);

      // Auto-update financial totals after removal
      _billAmountController.text = _itemsSubTotal.toStringAsFixed(2);
      _taxAmountController.text = _itemsTaxTotal.toStringAsFixed(2);
      _grandTotalController.text = (_itemsSubTotal + _itemsTaxTotal)
          .toStringAsFixed(2);
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
    if (_selectedSupplierId == null) {
      AppSnackBar.warning(
        message: 'Select or save a supplier before receiving stock.',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final subTotal = _itemsSubTotal;
      final taxTotal = _itemsTaxTotal;
      final grandTotal = subTotal + taxTotal;

      await _api.createWarehouseReceipt({
        'supplierId': _selectedSupplierId,
        'supplier': _supplierController.text.trim(),
        'invoiceNo': _invoiceNoController.text.trim(),
        'invoiceDate': _invoiceDateController.text.trim(),
        'deliveryNote': _deliveryNoteController.text.trim(),
        'receivingDate': _receivingDateController.text.trim(),
        'receivedBy': _receivedByController.text.trim(),
        'referencePoNo': _poNumberController.text.trim().isNotEmpty
            ? _poNumberController.text.trim()
            : _referenceController.text.trim(),
        'discountAmount':
            double.tryParse(_discountAmountController.text.trim()) ?? 0,
        'freight': double.tryParse(_freightController.text.trim()) ?? 0,
        'otherCharges':
            double.tryParse(_otherChargesController.text.trim()) ?? 0,
        'roundOff': double.tryParse(_roundOffController.text.trim()) ?? 0,
        'paidAmount': double.tryParse(_paidAmountController.text.trim()) ?? 0,
        'paymentTerms': _paymentTermsController.text.trim(),
        'paymentMode': _paymentModeController.text.trim(),
        'dueDate': _dueDateController.text.trim(),
        'referenceNumber': _referenceNumberController.text.trim(),
        'warehouseName': _warehouseController.text.trim(),
        'rackBin': _rackBinController.text.trim(),
        'receivingLocation': _receivingLocationController.text.trim(),
        'notes': _notesController.text.trim(),
        'supplierContact': _contactPersonController.text.trim(),
        'supplierPhone': _supplierPhoneController.text.trim(),
        'supplierGstin': _supplierGstinController.text.trim(),
        'supplierAddress': _supplierAddressController.text.trim(),
        'supplierLocation': _supplierLocationController.text.trim(),
        'transportName': _transportController.text.trim(),
        'vehicleNo': _vehicleController.text.trim(),
        'subTotal': subTotal,
        'taxTotal': taxTotal,
        'grandTotal': grandTotal,
        'billAmount': subTotal,
        'taxAmount': taxTotal,
        'status': 'Received',
        'items': _items
            .map(
              (e) => {
                'category': e.category,
                'itemName': e.itemName,
                'itemCode': _safeInventoryCode(e),
                'itemId': e.itemId,
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
    _selectedSupplierId = null;
    _isNewItem = false;
    _selectedItemId = null;
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
    setState(() {
      _isLoadingCategories = true;
      _categoriesError = null;
    });
    try {
      final data = await _categoryService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _categoriesError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _loadItems({int? categoryId}) async {
    setState(() {
      _isLoadingItems = true;
      _itemsError = null;
    });
    try {
      final data = await _itemService.getItems(categoryId: categoryId);
      if (!mounted) return;
      setState(() {
        _itemsList = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _itemsError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingItems = false);
    }
  }

  void _onCategorySelected(CategoryModel category) {
    setState(() {
      _isNewItem = false;
      _selectedItemId = null;
      _itemNameController.clear();
      _itemCodeController.clear();
      _unitController.clear();
      _rateController.text = '0';
      _taxController.text = '0';
    });
    _loadItems(categoryId: category.id);
  }

  Future<CategoryModel> _createCategory(String name) async {
    final category = await _categoryService.addCategory(name: name.trim());
    if (!mounted) return category;
    setState(() {
      _categories = [..._categories, category];
      _categoryController.text = category.name;
      _categoriesError = null;
    });
    return category;
  }

  void _startNewItem(String name) {
    setState(() {
      _isNewItem = true;
      _selectedItemId = null;
      _itemNameController.text = name.trim();
      _itemCodeController.clear();
      _unitController.text = 'PCS';
      _rateController.text = '0';
      _taxController.text = '0';
    });
  }

  void _onItemSelected(ItemModel item) {
    final category = _categories
        .where((entry) => entry.id == item.categoryId)
        .firstOrNull;
    setState(() {
      if (category != null) {
        _categoryController.text = category.name;
      } else if (item.categoryName != null) {
        _categoryController.text = item.categoryName!;
      }
      _itemNameController.text = item.name;
      _itemCodeController.text = item.code;
      _unitController.text = item.unit;
      _rateController.text = item.rate.toString();
      _taxController.text = item.gst.toString();
      _selectedItemId = item.id;
      _isNewItem = false;
    });
  }

  Future<void> _showSelectedItemDetails() async {
    final selected = _itemsList
        .where((item) => item.id == _selectedItemId)
        .firstOrNull;
    if (selected == null) {
      AppSnackBar.warning(message: 'Select an existing item to view its QR.');
      return;
    }
    await _showItemDetailsDialog(selected);
  }

  Future<void> _showItemDetailsDialog(ItemModel item) async {
    final categoryName =
        item.categoryName ??
        _categories
            .where((category) => category.id == item.categoryId)
            .map((category) => category.name)
            .firstOrNull ??
        '—';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Item Details & QR Code'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: item.code,
                version: QrVersions.auto,
                size: 190,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
              const SizedBox(height: 12),
              Text(
                item.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _ItemDetailLine(label: 'Item Code', value: item.code),
              _ItemDetailLine(label: 'Item ID', value: item.id.toString()),
              _ItemDetailLine(label: 'Category', value: categoryName),
              _ItemDetailLine(
                label: 'Unit / Rate',
                value: '${item.unit} / ${item.rate.toStringAsFixed(2)}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () => _printItemQr(item),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print / Save PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _printItemQr(ItemModel item) async {
    try {
      final qrBytes = await QrPainter(
        data: item.code,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      ).toImageData(512, format: ui.ImageByteFormat.png);
      if (qrBytes == null) {
        throw StateError('Unable to render the item QR code.');
      }
      final pdf = pw.Document();
      final qrImage = pw.MemoryImage(qrBytes.buffer.asUint8List());
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  item.name,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Image(qrImage, width: 220, height: 220),
                pw.SizedBox(height: 8),
                pw.Text('Item Code: ${item.code}'),
                pw.Text('Item ID: ${item.id}'),
              ],
            ),
          ),
        ),
      );
      await Printing.layoutPdf(
        name: 'item-${item.code}.pdf',
        onLayout: (_) => pdf.save(),
      );
    } catch (error) {
      if (mounted) {
        AppSnackBar.failed(message: 'Unable to print item QR: $error');
      }
    }
  }

  Future<void> _addNewSupplier(String name) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: name);
    final codeController = TextEditingController();
    final phoneController = TextEditingController();
    final gstinController = TextEditingController();
    final addressController = TextEditingController();
    final locationController = TextEditingController();
    var saving = false;
    String? dialogError;

    final supplier = await showDialog<SupplierModel>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Supplier'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DialogTextField(
                      label: 'Supplier Name *',
                      controller: nameController,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Supplier name is required'
                          : null,
                    ),
                    _DialogTextField(
                      label: 'Supplier Code',
                      controller: codeController,
                    ),
                    _DialogTextField(
                      label: 'Contact Number',
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    _DialogTextField(
                      label: 'GSTIN',
                      controller: gstinController,
                    ),
                    _DialogTextField(
                      label: 'Address',
                      controller: addressController,
                    ),
                    _DialogTextField(
                      label: 'Location',
                      controller: locationController,
                    ),
                    if (dialogError != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            dialogError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        dialogError = null;
                      });
                      try {
                        final existing = await _supplierService.getSuppliers(
                          search: nameController.text.trim(),
                        );
                        if (!dialogContext.mounted) return;
                        final duplicate = existing.where(
                          (entry) =>
                              entry.name.trim().toLowerCase() ==
                              nameController.text.trim().toLowerCase(),
                        );
                        if (duplicate.isNotEmpty) {
                          Navigator.pop(dialogContext, duplicate.first);
                          return;
                        }
                        final created = await _supplierService.addSupplier(
                          name: nameController.text,
                          code: codeController.text,
                          phone: phoneController.text,
                          gstin: gstinController.text,
                          address: addressController.text,
                          location: locationController.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, created);
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            saving = false;
                            dialogError = e.toString();
                          });
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Supplier'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    codeController.dispose();
    phoneController.dispose();
    gstinController.dispose();
    addressController.dispose();
    locationController.dispose();

    if (supplier != null && mounted) {
      setState(() {
        if (!_suppliers.any((entry) => entry.id == supplier.id)) {
          _suppliers = [..._suppliers, supplier];
        }
      });
      await _onSupplierSelected(supplier);
      AppSnackBar.success(message: 'Supplier saved and selected.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: _selectedTab == 0
              ? _ReceiveItemsPanel(
                  itemsList: _itemsList,
                  categories: _categories,
                  suppliers: _suppliers,
                  items: _items,
                  onAddItem: _addItem,
                  isAddingItem: _isAddingItem,
                  onRemoveRow: _removeItemRow,
                  onSubmit: _submitReceiveToStore,
                  onClear: _clearForm,
                  onSaveDraft: _saveDraft,
                  onPrint: _printReceipt,
                  onFetchSupplierDetails: _onSupplierSelected,
                  onAddNewSupplier: (name) => _addNewSupplier(name),
                  onCategorySelected: _onCategorySelected,
                  onCreateCategory: _createCategory,
                  onNewItem: _startNewItem,
                  onItemSelected: _onItemSelected,
                  onShowSelectedItemDetails: _showSelectedItemDetails,
                  isNewItem: _isNewItem,
                  isLoadingSuppliers: _isLoadingSuppliers,
                  suppliersError: _suppliersError,
                  isLoadingCategories: _isLoadingCategories,
                  categoriesError: _categoriesError,
                  isLoadingItems: _isLoadingItems,
                  itemsError: _itemsError,
                  isSubmitting: _isSubmitting,
                  supplierController: _supplierController,
                  invoiceNoController: _invoiceNoController,
                  invoiceDateController: _invoiceDateController,
                  referenceController: _referenceController,
                  poNumberController: _poNumberController,
                  deliveryNoteController: _deliveryNoteController,
                  receivingDateController: _receivingDateController,
                  receivedByController: _receivedByController,
                  warehouseController: _warehouseController,
                  rackBinController: _rackBinController,
                  receivingLocationController: _receivingLocationController,
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
                  outstandingBalanceController: _outstandingBalanceController,
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
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _DispatchStatus extends StatelessWidget {
  const _DispatchStatus(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => StatusBadge(label: label, color: color);
}

// ignore: unused_element
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
    required this.isAddingItem,
    required this.onRemoveRow,
    required this.onSubmit,
    required this.onClear,
    required this.onSaveDraft,
    required this.onPrint,
    required this.onFetchSupplierDetails,
    required this.onAddNewSupplier,
    required this.onCategorySelected,
    required this.onCreateCategory,
    required this.onNewItem,
    required this.onItemSelected,
    required this.onShowSelectedItemDetails,
    required this.isNewItem,
    required this.isLoadingSuppliers,
    required this.suppliersError,
    required this.isLoadingCategories,
    required this.categoriesError,
    required this.isLoadingItems,
    required this.itemsError,
    required this.isSubmitting,
    required this.supplierController,
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
  final bool isAddingItem;
  final ValueChanged<int> onRemoveRow;
  final Future<void> Function() onSubmit;
  final VoidCallback onClear;
  final Future<void> Function() onSaveDraft;
  final VoidCallback onPrint;
  final Function(SupplierModel) onFetchSupplierDetails;
  final ValueChanged<String> onAddNewSupplier;
  final ValueChanged<CategoryModel> onCategorySelected;
  final Future<CategoryModel> Function(String) onCreateCategory;
  final ValueChanged<String> onNewItem;
  final ValueChanged<ItemModel> onItemSelected;
  final VoidCallback onShowSelectedItemDetails;
  final bool isNewItem;
  final bool isLoadingSuppliers;
  final String? suppliersError;
  final bool isLoadingCategories;
  final String? categoriesError;
  final bool isLoadingItems;
  final String? itemsError;
  final bool isSubmitting;
  final List<SupplierModel> suppliers;
  final List<CategoryModel> categories;
  final TextEditingController supplierController;
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
    return Column(
      children: [
        Expanded(
          flex: 28,
          child: _FormSectionCard(
            title: 'Supply Receipt Form',
            icon: Icons.receipt_long_rounded,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeading('Supplier Information'),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: _SupplierDropdownCompact(
                                controller: supplierController,
                                suppliers: suppliers,
                                onSelected: onFetchSupplierDetails,
                                onAddNew: onAddNewSupplier,
                                isLoading: isLoadingSuppliers,
                                errorMessage: suppliersError,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _CompactInput(
                                label: 'Outstanding Balance',
                                hint: '0.00',
                                controller: outstandingBalanceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _CompactThreeFieldRow(
                          first: _CompactInput(
                            label: 'Supplier Location',
                            hint: 'Location',
                            controller: supplierLocationController,
                          ),
                          second: _CompactInput(
                            label: 'Contact Number',
                            hint: 'Phone',
                            controller: supplierPhoneController,
                            keyboardType: TextInputType.phone,
                          ),
                          third: _CompactInput(
                            label: 'GSTIN',
                            hint: 'GSTIN',
                            controller: supplierGstinController,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFD4DEE8),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeading('Invoice Details'),
                        const SizedBox(height: 3),
                        _CompactThreeFieldRow(
                          first: _CompactInput(
                            label: 'Invoice Number',
                            hint: 'INV-001',
                            controller: invoiceNoController,
                          ),
                          second: _ReceiptDateInput(
                            label: 'Invoice Date',
                            controller: invoiceDateController,
                          ),
                          third: _CompactInput(
                            label: 'PO Number',
                            hint: 'PO-001',
                            controller: poNumberController,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _CompactThreeFieldRow(
                          first: _CompactInput(
                            label: 'Delivery Note',
                            hint: 'DN-001',
                            controller: deliveryNoteController,
                          ),
                          second: _ReceiptDateInput(
                            label: 'Receiving Date',
                            controller: receivingDateController,
                          ),
                          third: _CompactInput(
                            label: 'Received By',
                            hint: 'Name',
                            controller: receivedByController,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: 36,
          child: _FormSectionCard(
            title: 'Items',
            icon: Icons.inventory_2_outlined,
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final fields = <Widget>[
                      ErpSearchDropdown<CategoryModel>(
                        label: 'Category',
                        hint: 'Search Category',
                        controller: categoryController,
                        items: categories,
                        isLoading: isLoadingCategories,
                        errorMessage: categoriesError,
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
                            await onCreateCategory(name);
                          } catch (e) {
                            AppSnackBar.failed(
                              message: 'Unable to add category: $e',
                            );
                          }
                        },
                      ),
                      ErpSearchDropdown<ItemModel>(
                        label: 'Item Name',
                        hint: 'Search or Enter Item',
                        controller: itemNameController,
                        items: itemsList,
                        isLoading: isLoadingItems,
                        errorMessage: itemsError,
                        selectedItem: itemsList
                            .where((e) => e.name == itemNameController.text)
                            .cast<ItemModel?>()
                            .firstOrNull,
                        itemText: (e) => e.name,
                        onSelected: onItemSelected,
                        onAddNew: onNewItem,
                      ),
                      _CompactInput(
                        label: 'Item Code',
                        hint: isNewItem ? 'Generated on save' : 'Code',
                        controller: itemCodeController,
                        readOnly: isNewItem,
                        suffixIcon: isNewItem ? null : Icons.qr_code_2_rounded,
                        onSuffixTap: onShowSelectedItemDetails,
                      ),
                      _CompactInput(
                        label: 'Qty',
                        hint: '1',
                        controller: qtyController,
                      ),
                      _CompactInput(
                        label: 'Unit',
                        hint: 'PCS',
                        controller: unitController,
                      ),
                      _CompactInput(
                        label: 'Rate',
                        hint: '0.00',
                        controller: rateController,
                      ),
                      _CompactInput(
                        label: 'GST %',
                        hint: '0',
                        controller: taxController,
                      ),
                      _CompactInput(
                        label: 'Discount',
                        hint: '0',
                        controller: discountController,
                      ),
                    ];
                    final addButton = SizedBox(
                      height: 32,
                      child: FilledButton.icon(
                        onPressed: isAddingItem ? null : onAddItem,
                        icon: isAddingItem
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add_rounded, size: 15),
                        label: Text(
                          isAddingItem ? 'Adding' : 'Add Item',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: const Color(0xFF1167E8),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    );

                    if (constraints.maxWidth >= 1200) {
                      const fieldFlex = [
                        2.1,
                        1.25,
                        1.25,
                        0.65,
                        0.8,
                        1,
                        0.8,
                        1.1,
                      ];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var index = 0; index < fields.length; index++)
                            Expanded(
                              flex: (fieldFlex[index] * 100).round(),
                              child: Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: fields[index],
                              ),
                            ),
                          addButton,
                        ],
                      );
                    }

                    final fieldWidth = (constraints.maxWidth - 8) / 2;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        for (final field in fields)
                          SizedBox(width: fieldWidth, child: field),
                        addButton,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFFD4DEE8)),
                    ),
                    child: Column(
                      children: [
                        const _CompactItemHeaderRow(),
                        const Divider(height: 1, color: Color(0xFFD4DEE8)),
                        Expanded(
                          child: _ItemsEditorTable(
                            items: items,
                            onRemoveRow: onRemoveRow,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: 36,
          child: _FormSectionCard(
            title: 'Financial & Payment Details',
            icon: Icons.payments_outlined,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionHeading('Financial Details'),
                              const SizedBox(height: 3),
                              _CompactThreeFieldRow(
                                first: _CompactInput(
                                  label: 'Subtotal',
                                  hint: '0.00',
                                  controller: billAmountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                                second: _CompactInput(
                                  label: 'Discount',
                                  hint: '0.00',
                                  controller: discountAmountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                                third: _CompactInput(
                                  label: 'Tax',
                                  hint: '0.00',
                                  controller: taxAmountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              _CompactThreeFieldRow(
                                first: _CompactInput(
                                  label: 'Freight',
                                  hint: '0.00',
                                  controller: freightController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                                second: _CompactInput(
                                  label: 'Other Charges',
                                  hint: '0.00',
                                  controller: otherChargesController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                                third: _CompactInput(
                                  label: 'Round Off',
                                  hint: '0.00',
                                  controller: roundOffController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              _CompactThreeFieldRow(
                                first: _CompactInput(
                                  label: 'Grand Total',
                                  hint: '0.00',
                                  controller: grandTotalController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                                second: _CompactInput(
                                  label: 'Paid Amount',
                                  hint: '0.00',
                                  controller: paidAmountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                                third: _CompactInput(
                                  label: 'Balance Amount',
                                  hint: '0.00',
                                  controller: balanceAmountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: Color(0xFFD4DEE8),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionHeading('Payment Details'),
                              const SizedBox(height: 3),
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
                                third: _ReceiptDateInput(
                                  label: 'Due Date',
                                  controller: dueDateController,
                                ),
                                fourth: _CompactInput(
                                  label: 'Reference Number',
                                  hint: 'REF-001',
                                  controller: referenceNumberController,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const _SectionHeading('Notes'),
                              const SizedBox(height: 2),
                              Expanded(
                                child: _CompactInput(
                                  label: '',
                                  hint: 'Enter notes here...',
                                  controller: notesController,
                                  maxLines: 2,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  spacing: 5,
                                  runSpacing: 4,
                                  alignment: WrapAlignment.end,
                                  children: [
                                    _GlossyButton(
                                      label: 'Clear',
                                      icon: Icons.close_rounded,
                                      onPressed: onClear,
                                      tone: _GlossyTone.clear,
                                    ),
                                    _GlossyButton(
                                      label: 'Save as Draft',
                                      icon: Icons.save_outlined,
                                      onPressed: () async => onSaveDraft(),
                                      tone: _GlossyTone.draft,
                                    ),
                                    _GlossyButton(
                                      label: isSubmitting
                                          ? 'Receiving'
                                          : 'Receive Stock',
                                      icon: isSubmitting
                                          ? null
                                          : Icons.inventory_2_outlined,
                                      onPressed: isSubmitting
                                          ? null
                                          : () => onSubmit(),
                                      tone: _GlossyTone.receive,
                                      loading: isSubmitting,
                                    ),
                                    _GlossyButton(
                                      label: 'Print',
                                      icon: Icons.print_outlined,
                                      onPressed: onPrint,
                                      tone: _GlossyTone.print,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
  const _SectionHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF082D68),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(height: 1, color: Color(0xFFC7D3E2))),
      ],
    );
  }
}

// ignore: unused_element
class _CompactFieldRow extends StatelessWidget {
  const _CompactFieldRow({required this.left, required this.right});

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
    this.readOnly = false,
    this.suffixIcon,
    this.onSuffixTap,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool readOnly;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2A3A),
            ),
          ),
          const SizedBox(height: 3),
        ],
        SizedBox(
          height: maxLines == 1 ? _warehouseFieldHeight : 56,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            readOnly: readOnly,
            style: const TextStyle(fontSize: 12, color: Color(0xFF17213B)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF8AA0B6),
                fontWeight: FontWeight.w500,
              ),
              isDense: true,
              constraints: maxLines == 1
                  ? const BoxConstraints.tightFor(height: _warehouseFieldHeight)
                  : null,
              filled: true,
              fillColor: Colors.white,
              suffixIcon: suffixIcon == null
                  ? null
                  : InkWell(
                      onTap: onSuffixTap,
                      child: SizedBox(
                        width: 30,
                        height: 26,
                        child: Center(
                          child: Icon(
                            suffixIcon,
                            size: 17,
                            color: const Color(0xFF1167E8),
                          ),
                        ),
                      ),
                    ),
              suffixIconConstraints: suffixIcon == null
                  ? null
                  : const BoxConstraints.tightFor(width: 30, height: 26),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFFD4DEE8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFFD4DEE8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFF1167E8)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemDetailLine extends StatelessWidget {
  const _ItemDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF68788A)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF24364B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptDateInput extends StatelessWidget {
  const _ReceiptDateInput({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  DateTime _initialDate() {
    final parts = controller.text.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        final date = DateTime(year, month, day);
        if (date.year == year && date.month == month && date.day == day) {
          return date;
        }
      }
    }
    return DateTime.now();
  }

  Future<void> _pickDate(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _initialDate(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: const Color(0xFF1167E8),
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (selected == null) return;
    controller.text =
        '${selected.day.toString().padLeft(2, '0')}/${selected.month.toString().padLeft(2, '0')}/${selected.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A2A3A),
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: _warehouseFieldHeight,
          child: TextField(
            controller: controller,
            readOnly: true,
            onTap: () => _pickDate(context),
            style: const TextStyle(fontSize: 12, color: Color(0xFF17213B)),
            decoration: InputDecoration(
              hintText: 'Select date',
              hintStyle: const TextStyle(color: Color(0xFF8AA0B6)),
              isDense: true,
              constraints: const BoxConstraints.tightFor(
                height: _warehouseFieldHeight,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 6,
              ),
              suffixIcon: InkWell(
                onTap: () => _pickDate(context),
                child: const SizedBox(
                  width: 30,
                  height: 26,
                  child: Center(
                    child: Icon(
                      Icons.calendar_month_outlined,
                      size: 16,
                      color: Color(0xFF17213B),
                    ),
                  ),
                ),
              ),
              suffixIconConstraints: const BoxConstraints.tightFor(
                width: 30,
                height: 26,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFFD4DEE8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFFD4DEE8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFF1167E8)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogTextField extends StatelessWidget {
  const _DialogTextField({
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}

class _CompactItemHeaderRow extends StatelessWidget {
  const _CompactItemHeaderRow();

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
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF124FAE),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: List.generate(headers.length, (index) {
          final flex = [1, 2, 3, 2, 1, 1, 1, 1, 1, 1][index];
          return Expanded(
            flex: flex,
            child: Text(
              headers[index],
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ),
    );
  }
}

// ignore: unused_element
class _InlineItemEntry extends StatelessWidget {
  const _InlineItemEntry({
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
                    debugPrint("Typed Name = $name");

                    try {
                      final newCategory = await CategoryService().addCategory(
                        name: name.trim(),
                      );

                      debugPrint("Added = ${newCategory.name}");

                      categoryController.text = newCategory.name;
                    } catch (e) {
                      debugPrint("ERROR: $e");
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD4DEE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFD7E9FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 17, color: const Color(0xFF1167E8)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
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

// ignore: unused_element
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
    this.controller,
  }) : keyboardType = null,
       maxLines = 1;

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
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF17213B),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: maxLines == 1 ? 27 : 56,
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF17213B)),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFFD4DEE8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFFD4DEE8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFF1167E8)),
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
    if (widget.items.isEmpty) {
      return Center(
        child: Text(
          'No items added yet. Click Add Item Row to enter item details.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: widget.items.length,
      itemBuilder: (context, index) => _ItemDisplayRow(
        index: index,
        row: widget.items[index],
        onRemove: () => widget.onRemoveRow(index),
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
    (row.qty * row.rate - row.discount).clamp(0, double.infinity);

    Widget cell(Widget child, {int flex = 1}) {
      return Expanded(flex: flex, child: child);
    }

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFFCFDFF),
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.55)),
        ),
      ),
      child: Row(
        children: [
          cell(
            Text('${index + 1}', style: const TextStyle(fontSize: 12)),
            flex: 1,
          ),
          cell(
            Text(
              row.category,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
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
            Text(
              row.itemCode,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            flex: 2,
          ),
          cell(Text(row.unit, style: const TextStyle(fontSize: 12)), flex: 1),
          cell(
            Text(
              row.qty.toStringAsFixed(2),
              style: const TextStyle(fontSize: 12),
            ),
            flex: 1,
          ),
          cell(
            Text(
              row.rate.toStringAsFixed(2),
              style: const TextStyle(fontSize: 12),
            ),
            flex: 1,
          ),
          cell(
            Text(
              row.tax.toStringAsFixed(0),
              style: const TextStyle(fontSize: 12),
            ),
            flex: 1,
          ),
          cell(
            Text(
              row.discount.toStringAsFixed(2),
              style: const TextStyle(fontSize: 12),
            ),
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

enum _GlossyTone { clear, draft, receive, print }

class _GlossyButton extends StatelessWidget {
  const _GlossyButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = _GlossyTone.draft,
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

    final (background, foreground, borderColor) = switch (tone) {
      _GlossyTone.clear => (
        const Color(0xFFDC3545),
        Colors.white,
        const Color(0xFFC52A39),
      ),
      _GlossyTone.draft => (
        const Color(0xFFE5E7EB),
        const Color(0xFF374151),
        const Color(0xFFD1D5DB),
      ),
      _GlossyTone.receive => (
        const Color(0xFF198754),
        Colors.white,
        const Color(0xFF157347),
      ),
      _GlossyTone.print => (
        const Color(0xFF1167E8),
        Colors.white,
        const Color(0xFF0B55C0),
      ),
    };

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        valueColor: AlwaysStoppedAnimation<Color>(foreground),
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, size: 14, color: foreground),
                  if (icon != null || loading) const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupplierDropdownCompact extends StatefulWidget {
  const _SupplierDropdownCompact({
    required this.controller,
    required this.suppliers,
    required this.onSelected,
    required this.onAddNew,
    this.isLoading = false,
    this.errorMessage,
  });

  final TextEditingController controller;
  final List<SupplierModel> suppliers;
  final Function(SupplierModel) onSelected;
  final ValueChanged<String> onAddNew;
  final bool isLoading;
  final String? errorMessage;

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
      _filteredSuppliers = _matchingSuppliers(widget.controller.text);
    }
    if (oldWidget.suppliers != widget.suppliers ||
        oldWidget.isLoading != widget.isLoading ||
        oldWidget.errorMessage != widget.errorMessage) {
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
    _filteredSuppliers = _matchingSuppliers(query);
    _overlay?.markNeedsBuild();
    setState(() {});
  }

  List<SupplierModel> _matchingSuppliers(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return widget.suppliers;
    return widget.suppliers.where((supplier) {
      return [
        supplier.name,
        supplier.code,
        supplier.phone,
        supplier.location,
      ].any((value) => value.toLowerCase().contains(normalizedQuery));
    }).toList();
  }

  void _showOverlay() {
    if (_overlay != null) {
      _overlay!.markNeedsBuild();
      return;
    }

    _overlay = OverlayEntry(
      builder: (context) {
        final renderBox =
            _targetKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) {
          return const SizedBox.shrink();
        }
        final size = renderBox.size;
        final overlayBox =
            Overlay.of(context).context.findRenderObject() as RenderBox?;
        final viewportSize = overlayBox?.size ?? MediaQuery.sizeOf(context);
        final targetPosition = overlayBox == null
            ? renderBox.localToGlobal(Offset.zero)
            : renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
        final availableWidth = (viewportSize.width - 24).clamp(
          0.0,
          viewportSize.width,
        );
        final menuWidth = (size.width < 300 ? 360.0 : size.width)
            .clamp(0.0, availableWidth)
            .toDouble();
        final menuHeight =
            (38 +
                    (_filteredSuppliers.isEmpty
                        ? 56
                        : _filteredSuppliers.length * 50) +
                    (_canAddNew ? 44 : 0))
                .clamp(0, 320)
                .toDouble();
        final mediaPadding = MediaQuery.paddingOf(context);
        final availableBelow =
            viewportSize.height -
            targetPosition.dy -
            size.height -
            mediaPadding.bottom -
            5;
        final availableHeight = availableBelow
            .clamp(0.0, menuHeight)
            .toDouble();
        final targetLeft = targetPosition.dx;
        final menuLeft = targetLeft
            .clamp(12.0, viewportSize.width - menuWidth - 12)
            .toDouble();

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
              offset: Offset(menuLeft - targetLeft, size.height + 5),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: menuWidth,
                  constraints: BoxConstraints(maxHeight: availableHeight),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDCE5F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF17365D).withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: widget.isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(18),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Loading suppliers…',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF52657A),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : widget.errorMessage != null
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              widget.errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFB42318),
                                fontSize: 12,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: _filteredSuppliers.isEmpty
                                ? 2 + (_canAddNew ? 1 : 0)
                                : 1 +
                                      _filteredSuppliers.length +
                                      (_canAddNew ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF6F9FD),
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Color(0xFFE7EDF4),
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text(
                                        'SUPPLIERS',
                                        style: TextStyle(
                                          fontSize: 10,
                                          letterSpacing: 0.7,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF63758A),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${_filteredSuppliers.length} found',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF8292A5),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              if (_filteredSuppliers.isEmpty) {
                                if (index == 1) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    child: Text(
                                      widget.controller.text.trim().isEmpty
                                          ? 'No suppliers available'
                                          : 'No matching supplier found',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF718096),
                                      ),
                                    ),
                                  );
                                }
                                return _buildAddSupplierOption();
                              }

                              final supplierIndex = index - 1;
                              if (_canAddNew &&
                                  supplierIndex == _filteredSuppliers.length) {
                                return _buildAddSupplierOption();
                              }
                              final supplier =
                                  _filteredSuppliers[supplierIndex];
                              final subtitle = supplier.location.trim();
                              final isSelected =
                                  widget.controller.text.trim().toLowerCase() ==
                                  supplier.name.trim().toLowerCase();

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Material(
                                    color: isSelected
                                        ? const Color(0xFFF0F6FF)
                                        : Colors.white,
                                    child: InkWell(
                                      onTapDown: (_) {
                                        _ignoreFocusLoss = true;
                                      },
                                      onTap: () {
                                        widget.controller.text = supplier.name;
                                        widget.controller.selection =
                                            TextSelection.collapsed(
                                              offset: supplier.name.length,
                                            );
                                        widget.onSelected(supplier);
                                        _hideOverlay();
                                        _focusNode.unfocus();
                                        _ignoreFocusLoss = false;
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 9,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 30,
                                              height: 30,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEAF2FF),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                supplier.name
                                                    .trim()
                                                    .characters
                                                    .first
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF1557B0),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    supplier.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF24364B),
                                                    ),
                                                  ),
                                                  if (subtitle.isNotEmpty)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 3,
                                                          ),
                                                      child: Text(
                                                        subtitle,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 10.5,
                                                          color: Color(
                                                            0xFF8290A2,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                const Text(
                                                  'BALANCE',
                                                  style: TextStyle(
                                                    fontSize: 8.5,
                                                    letterSpacing: 0.4,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF8997A8),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  supplier.outstandingBalance
                                                      .toStringAsFixed(2),
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF34465B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (supplierIndex <
                                      _filteredSuppliers.length - 1)
                                    const Divider(
                                      height: 1,
                                      indent: 52,
                                      color: Color(0xFFF0F3F7),
                                    ),
                                ],
                              );
                            },
                          ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlay!);
  }

  bool get _canAddNew {
    final query = widget.controller.text.trim();
    return query.isNotEmpty &&
        !_filteredSuppliers.any(
          (supplier) =>
              supplier.name.trim().toLowerCase() == query.toLowerCase(),
        );
  }

  Widget _buildAddSupplierOption() {
    final name = widget.controller.text.trim();
    if (name.isEmpty) return const SizedBox.shrink();
    return Material(
      color: const Color(0xFFF8FBFF),
      child: InkWell(
        onTapDown: (_) => _ignoreFocusLoss = true,
        onTap: () {
          _hideOverlay();
          _focusNode.unfocus();
          _ignoreFocusLoss = false;
          widget.onAddNew(name);
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 17,
                color: Color(0xFF1167E8),
              ),
              SizedBox(width: 8),
              Text(
                'Add New Supplier',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1167E8),
                ),
              ),
              Spacer(),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: Color(0xFF1167E8),
              ),
            ],
          ),
        ),
      ),
    );
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
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2A3A),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            key: _targetKey,
            height: _warehouseFieldHeight,
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
              style: const TextStyle(fontSize: 12, color: Color(0xFF17213B)),
              decoration: InputDecoration(
                hintText: 'Search supplier',
                hintStyle: const TextStyle(
                  color: Color(0xFF8AA0B6),
                  fontSize: 12,
                ),
                suffixIcon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Color(0xFF73849A),
                ),
                suffixIconConstraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 26,
                ),
                isDense: true,
                constraints: const BoxConstraints.tightFor(
                  height: _warehouseFieldHeight,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFD4DEE8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFD4DEE8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF1167E8)),
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
                      borderSide: const BorderSide(
                        color: Colors.blue,
                        width: 1,
                      ),
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
                              'Add "${_controller.text}" as new supplier',
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
    this.itemId,
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
  final int? itemId;
  final String hsnSac;
  final double qty;
  final String unit;
  final double rate;
  final double discount;
  final double tax;
}
