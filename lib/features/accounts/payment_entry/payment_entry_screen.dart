import 'dart:io';

import 'package:desktop/core/widgets/app_snackbar.dart';
import 'package:desktop/features/accounts/payment_entry/models/payment_model.dart';
import 'package:desktop/features/accounts/payment_entry/services/payment_service.dart';
import 'package:desktop/features/accounts/payment_entry/widgets/payment_dialog.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdfLib;
import 'package:pdf/widgets.dart' as pw;

class PaymentEntryScreen extends StatefulWidget {
  const PaymentEntryScreen({super.key});

  @override
  State<PaymentEntryScreen> createState() => _PaymentEntryScreenState();
}

class _PaymentEntryScreenState extends State<PaymentEntryScreen> {
  int _selectedTab = 0;
  Widget _tabButton({
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
          color: selected ? const Color(0xff2F54EB) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xff2F54EB) : Colors.grey.shade300,
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: const Color(0xffF5F7FA),
            body: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// HEADER
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Payment Entry",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Manage customer & supplier payments",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  /// TAB BAR
                  Row(
                    children: [
                      _tabButton(
                        icon: Icons.people,
                        title: "Customer Payments",
                        selected: _selectedTab == 0,
                        onTap: () {
                          setState(() {
                            _selectedTab = 0;
                          });
                        },
                      ),

                      const SizedBox(width: 12),

                      _tabButton(
                        icon: Icons.local_shipping,
                        title: "Supplier Payments",
                        selected: _selectedTab == 1,
                        onTap: () {
                          setState(() {
                            _selectedTab = 1;
                          });
                        },
                      ),

                      const Spacer(),
                    ],
                  ),

                  const SizedBox(height: 18),

                  /// TAB VIEW
                  Expanded(
                    child: _selectedTab == 0
                        ? const _CustomerPaymentTab()
                        : const _SupplierPaymentTab(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

///------------------------------------------------------------
/// CUSTOMER TAB
///------------------------------------------------------------

class _CustomerPaymentTab extends StatelessWidget {
  const _CustomerPaymentTab();

  @override
  Widget build(BuildContext context) {
    return _PaymentTable(title: "Recent Customer Payments", isSupplier: false);
  }
}

///------------------------------------------------------------
/// SUPPLIER TAB
///------------------------------------------------------------

class _SupplierPaymentTab extends StatelessWidget {
  const _SupplierPaymentTab();

  @override
  Widget build(BuildContext context) {
    return _PaymentTable(title: "Recent Supplier Payments", isSupplier: true);
  }
}

class _PaymentTable extends StatefulWidget {
  final String title;
  final bool isSupplier;

  const _PaymentTable({required this.title, required this.isSupplier});

  @override
  State<_PaymentTable> createState() => _PaymentTableState();
}

class _PaymentTableState extends State<_PaymentTable> {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');

  List<PaymentModel> _payments = [];
  List<PaymentModel> _filteredPayments = [];
  bool _isLoading = true;
  String _searchText = '';
  String _selectedMode = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  static const int _rowsPerPage = 5;

  @override
  void initState() {
    super.initState();
    _loadPayments();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final payments = await PaymentService.getPayments();
      _payments = payments.where((payment) {
        final hasSupplier =
            payment.supplierId != null && payment.supplierId!.isNotEmpty;
        return widget.isSupplier ? hasSupplier : !hasSupplier;
      }).toList();
      _applyFilters();
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.failed(message: 'Failed to load payments: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchText = _searchController.text.trim();
      _currentPage = 0;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final query = _searchText.toLowerCase();

    _filteredPayments = _payments.where((payment) {
      final matchesMode =
          _selectedMode == 'All' ||
          payment.paymentMode.toLowerCase() == _selectedMode.toLowerCase();

      final matchesDate = (_startDate == null || _endDate == null)
          ? true
          : (payment.paymentDate.isAtSameMomentAs(_startDate!) ||
                    payment.paymentDate.isAfter(_startDate!)) &&
                (payment.paymentDate.isAtSameMomentAs(_endDate!) ||
                    payment.paymentDate.isBefore(_endDate!));

      final customerName = payment.partyName ?? payment.customerName;
      final invoiceNo = payment.invoiceNo ?? '';
      final amountText = payment.amount.toStringAsFixed(2);
      final dateText = _dateFormat.format(payment.paymentDate);

      final matchesSearch =
          query.isEmpty ||
          customerName.toLowerCase().contains(query) ||
          payment.voucherNo.toLowerCase().contains(query) ||
          payment.paymentMode.toLowerCase().contains(query) ||
          invoiceNo.toLowerCase().contains(query) ||
          payment.referenceNo.toLowerCase().contains(query) ||
          payment.status.toLowerCase().contains(query) ||
          amountText.contains(query) ||
          dateText.contains(query);

      return matchesMode && matchesDate && matchesSearch;
    }).toList();

    if (_currentPage >= pageCount) {
      _currentPage = pageCount > 0 ? pageCount - 1 : 0;
    }
  }

  int get pageCount {
    if (_filteredPayments.isEmpty) return 1;
    return (_filteredPayments.length / _rowsPerPage).ceil();
  }

  List<PaymentModel> get _pagedPayments {
    final start = _currentPage * _rowsPerPage;
    return _filteredPayments.skip(start).take(_rowsPerPage).toList();
  }

  Future<void> _openPaymentDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentDialog(isSupplier: widget.isSupplier),
    );

    if (result == true) {
      await _loadPayments();
    }
  }

  Future<void> _showFilterDialog() async {
    final selectedMode = _selectedMode;
    final startDate = _startDate;
    final endDate = _endDate;

    await showDialog<void>(
      context: context,
      builder: (context) {
        String filterMode = selectedMode;
        DateTime? localStart = startDate;
        DateTime? localEnd = endDate;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: Container(
                width: 380,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FE),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter payments',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.blueGrey.shade900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Refine the payment list with smart filters.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.blueGrey.shade400,
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: filterMode,
                      decoration: InputDecoration(
                        labelText: 'Payment Mode',
                        labelStyle: GoogleFonts.poppins(color: Colors.blueGrey.shade600),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                        DropdownMenuItem(value: 'upi', child: Text('UPI')),
                        DropdownMenuItem(value: 'bankTransfer', child: Text('Bank Transfer')),
                      ],
                      onChanged: (value) {
                        setStateDialog(() {
                          filterMode = value ?? 'All';
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: localStart ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                helpText: 'Select start date',
                              );
                              if (picked != null) {
                                setStateDialog(() {
                                  localStart = picked;
                                });
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: BorderSide(color: Colors.grey.shade200),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  localStart == null
                                      ? 'Start date'
                                      : _dateFormat.format(localStart!),
                                  style: GoogleFonts.poppins(
                                    color: Colors.blueGrey.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                                const Icon(Icons.calendar_month_outlined, size: 18),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: localEnd ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                helpText: 'Select end date',
                              );
                              if (picked != null) {
                                setStateDialog(() {
                                  localEnd = picked;
                                });
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: BorderSide(color: Colors.grey.shade200),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  localEnd == null
                                      ? 'End date'
                                      : _dateFormat.format(localEnd!),
                                  style: GoogleFonts.poppins(
                                    color: Colors.blueGrey.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                                const Icon(Icons.calendar_month_outlined, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              localStart = null;
                              localEnd = null;
                              filterMode = 'All';
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.white,
                            ),
                            child: Text(
                              'Reset',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey.shade700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedMode = filterMode;
                                _startDate = localStart;
                                _endDate = localEnd;
                                _currentPage = 0;
                                _applyFilters();
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              'Apply',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportPaymentsPdf() async {
    if (_filteredPayments.isEmpty) {
      AppSnackBar.warning(message: 'No payments to export.');
      return;
    }

    final pdf = pw.Document();
    final tableHeaders = ['Voucher', 'Party', 'Invoice', 'Mode', 'Amount', 'Date', 'Status'];
    final tableData = _filteredPayments.map((payment) {
      final party = payment.partyName ?? payment.customerName;
      return [
        payment.voucherNo,
        party,
        payment.invoiceNo?.isNotEmpty == true ? payment.invoiceNo! : '-',
        payment.paymentMode,
        '₹${payment.amount.toStringAsFixed(2)}',
        _dateFormat.format(payment.paymentDate),
        payment.status,
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(24)),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: 1, color: pdfLib.PdfColor.fromInt(0xFFD1D5DB)),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Payment Export',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${widget.title} · Generated on ${DateFormat('dd-MM-yyyy').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 10, color: pdfLib.PdfColor.fromInt(0xFF6B7280)),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Table.fromTextArray(
            headers: tableHeaders,
            data: tableData,
            headerStyle: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            cellStyle: pw.TextStyle(fontSize: 10),
            headerDecoration: pw.BoxDecoration(color: pdfLib.PdfColor.fromInt(0xFFEFF6FF)),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2.5),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(2),
              5: const pw.FlexColumnWidth(2),
              6: const pw.FlexColumnWidth(1.8),
            },
            cellAlignments: {
              4: pw.Alignment.centerRight,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
            },
          ),
        ],
      ),
    );

    final pdfBytes = await pdf.save();
    final documentsDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${documentsDir.path}${Platform.pathSeparator}SalesOrderExports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final file = File(
      '${exportDir.path}${Platform.pathSeparator}payments_export_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(pdfBytes);

    AppSnackBar.success(message: 'PDF saved to ${file.path}');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          /// HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      widget.isSupplier
                          ? "Manage supplier payments"
                          : "Manage customer payments",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    "${_filteredPayments.length} Records",
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// TOOLBAR
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 34,
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.poppins(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "Search...",
                        hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                erpActionButton(
                  title: "Filter",
                  icon: Icons.filter_alt_outlined,
                  onPressed: _showFilterDialog,
                  compact: true,
                ),

                const SizedBox(width: 8),

                erpActionButton(
                  title: "Download PDF",
                  icon: Icons.picture_as_pdf_outlined,
                  onPressed: _exportPaymentsPdf,
                  compact: true,
                ),

                const SizedBox(width: 10),

                primaryButton(
                  title: widget.isSupplier ? "New Payment" : "New Receipt",
                  icon: Icons.add,
                  onPressed: _openPaymentDialog,
                  compact: true,
                ),
              ],
            ),
          ),

          Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPayments.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No payment records found.',
                            style: TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth,
                                    ),
                                    child: DataTable(
                                      horizontalMargin: 8,
                                      columnSpacing: 14,
                                      dividerThickness: 0.5,
                                      headingRowHeight: 36,
                                      dataRowMinHeight: 36,
                                      dataRowMaxHeight: 40,
                                      headingTextStyle: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                        fontSize: 12,
                                      ),
                                      dataTextStyle: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                      columns: const [
                                        DataColumn(label: Text("Voucher")),
                                        DataColumn(label: Text("Party")),
                                        DataColumn(label: Text("Invoice")),
                                        DataColumn(label: Text("Amount")),
                                        DataColumn(label: Text("Mode")),
                                        DataColumn(label: Text("Date")),
                                        DataColumn(label: Text("Status")),
                                      ],
                                      rows: _pagedPayments.map((payment) {
                                        final party =
                                            payment.partyName ?? payment.customerName;
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(payment.voucherNo)),
                                            DataCell(Text(party)),
                                            DataCell(
                                              Text(
                                                payment.invoiceNo?.isNotEmpty == true
                                                    ? payment.invoiceNo!
                                                    : '-',
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                '₹${payment.amount.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            DataCell(Text(payment.paymentMode)),
                                            DataCell(
                                              Text(
                                                _dateFormat.format(
                                                  payment.paymentDate,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade100,
                                                  borderRadius: BorderRadius.circular(
                                                    14,
                                                  ),
                                                ),
                                                child: Text(
                                                  payment.status,
                                                  style: TextStyle(
                                                    color: Colors.green.shade800,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border(top: BorderSide(color: Colors.grey.shade200)),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Page ${_currentPage + 1} of $pageCount',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.blueGrey.shade700,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: _currentPage > 0
                                      ? () {
                                          setState(() {
                                            _currentPage -= 1;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.arrow_back_ios_new,size: 13),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: _currentPage < pageCount - 1
                                      ? () {
                                          setState(() {
                                            _currentPage += 1;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.arrow_forward_ios,size: 13),
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

  Widget primaryButton({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
    bool compact = false,
  }) {
    return SizedBox(
      height: compact ? 34 : 40,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 18,
            vertical: 0,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Container(
          width: compact ? 18 : 22,
          height: compact ? 18 : 22,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.18),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(Icons.add, size: compact ? 14 : 15, color: Colors.white),
        ),
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

  Widget erpActionButton({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
    bool compact = false,
  }) {
    return SizedBox(
      height: compact ? 34 : 38,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: compact ? 16 : 18,
          color: const Color(0xFF475569),
        ),
        label: Text(
          title,
          style: TextStyle(
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: 0,
          ),
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      ),
    );
  }
}
