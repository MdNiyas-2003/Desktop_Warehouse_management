import 'dart:io';

import 'package:desktop/features/accounts/payment_entry/models/payment_model.dart';
import 'package:desktop/features/accounts/payment_entry/services/payment_service.dart';
import 'package:desktop/features/supplier/model/supplier_model.dart';
import 'package:desktop/features/supplier/services/supplier_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdfLib;
import 'package:pdf/widgets.dart' as pw;

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/premium_widgets.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final NumberFormat _moneyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  bool _loading = true;
  bool _exporting = false;
  int _activeTab = 0;
  int _rowsPerPage = 10;
  int _page = 0;

  List<CustomerModel> _customers = [];
  List<SupplierModel> _suppliers = [];
  List<CustomerInvoiceModel> _customerInvoices = [];
  List<SupplierInvoiceModel> _supplierInvoices = [];
  List<PaymentModel> _payments = [];

  CustomerModel? _selectedCustomer;
  SupplierModel? _selectedSupplier;
  DateTime? _fromDate;
  DateTime? _toDate;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLedgerData();
  }

  Future<void> _loadLedgerData() async {
    setState(() {
      _loading = true;
      _page = 0;
    });

    try {
      final customers = await CustomerService.getCustomers();
      final suppliers = await SupplierService.getSuppliers();
      final payments = await PaymentService.getPayments();

      setState(() {
        _customers = customers;
        _suppliers = suppliers;
        _payments = payments;
        _selectedCustomer = customers.isNotEmpty ? customers.first : null;
        _selectedSupplier = suppliers.isNotEmpty ? suppliers.first : null;
      });

      if (_selectedCustomer != null) {
        await _loadCustomerInvoices(_selectedCustomer!.id);
      }

      if (_selectedSupplier != null) {
        await _loadSupplierInvoices(_selectedSupplier!.name);
      }
    } catch (e) {
      AppSnackBar.failed(message: 'Failed to load ledger data: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadCustomerInvoices(String customerId) async {
    setState(() {
      _loading = true;
      _page = 0;
    });
    try {
      final invoices = await CustomerService.getCustomerInvoices(customerId);
      setState(() {
        _customerInvoices = invoices;
      });
    } catch (e) {
      AppSnackBar.failed(message: 'Failed to load customer invoices: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadSupplierInvoices(String supplierName) async {
    setState(() {
      _loading = true;
      _page = 0;
    });
    try {
      final invoices = await SupplierService.getSupplierInvoices(supplierName);
      setState(() {
        _supplierInvoices = invoices;
      });
    } catch (e) {
      AppSnackBar.failed(message: 'Failed to load supplier invoices: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  List<LedgerEntry> get _customerLedgerEntries {
    final customerId = _selectedCustomer?.id;
    if (customerId == null) return [];

    final invoiceEntries = _customerInvoices.map((invoice) {
      final date = invoice.invoiceDate ?? DateTime.now();
      return LedgerEntry(
        date: date,
        invoiceNo: invoice.invoiceNo,
        paymentMethod: 'Sales Invoice',
        chequeInfo: '-',
        debit: invoice.amount,
        credit: 0,
        note: invoice.status,
      );
    });

    final paymentEntries = _payments
        .where((payment) => payment.customerId == customerId)
        .map((payment) {
      final method = payment.paymentMode.toLowerCase();
      final chequeInfo = method.contains('cheque')
          ? '${payment.chequeNo?.trim() ?? ''}${payment.chequeDate != null ? ' / ${_dateFormat.format(payment.chequeDate!)}' : ''}'.trim()
          : '-';
      return LedgerEntry(
        date: payment.paymentDate,
        invoiceNo: payment.invoiceNo ?? '',
        paymentMethod: method.contains('cash')
            ? 'Cash Receipt'
            : method.contains('cheque')
                ? 'Cheque Receipt'
                : method.contains('bank')
                    ? 'Bank Receipt'
                    : 'Payment',
        chequeInfo: chequeInfo.isNotEmpty ? chequeInfo : '-',
        debit: 0,
        credit: payment.amount,
        note: payment.status,
      );
    });

    return _buildBalanceLedger([...invoiceEntries, ...paymentEntries], isCustomer: true);
  }

  List<LedgerEntry> get _supplierLedgerEntries {
    final selectedSupplier = _selectedSupplier;
    if (selectedSupplier == null) return [];

    final openingInvoices = _supplierInvoices.map((invoice) {
      final date = invoice.invoiceDate ?? DateTime.now();
      return LedgerEntry(
        date: date,
        invoiceNo: invoice.invoiceNo,
        paymentMethod: 'Purchase Invoice',
        chequeInfo: '-',
        debit: 0,
        credit: invoice.grandTotal,
        note: '',
      );
    });

    final paymentEntries = _payments
        .where((payment) => payment.supplierId != null && _supplierInvoices.any((invoice) => invoice.id == payment.supplierId))
        .map((payment) {
      final method = payment.paymentMode.toLowerCase();
      final chequeInfo = method.contains('cheque')
          ? '${payment.chequeNo?.trim() ?? ''}${payment.chequeDate != null ? ' / ${_dateFormat.format(payment.chequeDate!)}' : ''}'.trim()
          : '-';
      return LedgerEntry(
        date: payment.paymentDate,
        invoiceNo: payment.invoiceNo ?? '',
        paymentMethod: method.contains('cash')
            ? 'Cash Payment'
            : method.contains('cheque')
                ? 'Cheque Payment'
                : method.contains('bank')
                    ? 'Bank Payment'
                    : 'Payment',
        chequeInfo: chequeInfo.isNotEmpty ? chequeInfo : '-',
        debit: payment.amount,
        credit: 0,
        note: payment.status,
      );
    });

    return _buildBalanceLedger([...openingInvoices, ...paymentEntries], isCustomer: false);
  }

  List<LedgerEntry> _buildBalanceLedger(List<LedgerEntry> rawEntries, {required bool isCustomer}) {
    final sorted = [...rawEntries]
      ..sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        return b.debit.compareTo(a.debit);
      });

    double balance = 0;
    return sorted.map((entry) {
      balance += isCustomer ? entry.debit - entry.credit : entry.credit - entry.debit;
      return entry.copyWith(balance: balance);
    }).toList();
  }

  List<LedgerEntry> _filterEntries(List<LedgerEntry> entries) {
    final query = _searchQuery.trim().toLowerCase();
    return entries.where((entry) {
      final matchesQuery = query.isEmpty ||
          entry.invoiceNo.toLowerCase().contains(query) ||
          entry.paymentMethod.toLowerCase().contains(query) ||
          entry.note.toLowerCase().contains(query);

      final matchesFrom = _fromDate == null || !entry.date.isBefore(_fromDate!);
      final matchesTo = _toDate == null || !entry.date.isAfter(_toDate!);
      return matchesQuery && matchesFrom && matchesTo;
    }).toList();
  }

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final initialDate = isStart ? _fromDate ?? DateTime.now() : _toDate ?? DateTime.now();
    final firstDate = DateTime(2000);
    final lastDate = DateTime.now().add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) return;
    setState(() {
      if (isStart) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
      _page = 0;
    });
  }

  Future<void> _exportFilteredLedger(String format) async {
    final entries = _filterEntries(_activeTab == 0 ? _customerLedgerEntries : _supplierLedgerEntries);
    if (entries.isEmpty) {
      AppSnackBar.warning(message: 'No records found to export.');
      return;
    }

    setState(() {
      _exporting = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final folder = Directory('${directory.path}${Platform.pathSeparator}SalesERP-LedgerExports');
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = _activeTab == 0 ? 'customer-ledger-$stamp' : 'supplier-ledger-$stamp';
      final filePath = '${folder.path}${Platform.pathSeparator}$fileName.$format';

      if (format == 'csv') {
        final csv = _buildCsv(entries);
        final file = File(filePath);
        await file.writeAsString(csv);
        AppSnackBar.success(message: 'Ledger exported to ${file.path}');
      } else {
        final file = File(filePath);
        final pdfBytes = await _buildPdf(entries);
        await file.writeAsBytes(pdfBytes);
        AppSnackBar.success(message: 'Ledger exported to ${file.path}');
      }
    } catch (e) {
      AppSnackBar.failed(message: 'Could not export ledger: $e');
    } finally {
      setState(() {
        _exporting = false;
      });
    }
  }

  String _buildCsv(List<LedgerEntry> entries) {
    final header = ['S.No', 'Invoice Date', 'Invoice No', 'Payment Method', 'Debit', 'Credit', 'Balance'];
    final rows = entries.asMap().entries.map((entry) {
      return [
        '${entry.key + 1}',
        _dateFormat.format(entry.value.date),
        entry.value.invoiceNo,
        entry.value.paymentMethod,
        _moneyFormat.format(entry.value.debit),
        _moneyFormat.format(entry.value.credit),
        _moneyFormat.format(entry.value.balance),
      ];
    });
    final buffer = StringBuffer();
    buffer.writeln(header.join(','));
    for (final row in rows) {
      buffer.writeln(row.map((cell) => '"${cell.toString().replaceAll('"', '""')}"').join(','));
    }
    return buffer.toString();
  }

  Future<List<int>> _buildPdf(List<LedgerEntry> entries) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: pdfLib.PdfPageFormat.a4,
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 9, color: pdfLib.PdfColors.grey700),
            ),
          );
        },
        build: (context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _activeTab == 0 ? 'Customer Ledger' : 'Supplier Ledger',
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: pdfLib.PdfColors.black),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Export generated on ${_dateFormat.format(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 10, color: pdfLib.PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: pdfLib.PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                    color: pdfLib.PdfColors.grey100,
                  ),
                  child: pw.Text(
                    'Sales Ledger',
                    style: pw.TextStyle(fontSize: 10, color: pdfLib.PdfColors.grey900),
                  ),
                ),
              ],
            ),
            pw.Divider(color: pdfLib.PdfColors.grey300, thickness: 0.9),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildPdfMetric('Total Debit', _moneyFormat.format(entries.fold(0.0, (sum, entry) => sum + entry.debit)), pdfLib.PdfColors.green50, pdfLib.PdfColors.green900),
                _buildPdfMetric('Total Credit', _moneyFormat.format(entries.fold(0.0, (sum, entry) => sum + entry.credit)), pdfLib.PdfColors.blue50, pdfLib.PdfColors.blue900),
                _buildPdfMetric('Closing Balance', _moneyFormat.format(entries.isNotEmpty ? entries.last.balance : 0), pdfLib.PdfColors.grey200, pdfLib.PdfColors.grey900),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.TableHelper.fromTextArray(
              headers: ['S.No', 'Date', 'Invoice No', 'Method', 'Cheque', 'Debit', 'Credit', 'Balance'],
              data: entries.asMap().entries.map((entry) {
                return [
                  '${entry.key + 1}',
                  _dateFormat.format(entry.value.date),
                  entry.value.invoiceNo,
                  entry.value.paymentMethod,
                  entry.value.chequeInfo,
                  _moneyFormat.format(entry.value.debit),
                  _moneyFormat.format(entry.value.credit),
                  _moneyFormat.format(entry.value.balance),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: pdfLib.PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: pdfLib.PdfColors.blue900),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: pw.TextStyle(fontSize: 10, color: pdfLib.PdfColors.black),
              oddRowDecoration: const pw.BoxDecoration(color: pdfLib.PdfColors.grey100),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.8),
                1: const pw.FlexColumnWidth(1.3),
                2: const pw.FlexColumnWidth(2.3),
                3: const pw.FlexColumnWidth(1.7),
                4: const pw.FlexColumnWidth(1.2),
                5: const pw.FlexColumnWidth(1.2),
                6: const pw.FlexColumnWidth(1.2),
              },
              cellAlignments: {
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
              },
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  pw.Widget _buildPdfMetric(String label, String value, pdfLib.PdfColor bgColor, pdfLib.PdfColor textColor) {
    return pw.Container(
      width: 140,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: pdfLib.PdfColors.grey700)),
          pw.SizedBox(height: 6),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  void _changePage(int delta, int pageCount) {
    setState(() {
      _page = (_page + delta).clamp(0, pageCount - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = _filterEntries(_activeTab == 0 ? _customerLedgerEntries : _supplierLedgerEntries);
    final pageEntries = filteredEntries.skip(_page * _rowsPerPage).take(_rowsPerPage).toList();
    final totals = filteredEntries.fold<LedgerTotals>(
      LedgerTotals.zero(),
      (prev, entry) => prev.copyWith(
        debit: prev.debit + entry.debit,
        credit: prev.credit + entry.credit,
        balance: entry.balance,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                        
                          Text(
                            'Customer and supplier account ledgers with filters, search, pagination, and export.',
                            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _actionButton(
                      title: _exporting ? 'Exporting...' : 'Download PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      onPressed: _exporting ? null : () => _exportFilteredLedger('pdf'),
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                PremiumCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _ledgerTabButton(
                            icon: Icons.people,
                            title: 'Customer Ledger',
                            selected: _activeTab == 0,
                            onTap: () {
                              setState(() {
                                _activeTab = 0;
                                _page = 0;
                                _searchQuery = '';
                                _fromDate = null;
                                _toDate = null;
                              });
                            },
                          ),
                          const SizedBox(width: 12),
                          _ledgerTabButton(
                            icon: Icons.local_shipping,
                            title: 'Supplier Ledger',
                            selected: _activeTab == 1,
                            onTap: () {
                              setState(() {
                                _activeTab = 1;
                                _page = 0;
                                _searchQuery = '';
                                _fromDate = null;
                                _toDate = null;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildPartyDropdown(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _buildDateField(
                              label: 'From date',
                              value: _fromDate,
                              onTap: () => _pickDate(context, true),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _buildDateField(
                              label: 'To date',
                              value: _toDate,
                              onTap: () => _pickDate(context, false),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 4,
                            child: _buildSearchField(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _loading
                          ? const SizedBox(
                              height: 380,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : _buildLedgerTable(pageEntries, filteredEntries.length, totals),
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

  Widget _buildLedgerTable(List<LedgerEntry> entries, int totalItems, LedgerTotals totals) {
    final pageCount = (totalItems / _rowsPerPage).ceil().clamp(1, 999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Transactions (${totalItems.toString()})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Row(
              children: [
                Text('Rows per page:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _rowsPerPage,
                  items: const [10, 20, 50].map((value) {
                    return DropdownMenuItem(value: value, child: Text('$value'));
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _rowsPerPage = value;
                      _page = 0;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        PremiumCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SummaryMetric(
                      label: 'Total Debit',
                      value: _moneyFormat.format(totals.debit),
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SummaryMetric(
                      label: 'Total Credit',
                      value: _moneyFormat.format(totals.credit),
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SummaryMetric(
                      label: 'Closing Balance',
                      value: _moneyFormat.format(totals.balance),
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 52,
                    dataRowHeight: 56,
                    showBottomBorder: true,
                    headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
                    columns: const [
                      DataColumn(label: Text('S.No')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Particular')),
                      DataColumn(label: Text('Cheque')),
                      DataColumn(label: Text('Invoice No')),
                      DataColumn(label: Text('Debit')),
                      DataColumn(label: Text('Credit')),
                      DataColumn(label: Text('Balance')),
                    ],
                    rows: entries.asMap().entries.map((item) {
                      final entry = item.value;
                      return DataRow(cells: [
                        DataCell(Text('${item.key + 1 + _page * _rowsPerPage}')),
                        DataCell(Text(_dateFormat.format(entry.date))),
                        DataCell(Text(entry.paymentMethod)),
                        DataCell(Text(entry.chequeInfo)),
                        DataCell(Text(entry.invoiceNo)),
                        DataCell(Text(entry.debit > 0 ? _moneyFormat.format(entry.debit) : '-')),
                        DataCell(Text(entry.credit > 0 ? _moneyFormat.format(entry.credit) : '-')),
                        DataCell(Text(_moneyFormat.format(entry.balance))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Page ${_page + 1} of $pageCount'),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _page > 0 ? () => _changePage(-1, pageCount) : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _page < pageCount - 1 ? () => _changePage(1, pageCount) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPartyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _activeTab == 0 ? 'Customer' : 'Supplier',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        if (_activeTab == 0)
          DropdownSearch<CustomerModel>(
            selectedItem: _selectedCustomer,
            items: (filter, _) => _customers,
            itemAsString: (customer) => customer.name,
            compareFn: (item, selectedItem) => item.id == selectedItem.id,
            popupProps: PopupProps.menu(
              showSearchBox: true,
              fit: FlexFit.loose,
            ),
            decoratorProps: DropDownDecoratorProps(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Select',
                isDense: true,
              ),
            ),
            onChanged: (customer) {
              if (customer == null) return;
              setState(() {
                _selectedCustomer = customer;
                _page = 0;
              });
              _loadCustomerInvoices(customer.id);
            },
          )
        else
          DropdownSearch<SupplierModel>(
            selectedItem: _selectedSupplier,
            items: (filter, _) => _suppliers,
            itemAsString: (supplier) => supplier.name,
            compareFn: (item, selectedItem) => item.name == selectedItem.name,
            popupProps: PopupProps.menu(
              showSearchBox: true,
              fit: FlexFit.loose,
            ),
            decoratorProps: DropDownDecoratorProps(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Select',
                isDense: true,
              ),
            ),
            onChanged: (supplier) {
              if (supplier == null) return;
              setState(() {
                _selectedSupplier = supplier;
                _page = 0;
              });
              _loadSupplierInvoices(supplier.name);
            },
          ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_month),
              isDense: true,
            ),
            child: Text(value != null ? _dateFormat.format(value) : 'Select date'),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Search', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              _page = 0;
            });
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Search invoices, methods or notes',
            prefixIcon: Icon(Icons.search_rounded),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _ledgerTabButton({
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.grey, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String title,
    required IconData icon,
    required VoidCallback? onPressed,
    bool compact = false,
  }) {
    return SizedBox(
      height: compact ? 34 : 40,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 18,
            vertical: 0,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: compact ? 16 : 18),
        label: Text(
          title,
          style: TextStyle(
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class LedgerEntry {
  LedgerEntry({
    required this.date,
    required this.invoiceNo,
    required this.paymentMethod,
    required this.chequeInfo,
    required this.debit,
    required this.credit,
    required this.note,
    this.balance = 0,
  });

  final DateTime date;
  final String invoiceNo;
  final String paymentMethod;
  final String chequeInfo;
  final double debit;
  final double credit;
  final String note;
  final double balance;

  LedgerEntry copyWith({double? balance}) {
    return LedgerEntry(
      date: date,
      invoiceNo: invoiceNo,
      paymentMethod: paymentMethod,
      chequeInfo: chequeInfo,
      debit: debit,
      credit: credit,
      note: note,
      balance: balance ?? this.balance,
    );
  }
}

class LedgerTotals {
  const LedgerTotals({required this.debit, required this.credit, required this.balance});

  final double debit;
  final double credit;
  final double balance;

  factory LedgerTotals.zero() => const LedgerTotals(debit: 0, credit: 0, balance: 0);

  LedgerTotals copyWith({double? debit, double? credit, double? balance}) {
    return LedgerTotals(
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      balance: balance ?? this.balance,
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
