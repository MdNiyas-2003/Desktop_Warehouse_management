import 'package:desktop/core/widgets/app_snackbar.dart';
import 'package:desktop/features/warehouse/services/category_service.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/network/backend_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';
import 'package:intl/intl.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.openCreateSignal = 0});

  final int openCreateSignal;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final BackendApi _api = BackendApi();
  int _selectedTab = 0;
  _OrdersDateFilter _dateFilter = _OrdersDateFilter.all;
  DateTime? _customDate;
  int _lastHandledCreateSignal = 0;
  late Future<List<_OrderTableRow>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _loadOrders();
    _lastHandledCreateSignal = widget.openCreateSignal;
    if (widget.openCreateSignal > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showCreateOrderDialog();
      });
    }
  }

  @override
  void didUpdateWidget(covariant OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openCreateSignal != _lastHandledCreateSignal) {
      _lastHandledCreateSignal = widget.openCreateSignal;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showCreateOrderDialog();
      });
    }
  }

  Future<void> _showCreateOrderDialog({String? draftId}) async {
    final api = _api;
    final customers = <_CustomerProfile>[];
    final catalogMap = <String, _CatalogItem>{};
    Map<String, dynamic>? draftData;

    if (draftId != null) {
      draftData = await _api.getDraftOrderById(draftId);
    }

    try {
      final customersRaw = await api.getCustomers();
      for (final row in customersRaw) {
        final customer = _CustomerProfile.fromMap(row);

        print("RAW: $row");
        print("companyName: '${customer.companyName}'");
        print("Customer Count: ${customersRaw.length}");
        if (customer.companyName.trim().isNotEmpty) {
          customers.add(customer);
        }
      }

      final catalogRaw = await api.getCatalog();
      for (final row in catalogRaw) {
        final item = _CatalogItem.fromMap(
          (row['id'] ?? row['sku'] ?? row['itemName'] ?? 'item').toString(),
          row,
        );
        catalogMap[item.id] = item;
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.failed(
        message: 'Unable to load API data. Check backend server and DB. ($e)',
      );
      return;
    }
    if (customers.isEmpty) {
      if (!mounted) return;
      AppSnackBar.warning(
        message: 'No customers found in backend. Create customer first.',
      );
      return;
    }

    if (catalogMap.isEmpty) {
      catalogMap['manual-item'] = const _CatalogItem(
        id: 'manual-item',
        category: 'General',
        itemName: 'Manual Item',
        sku: 'MANUAL',
        rate: 0,
      );
    }

    final catalog = catalogMap.values.toList();

    final draft = await showDialog<_CreateOrderDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreateOrderDialog(
        customers: customers,
        catalog: catalog,
        draftData: draftData,
      ),
    );

    if (draft == null) return;

    final totalAmount = draft.items.fold<double>(
      0,
      (sum, item) => sum + item.lineTotal,
    );
    final totalQty = draft.items.fold<double>(0, (sum, item) => sum + item.qty);
    final now = DateTime.now();
    final orderCode =
        'ORD-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecond.toString().padLeft(3, '0')}';

    try {
      await api.createOrder({
        'orderId': orderCode,
        'shopName': draft.customer.companyName,
        'shopId': draft.customer.id,
        'salesmanName': draft.salesmanName,
        'amount': totalAmount,
        'total': totalAmount,
        'status': draft.isDraft ? 'Draft' : 'Pending',
        'isDraft': draft.isDraft,
        'productsCount': draft.items.length,
        'quantity': totalQty,
        'notes': draft.notes,
        'customer': {
          'ownerName': draft.customer.ownerName,
          'mobile': draft.customer.mobile,
          'email': draft.customer.email,
          'gstin': draft.customer.gstin,
          'region': draft.customer.region,
          'address': draft.customer.address,
        },
        'products': draft.items
            .map(
              (item) => {
                'name': item.itemName,
                'sku': item.sku,
                'category': item.category,
                'quantity': item.qty,
                'unitPrice': item.rate,
                'total': item.lineTotal,
              },
            )
            .toList(),
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.failed(message: 'Unable to create order in backend. ($e)');
      return;
    }

    if (!mounted) return;
    setState(() {
      _ordersFuture = _loadOrders();
    });
    AppSnackBar.success(message: 'Order created successfully.');
  }

  Future<List<_OrderTableRow>> _loadOrders() async {
    try {
      final rows = await _api.getOrders();
      if (rows.isEmpty) return _fallbackOrders;
      return rows.map(_OrderTableRow.fromMap).toList();
    } catch (_) {
      return _fallbackOrders;
    }
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _matchesDateFilter(DateTime date) {
    final now = DateTime.now();
    switch (_dateFilter) {
      case _OrdersDateFilter.all:
        return true;
      case _OrdersDateFilter.today:
        return _isSameDate(date, now);
      case _OrdersDateFilter.last7Days:
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
        final d = DateTime(date.year, date.month, date.day);
        return !d.isBefore(start);
      case _OrdersDateFilter.thisMonth:
        return date.year == now.year && date.month == now.month;
      case _OrdersDateFilter.custom:
        if (_customDate == null) return true;
        return _isSameDate(date, _customDate!);
    }
  }

  String _filterLabel() {
    switch (_dateFilter) {
      case _OrdersDateFilter.all:
        return 'All Dates';
      case _OrdersDateFilter.today:
        return 'Today';
      case _OrdersDateFilter.last7Days:
        return 'Last 7 Days';
      case _OrdersDateFilter.thisMonth:
        return 'This Month';
      case _OrdersDateFilter.custom:
        if (_customDate == null) return 'Custom Date';
        return '${_customDate!.day}/${_customDate!.month}/${_customDate!.year}';
    }
  }

  Future<void> _selectCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      _customDate = picked;
      _dateFilter = _OrdersDateFilter.custom;
    });
  }

  Future<bool> _updateOrderStatus(String idOrCode, String status) async {
    try {
      await _api.updateOrderStatus(idOrCode, status);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleStatusAction({
    required BuildContext dialogContext,
    required _OrderTableRow order,
    required String targetStatus,
  }) async {
    if (order.status == targetStatus) {
      AppSnackBar.warning(message: 'Order is already $targetStatus.');
      return;
    }

    final idOrCode = order.docId ?? order.orderId;
    final updated = await _updateOrderStatus(idOrCode, targetStatus);
    if (!updated) {
      AppSnackBar.failed(message: 'Unable to update status in backend API.');
      return;
    }

    setState(() {
      _ordersFuture = _loadOrders();
    });

    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
  }

  Future<void> _showOrderDetailsDialog(_OrderTableRow order) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _OrdersOrderDetailsDialog(
          order: order,
          onApprove: () => _handleStatusAction(
            dialogContext: dialogContext,
            order: order,
            targetStatus: 'Approved',
          ),
          onReject: () => _handleStatusAction(
            dialogContext: dialogContext,
            order: order,
            targetStatus: 'Rejected',
          ),
          onExportInvoice: () async {
            Navigator.of(dialogContext).pop();
            await Future<void>.delayed(const Duration(milliseconds: 150));
            if (!mounted) return;
            await _exportInvoiceReceipt(order);
          },
        );
      },
    );
  }

  Future<void> _exportInvoiceReceipt(_OrderTableRow order) async {
    final items = order.productsForDialog;
    final totalQty = items.fold<double>(0, (sum, item) => sum + item.quantity);
    final subTotal = items.fold<double>(0, (sum, item) => sum + item.lineTotal);
    const taxRate = 18.0;
    final taxableValue = subTotal / (1 + (taxRate / 100));
    final taxAmount = subTotal - taxableValue;
    final invoiceNo = 'INV-${order.orderId.replaceAll('ORD-', '')}';
    final invoiceDate =
        '${order.orderDate.day.toString().padLeft(2, '0')}/${order.orderDate.month.toString().padLeft(2, '0')}/${order.orderDate.year}';

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(26, 24, 26, 24),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8FBFF'),
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: PdfColor.fromHex('#BDD3F6')),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#243B63'),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Warehouse - Premium Receipt',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColor.fromHex('#5A6F95'),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#EAF1FF'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Invoice No: $invoiceNo',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Order ID: ${order.orderId}',
                        style: const pw.TextStyle(fontSize: 9.5),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Date: $invoiceDate',
                        style: const pw.TextStyle(fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromHex('#D7E2F5')),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BILL TO',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColor.fromHex('#5B6D8E'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        order.shop,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Salesman: ${order.salesman}',
                        style: const pw.TextStyle(fontSize: 9.5),
                      ),
                      pw.Text(
                        'Status: ${order.status}',
                        style: const pw.TextStyle(fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromHex('#D7E2F5')),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ORDER SUMMARY',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColor.fromHex('#5B6D8E'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Items: ${items.length}',
                        style: const pw.TextStyle(fontSize: 9.5),
                      ),
                      pw.Text(
                        'Quantity: ${totalQty.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 9.5),
                      ),
                      pw.Text(
                        'Order Date: ${order.dateText}',
                        style: const pw.TextStyle(fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#D7E2F5')),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.8),
              1: const pw.FlexColumnWidth(3.0),
              2: const pw.FlexColumnWidth(1.7),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.8),
              5: const pw.FlexColumnWidth(1.9),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#ECF3FF'),
                ),
                children: [
                  _pdfHeaderCell('#'),
                  _pdfHeaderCell('Description'),
                  _pdfHeaderCell('SKU'),
                  _pdfHeaderCell('Qty'),
                  _pdfHeaderCell('Unit Price'),
                  _pdfHeaderCell('Amount'),
                ],
              ),
              ...items.asMap().entries.map((entry) {
                final i = entry.key + 1;
                final item = entry.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: entry.key.isEven
                        ? PdfColors.white
                        : PdfColor.fromHex('#F9FBFF'),
                  ),
                  children: [
                    _pdfBodyCell('$i', align: pw.TextAlign.center),
                    _pdfBodyCell(item.name),
                    _pdfBodyCell(item.sku, align: pw.TextAlign.center),
                    _pdfBodyCell(
                      item.quantity.toStringAsFixed(2),
                      align: pw.TextAlign.center,
                    ),
                    _pdfBodyCell(
                      _rupee(item.unitPrice),
                      align: pw.TextAlign.right,
                    ),
                    _pdfBodyCell(
                      _rupee(item.lineTotal),
                      align: pw.TextAlign.right,
                    ),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromHex('#D7E2F5')),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Notes',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                          color: PdfColor.fromHex('#354B72'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        order.notes.isEmpty ? '-' : order.notes,
                        style: const pw.TextStyle(fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.SizedBox(
                width: 220,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F2F7FF'),
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColor.fromHex('#C8D9F8')),
                  ),
                  child: pw.Column(
                    children: [
                      _pdfTotalRow('Taxable Amount', _rupee(taxableValue)),
                      _pdfTotalRow('Tax (18%)', _rupee(taxAmount)),
                      pw.Divider(color: PdfColor.fromHex('#C4D4F2')),
                      _pdfTotalRow(
                        'Grand Total',
                        _rupee(order.amount),
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Authorized Signature',
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#4F6388'),
                    fontSize: 9,
                  ),
                ),
                pw.SizedBox(height: 22),
                pw.Container(
                  width: 160,
                  height: 1,
                  color: PdfColor.fromHex('#8EA8D6'),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Use the production invoice layout for the printable document. The
    // original layout above is retained temporarily while orders created by
    // older backend records are still supported.
    late final pw.Document invoiceDoc;
    try {
      invoiceDoc = _buildProfessionalInvoice(
        order: order,
        items: items,
        invoiceNo: invoiceNo,
        taxableValue: taxableValue,
        taxAmount: taxAmount,
        totalQty: totalQty,
      );
    } catch (error, stackTrace) {
      debugPrint('Could not build invoice preview: $error\n$stackTrace');
      if (mounted) {
        AppSnackBar.failed(
          message: 'Could not prepare invoice preview: $error',
        );
      }
      return;
    }

    if (!mounted) return;

    // Show the invoice before invoking the operating system print dialog.
    // PdfPreview's toolbar contains the Print action, so users can verify the
    // invoice and then choose their printer (or Microsoft Print to PDF).
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (previewContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 64, vertical: 34),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 960,
          height: 790,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FF),
            // borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.84)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55061535),
                blurRadius: 36,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 18, 16, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF102A62), Color(0xFF1D56C3)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        // borderRadius: BorderRadius.circular(0),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice Preview',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Review the final invoice before printing',
                            style: TextStyle(
                              color: Color(0xFFD8E5FF),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        invoiceNo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Close preview',
                      onPressed: () => Navigator.of(previewContext).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFEAF0FA),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD6E1F3)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x140B244B),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: PdfPreview(
                        build: (_) => invoiceDoc.save(),
                        pdfFileName: '$invoiceNo.pdf',
                        initialPageFormat: PdfPageFormat.a4,
                        canChangePageFormat: false,
                        canChangeOrientation: false,
                        canDebug: false,
                        allowPrinting: false,
                        allowSharing: false,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFDCE5F3))),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF16A36A),
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Invoice is ready for printing',
                        style: TextStyle(
                          color: Color(0xFF556987),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: () => Navigator.of(previewContext).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEDF2FA),
                          foregroundColor: const Color(0xFF385171),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: () async {
                          try {
                            await Printing.layoutPdf(
                              onLayout: (_) => invoiceDoc.save(),
                            );
                          } catch (error) {
                            if (!previewContext.mounted) return;
                            AppSnackBar.failed(
                              message: 'Could not print invoice: $error',
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF245EFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        icon: const Icon(Icons.print_rounded, size: 19),
                        label: const Text(
                          'Print Invoice',
                          style: TextStyle(fontWeight: FontWeight.w700),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_OrderTableRow>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        final orders = snapshot.data ?? _fallbackOrders;

        final filteredOrders = orders
            .where((o) => _matchesDateFilter(o.orderDate))
            .toList();

        final newOrders =
            filteredOrders.where((o) => o.status == 'Pending').toList()
              ..sort((a, b) => b.sortTime.compareTo(a.sortTime));
        final approved = filteredOrders
            .where((o) => o.status == 'Approved')
            .toList();
        final dispatched = filteredOrders
            .where(
              (o) =>
                  o.status == 'In Transit' || o.status == 'Ready to Dispatch',
            )
            .toList();
        final delivered = filteredOrders
            .where((o) => o.status == 'Delivered')
            .toList();

        final tabs = [newOrders, approved, dispatched, delivered];
        final selected = tabs[_selectedTab];
        final rowsData = _selectedTab == 0
            ? selected.take(5).toList()
            : selected;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Order Management',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(fontSize: 26),
                        ),
                      ),
                      ActionButton(
                        label: 'Create Order',
                        icon: Icons.add_shopping_cart_rounded,
                        primary: true,
                        onPressed: () async {
                          final draftsJson = await _api.getDraftOrders();

                          if (draftsJson.isEmpty) {
                            await _showCreateOrderDialog();
                            return;
                          }

                          final drafts = draftsJson
                              .map((e) => _DraftOrder.fromJson(e))
                              .toList();

                          final result = await showDialog(
                            context: context,
                            builder: (_) => _DraftOrdersDialog(drafts: drafts),
                          );

                          if (result == null) return;

                          if (result == "new") {
                            await _showCreateOrderDialog();
                            return;
                          }

                          if (result is Map && result["action"] == "open") {
                            await _showCreateOrderDialog(draftId: result["id"]);

                            return;
                          }
                          if (result is Map && result["action"] == "delete") {
                            await _api.deleteDraft(result["id"]);

                            AppSnackBar.success(
                              message: "Draft deleted successfully",
                            );

                            setState(() {});

                            return;
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Monitor all sales orders, approvals, and dispatch stages from one table.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              PremiumCard(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PillTabBar(
                      labels: [
                        'New Orders (${newOrders.length})',
                        'Approved (${approved.length})',
                        'Dispatched (${dispatched.length})',
                        'Delivered (${delivered.length})',
                      ],
                      selectedIndex: _selectedTab,
                      compact: true,
                      onSelected: (value) =>
                          setState(() => _selectedTab = value),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        PopupMenuButton<_OrdersDateFilter>(
                          color: Colors.white,
                          tooltip: 'Date filter',
                          onSelected: (value) {
                            if (value == _OrdersDateFilter.custom) {
                              _selectCustomDate();
                              return;
                            }
                            setState(() {
                              _dateFilter = value;
                              if (value != _OrdersDateFilter.custom) {
                                _customDate = null;
                              }
                            });
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: _OrdersDateFilter.all,
                              child: Text('All Dates'),
                            ),
                            PopupMenuItem(
                              value: _OrdersDateFilter.today,
                              child: Text('Today'),
                            ),
                            PopupMenuItem(
                              value: _OrdersDateFilter.last7Days,
                              child: Text('Last 7 Days'),
                            ),
                            PopupMenuItem(
                              value: _OrdersDateFilter.thisMonth,
                              child: Text('This Month'),
                            ),
                            PopupMenuItem(
                              value: _OrdersDateFilter.custom,
                              child: Text('Custom Date'),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  size: 14,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _filterLabel(),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.text,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11.5,
                                      ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${filteredOrders.length} orders',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (rowsData.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: Text(
                          'No orders found for this status.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    else
                      SimpleTable(
                        headers: const [
                          'Order ID',
                          'Order Date',
                          'Shop Name',
                          'Salesman',
                          'Amount',
                          'Status',
                          'Action',
                        ],
                        columnFlexes: const [12, 12, 18, 12, 12, 12, 6],
                        rows: rowsData
                            .map(
                              (o) => [
                                TableTextCell(o.orderId, compact: true),
                                TableTextCell(o.dateText, compact: true),
                                _ScrollableTableTextCell(o.shop, compact: true),
                                TableTextCell(o.salesman, compact: true),
                                TableTextCell(_rupee(o.amount), compact: true),
                                _BadgeCell(o.status, _statusColor(o.status)),
                                _ActionCell(
                                  compact: true,
                                  onTap: () => _showOrderDetailsDialog(o),
                                ),
                              ],
                            )
                            .toList(),
                        compact: true,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DraftOrdersDialog extends StatelessWidget {
  const _DraftOrdersDialog({required this.drafts});

  final List<_DraftOrder> drafts;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 220, vertical: 90),
      child: Container(
        width: 620,
        height: 420,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            //=================================================
            // HEADER
            //=================================================
            Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xffECEFF5))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xffEEF4FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      size: 17,
                      color: Color(0xff2563EB),
                    ),
                  ),

                  const SizedBox(width: 10),

                  const Expanded(
                    child: Text(
                      "Draft Orders",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(110, 34),
                      elevation: 0,
                      backgroundColor: const Color(0xff2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context, "new");
                    },
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text(
                      "New",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  IconButton(
                    splashRadius: 18,
                    iconSize: 18,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            //=================================================
            // SUMMARY BAR
            //=================================================
            Container(
              height: 42,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xffF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: Color(0xff2563EB),
                  ),

                  const SizedBox(width: 8),

                  Text(
                    "${drafts.length} Draft${drafts.length == 1 ? "" : "s"}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),

                  const Spacer(),

                  Text(
                    "Continue Editing",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                ],
              ),
            ),

            //=================================================
            // LIST
            //=================================================
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: drafts.length,
                itemBuilder: (context, index) {
                  final draft = drafts[index];

                  // PART 2

                  return _DraftCard(
                    child: Container(
                      height: 82,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xffE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          //--------------------------------------------------
                          // ICON
                          //--------------------------------------------------
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xffEEF4FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.receipt_long_outlined,
                              color: Color(0xff2563EB),
                              size: 18,
                            ),
                          ),

                          const SizedBox(width: 10),

                          //--------------------------------------------------
                          // DETAILS
                          //--------------------------------------------------
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      draft.orderId,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffEEF7FF),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        "Draft",
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Color(0xff2563EB),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  draft.customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),

                                const SizedBox(height: 3),

                                Text(
                                  "${draft.quantity} Qty • ₹${draft.amount.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          //--------------------------------------------------
                          // DATE
                          //--------------------------------------------------
                          SizedBox(
                            width: 72,
                            child: Text(
                              "${draft.createdAt.day}/${draft.createdAt.month}/${draft.createdAt.year}",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          //--------------------------------------------------
                          // DELETE
                          //--------------------------------------------------
                          IconButton(
                            splashRadius: 18,
                            iconSize: 18,
                            onPressed: () {
                              Navigator.pop(context, {
                                "action": "delete",
                                "id": draft.id,
                              });
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),

                          //--------------------------------------------------
                          // OPEN
                          //--------------------------------------------------
                          FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(70, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              backgroundColor: const Color(0xff2563EB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context, {
                                "action": "open",
                                "id": draft.id,
                              });
                            },
                            child: const Text(
                              "Open",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            //=================================================
            // FOOTER
            //=================================================
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xffECEFF5))),
              ),
              child: Row(
                children: [
                  Text(
                    "${drafts.length} Saved Draft${drafts.length == 1 ? "" : "s"}",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),

                  const Spacer(),

                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(74, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("Close", style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftCard extends StatefulWidget {
  const _DraftCard({required this.child});

  final Widget child;

  @override
  State<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends State<_DraftCard> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => hover = true);
      },
      onExit: (_) {
        setState(() => hover = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),

        transform: Matrix4.identity()..translate(0.0, hover ? -2.0 : 0.0),

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),

          boxShadow: [
            BoxShadow(
              color: hover ? Colors.blue.withOpacity(.08) : Colors.transparent,

              blurRadius: 12,

              offset: const Offset(0, 4),
            ),
          ],
        ),

        child: widget.child,
      ),
    );
  }
}

class _HoverDraftCard extends StatefulWidget {
  const _HoverDraftCard({required this.child});

  final Widget child;

  @override
  State<_HoverDraftCard> createState() => _HoverDraftCardState();
}

class _HoverDraftCardState extends State<_HoverDraftCard> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          hovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          hovering = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),

        transform: Matrix4.identity()..translate(0.0, hovering ? -5.0 : 0.0),

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),

          boxShadow: [
            BoxShadow(
              color: hovering
                  ? Colors.blue.withOpacity(.14)
                  : Colors.black.withOpacity(.05),

              blurRadius: hovering ? 35 : 18,

              offset: Offset(0, hovering ? 18 : 8),
            ),
          ],
        ),

        child: widget.child,
      ),
    );
  }
}

// ignore: unused_element
class _DraftChip extends StatelessWidget {
  const _DraftChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),

      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(icon, size: 16, color: Colors.blueGrey),

          const SizedBox(width: 7),

          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class DraftChoiceDialog extends StatelessWidget {
  const DraftChoiceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Draft Order Found"),
      content: const Text(
        "You have an unfinished draft order.\n\n"
        "Do you want to continue editing it or create a new order?",
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context, "new");
          },
          child: const Text("Create New"),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, "draft");
          },
          child: const Text("Continue Draft"),
        ),
      ],
    );
  }
}

class _OrderTableRow {
  const _OrderTableRow({
    required this.docId,
    required this.orderId,
    required this.shop,
    required this.salesman,
    required this.amount,
    required this.status,
    required this.orderDate,
    required this.sortTime,
    required this.productsCount,
    required this.quantity,
    required this.isDraft,
    required this.notes,
    required this.rawProducts,
  });

  final String? docId;
  final String orderId;
  final String shop;
  final String salesman;
  final double amount;
  final String status;
  final DateTime orderDate;
  final DateTime sortTime;
  final int productsCount;
  final double quantity;
  final bool isDraft;
  final String notes;
  final List<dynamic> rawProducts;

  String get dateText {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${orderDate.day} ${months[orderDate.month - 1]} ${orderDate.year}';
  }

  List<_OrdersLineItem> get productsForDialog {
    if (rawProducts.isNotEmpty) {
      return List.generate(rawProducts.length, (index) {
        final dynamic raw = rawProducts[index];
        final p = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        final qty = _asNum(p['quantity'] ?? 0);
        final total = _asNum(p['total'] ?? p['lineTotal'] ?? 0);
        final price = qty > 0 ? (total / qty).toDouble() : 0.0;
        return _OrdersLineItem(
          name: (p['name'] ?? p['productName'] ?? 'Item ${index + 1}')
              .toString(),
          sku: (p['sku'] ?? p['code'] ?? 'SKU-${index + 1}').toString(),
          quantity: qty,
          unitPrice: price,

          lineTotal: total,
        );
      });
    }

    final count = productsCount > 0 ? productsCount : 1;
    final perItemQty = quantity > 0 ? (quantity / count).toDouble() : 1.0;
    final perItemPrice = amount > 0 ? (amount / count).toDouble() : 0.0;

    return List.generate(
      count,
      (index) => _OrdersLineItem(
        name: 'Item ${index + 1}',
        sku: 'SKU-${(index + 1).toString().padLeft(3, '0')}',
        quantity: perItemQty,
        unitPrice: perItemPrice,
        lineTotal: perItemQty * perItemPrice,
      ),
    );
  }

  factory _OrderTableRow.fromMap(Map<String, dynamic> data) {
    final createdRaw = data['createdAt'];
    final updatedRaw = data['updatedAt'];
    final dynamic productsDynamic = data['products'];

    DateTime created = DateTime.now();
    if (createdRaw is DateTime) {
      created = createdRaw;
    } else if (createdRaw is String) {
      created = DateTime.tryParse(createdRaw) ?? created;
    }

    DateTime sort = created;
    if (updatedRaw is DateTime) {
      sort = updatedRaw;
    } else if (updatedRaw is String) {
      sort = DateTime.tryParse(updatedRaw) ?? sort;
    }

    final List<dynamic> products = productsDynamic is List
        ? List<dynamic>.from(productsDynamic)
        : <dynamic>[];

    final quantityFromProducts = products.fold<double>(
      0,
      (sum, item) => sum + _asNum(item is Map ? item['quantity'] ?? 0 : 0),
    );

    return _OrderTableRow(
      docId: (data['id'] ?? '').toString().isEmpty
          ? null
          : data['id'].toString(),
      orderId: (data['orderId'] ?? data['order_code'] ?? '').toString(),
      shop: (data['shopName'] ?? data['shop'] ?? 'Unknown Shop').toString(),
      salesman: (data['salesmanName'] ?? data['salesman'] ?? 'Unknown')
          .toString(),
      amount: _asNum(data['amount'] ?? data['total'] ?? 0),
      status: _normalizeStatus((data['status'] ?? 'Pending').toString()),
      orderDate: created,
      sortTime: sort,
      productsCount: (data['productsCount'] is num)
          ? (data['productsCount'] as num).toInt()
          : (products.isNotEmpty ? products.length : 0),
      quantity: _asNum(data['quantity'] ?? quantityFromProducts),
      isDraft: data['isDraft'] ?? false,
      notes: (data['notes'] ?? 'No notes').toString(),
      rawProducts: products,
    );
  }
}

final _fallbackOrders = <_OrderTableRow>[
  _OrderTableRow(
    docId: null,
    orderId: 'ORD-1001',
    shop: 'Sharma Store',
    salesman: 'Rajesh Kumar',
    amount: 12450,
    status: 'Pending',
    orderDate: DateTime(2024, 5, 15),
    sortTime: DateTime(2024, 5, 15, 12, 0),
    productsCount: 5,
    isDraft: false,
    quantity: 58,
    notes: 'Handle fragile cartons on top rack.',
    rawProducts: const [],
  ),
  _OrderTableRow(
    docId: null,
    orderId: 'ORD-1002',
    shop: 'Gupta General Store',
    salesman: 'Sanjay Patel',
    amount: 8750,
    status: 'Approved',
    orderDate: DateTime(2024, 5, 15),
    sortTime: DateTime(2024, 5, 15, 11, 0),
    productsCount: 4,
    quantity: 44,
    isDraft: false,
    notes: 'Deliver before noon.',
    rawProducts: const [],
  ),
  _OrderTableRow(
    docId: null,
    orderId: 'ORD-1004',
    shop: 'Royal Mart',
    salesman: 'Vikram Singh',
    amount: 6410,
    status: 'In Transit',
    orderDate: DateTime(2024, 5, 14),
    sortTime: DateTime(2024, 5, 14, 18, 0),
    productsCount: 6,
    quantity: 76,
    isDraft: false,
    notes: 'Customer requested sealed packs only.',
    rawProducts: const [],
  ),
  _OrderTableRow(
    docId: null,
    orderId: 'ORD-1005',
    shop: 'City Bazaar',
    salesman: 'Amit Verma',
    amount: 15900,
    status: 'Delivered',
    orderDate: DateTime(2024, 5, 13),
    sortTime: DateTime(2024, 5, 13, 20, 0),
    productsCount: 8,
    quantity: 136,
    isDraft: false,
    notes: 'Dispatch with insurance invoice copy.',
    rawProducts: const [],
  ),
];

class _OrdersLineItem {
  const _OrdersLineItem({
    required this.name,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String name;
  final String sku;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
}

class _CustomerProfile {
  const _CustomerProfile({
    required this.id,
    required this.companyName,
    required this.ownerName,
    required this.mobile,
    required this.email,
    required this.gstin,
    required this.region,
    required this.address,
  });

  final String id;
  final String companyName;
  final String ownerName;
  final String mobile;
  final String email;
  final String gstin;
  final String region;
  final String address;

  factory _CustomerProfile.fromMap(Map<String, dynamic> data) {
    return _CustomerProfile(
      id: (data['id'] ?? '').toString(),

      companyName:
          (data['company_name'] ??
                  data['companyName'] ??
                  data['shopName'] ??
                  data['name'] ??
                  '')
              .toString(),

      ownerName: (data['contact_person'] ?? data['ownerName'] ?? '').toString(),

      mobile: (data['mobile'] ?? '').toString(),

      email: (data['email'] ?? '').toString(),

      gstin: (data['gstin'] ?? '').toString(),

      region: (data['state'] ?? data['region'] ?? '').toString(),

      address: [
        data['address_line1'],
        data['address_line2'],
        data['city'],
        data['state'],
      ].where((e) => e != null && e.toString().isNotEmpty).join(', '),
    );
  }
}

class _CatalogItem {
  const _CatalogItem({
    required this.id,
    required this.category,
    required this.itemName,
    required this.sku,
    required this.rate,
  });

  final String id;
  final String category;
  final String itemName;
  final String sku;
  final double rate;

  factory _CatalogItem.fromMap(String id, Map<String, dynamic> data) {
    return _CatalogItem(
      id: id,
      category: (data['category'] ?? data['type'] ?? 'General').toString(),
      itemName: (data['name'] ?? data['itemName'] ?? data['title'] ?? id)
          .toString(),
      sku: (data['sku'] ?? data['code'] ?? id).toString(),
      rate: _asNum(
        data['rate'] ?? data['price'] ?? data['lastPurchaseRate'] ?? 0,
      ),
    );
  }
}

class _CreateOrderItem {
  const _CreateOrderItem({
    required this.category,
    required this.itemName,
    required this.sku,
    required this.qty,
    required this.rate,
  });

  final String category;
  final String itemName;
  final String sku;
  final double qty;
  final double rate;

  double get lineTotal => qty * rate;
}

class _DraftOrder {
  const _DraftOrder({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.salesmanName,
    required this.amount,
    required this.quantity,
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final String customerName;
  final String salesmanName;
  final double amount;
  final int quantity;
  final DateTime createdAt;

  factory _DraftOrder.fromJson(Map<String, dynamic> json) {
    return _DraftOrder(
      id: json['id'],
      orderId: json['orderId'],
      customerName: json['customerName'],
      salesmanName: json['salesmanName'],
      amount: (json['amount'] as num).toDouble(),
      quantity: (json['quantity'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class _CreateOrderDraft {
  const _CreateOrderDraft({
    required this.customer,
    required this.salesmanName,
    required this.notes,
    required this.items,
    required this.isDraft,
  });

  final _CustomerProfile customer;
  final String salesmanName;
  final String notes;
  final List<_CreateOrderItem> items;
  final bool isDraft;
}

class _CreateOrderDialog extends StatefulWidget {
  const _CreateOrderDialog({
    required this.customers,
    required this.catalog,
    this.draftData,
  });

  final List<_CustomerProfile> customers;
  final List<_CatalogItem> catalog;
  final Map<String, dynamic>? draftData;

  @override
  State<_CreateOrderDialog> createState() => _CreateOrderDialogState();
}

class _CreateOrderDialogState extends State<_CreateOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _salesmanController = TextEditingController();
  final _notesController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _freightController = TextEditingController(text: '0');
  final _otherChargesController = TextEditingController(text: '0');
  final _paymentTermsController = TextEditingController();
  final _paymentReferenceController = TextEditingController();
  final _deliveryInstructionController = TextEditingController();
  final _transportPreferenceController = TextEditingController();
  final _expectedDeliveryController = TextEditingController();
  final _attachmentReferenceController = TextEditingController();
  final _orderDateController = TextEditingController();
  final _orderIdController = TextEditingController();
  final _referenceController = TextEditingController();
  final _poNumberController = TextEditingController();
  final _poDateController = TextEditingController();
  final _shopBranchController = TextEditingController();
  final _shippingAddressController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _rateController = TextEditingController(text: '0');

  _CustomerProfile? _selectedCustomer;
  String? _selectedCategory;
  _CatalogItem? _selectedItem;
  String _orderType = 'Sales Order';
  String _priority = 'Normal';
  String? _salesRegion;
  String paymentMethod = 'Credit';
  String paymentStatus = 'Pending';
  final List<String> paymentStatusList = ['Pending', 'Partial', 'Paid'];
  DateTime? dueDate;
  final _transportNameController = TextEditingController();
  final _transportPhoneController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _lrNumberController = TextEditingController();
  final CategoryService _categoryService = CategoryService();

  DateTime? dispatchDate;
  DateTime? expectedDeliveryDate;

  final advanceController = TextEditingController();

  final creditDaysController = TextEditingController();

  final referenceController = TextEditingController();

  final remarksController = TextEditingController();

  final bankController = TextEditingController();

  final transactionController = TextEditingController();
  bool _saveAsDraft = false;
  _CreateOrderStep _activeStep = _CreateOrderStep.orderDetails;
  final ScrollController _contentScrollController = ScrollController();
  final Map<_CreateOrderStep, GlobalKey> _stepKeys = {
    _CreateOrderStep.orderDetails: GlobalKey(),
    _CreateOrderStep.customerShop: GlobalKey(),
    _CreateOrderStep.items: GlobalKey(),
    _CreateOrderStep.pricing: GlobalKey(),
    _CreateOrderStep.payment: GlobalKey(),
    _CreateOrderStep.delivery: GlobalKey(),
    _CreateOrderStep.attachments: GlobalKey(),
    _CreateOrderStep.summary: GlobalKey(),
  };
  final List<_CreateOrderItem> _items = [];

  final List<String> _orderTypes = const ['Sales Order', 'Sales Return'];
  final List<String> _regions = const [
    'North',
    'South',
    'East',
    'West',
    'Central',
  ];
  final List<String> _priorities = const ['Low', 'Normal', 'High'];
  final List<String> paymentMethodList = [
    'Cash',
    'UPI',
    'Credit',
    'Bank Transfer',
    'Cheque',
  ];
  void _loadDraft(Map<String, dynamic> draft) {
    debugPrint("LOAD DRAFT");
    debugPrint(draft.toString());

    setState(() {
      // Customer
      debugPrint("Draft shopId: ${draft["shopId"]}");

      for (final c in widget.customers) {
        debugPrint("Customer id: ${c.id}  Name: ${c.companyName}");
      }
      _selectedCustomer = widget.customers.firstWhere(
        (c) => c.id == draft["shopId"],
        orElse: () => widget.customers.first,
      );

      _shippingAddressController.text = _selectedCustomer?.address ?? "";

      // Salesman
      _salesmanController.text = draft["salesmanName"] ?? "";

      // Notes
      _notesController.text = draft["notes"] ?? "";

      // Draft checkbox
      _saveAsDraft = draft["isDraft"] ?? false;

      // Clear previous items
      _items.clear();

      // Products
      final products = List<Map<String, dynamic>>.from(draft["products"] ?? []);

      for (final p in products) {
        _items.add(
          _CreateOrderItem(
            category: p["category"] ?? "",
            itemName: p["name"] ?? "",
            sku: p["sku"] ?? "",
            qty: (p["quantity"] as num).toDouble(),
            rate: (p["unitPrice"] as num).toDouble(),
          ),
        );
      }
    });
  }

  void _recalcPricing() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _orderDateController.text = _formatDate(now);
    _orderIdController.text = _generateOrderId(now);
    _poDateController.text = _formatDate(now);
    _expectedDeliveryController.text = _formatDate(
      now.add(const Duration(days: 2)),
    );
    _discountController.addListener(_recalcPricing);
    _freightController.addListener(_recalcPricing);
    _otherChargesController.addListener(_recalcPricing);
    if (widget.draftData != null) {
      _loadDraft(widget.draftData!);
    }
    loadCategories();
  }

  @override
  void dispose() {
    _salesmanController.dispose();
    _notesController.dispose();
    _discountController.removeListener(_recalcPricing);
    _freightController.removeListener(_recalcPricing);
    _otherChargesController.removeListener(_recalcPricing);
    _discountController.dispose();
    _freightController.dispose();
    _otherChargesController.dispose();
    _paymentTermsController.dispose();
    _paymentReferenceController.dispose();
    _deliveryInstructionController.dispose();
    _transportPreferenceController.dispose();
    _expectedDeliveryController.dispose();
    _attachmentReferenceController.dispose();
    _orderDateController.dispose();
    _orderIdController.dispose();
    _referenceController.dispose();
    _poNumberController.dispose();
    _poDateController.dispose();
    _shopBranchController.dispose();
    _shippingAddressController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    _contentScrollController.dispose();
    _transportNameController.dispose();
    advanceController.dispose();
    creditDaysController.dispose();
    referenceController.dispose();
    remarksController.dispose();
    bankController.dispose();
    transactionController.dispose();
    _transportPhoneController.dispose();
    _invoiceNumberController.dispose();
    _deliveryInstructionController.dispose();
    _lrNumberController.dispose();
    super.dispose();
  }

  String _generateOrderId(DateTime now) {
    return 'AUTO-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yy = value.year.toString();
    return '$dd/$mm/$yy';
  }

  Future<void> _pickOrderDate(TextEditingController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => controller.text = _formatDate(picked));
  }

  void _selectStep(_CreateOrderStep step) {
    setState(() => _activeStep = step);
    final key = _stepKeys[step];
    final targetContext = key?.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: 0.08,
    );
  }

  List<String> _categories = [];

  Future<void> loadCategories() async {
    try {
      final data = await _categoryService.getCategories();

      print("Category Count: ${data.length}");
      print(data);

      setState(() {
        _categories = data.map((e) => e.name).toList();
      });
    } catch (e) {
      print(e);
    }
  }

  List<_CatalogItem> get _itemsForCategory {
    if (_selectedCategory == null) return const [];
    return widget.catalog.where((e) => e.category == _selectedCategory).toList()
      ..sort((a, b) => a.itemName.compareTo(b.itemName));
  }

  void _addItem() {
    if (_selectedCategory == null || _selectedItem == null) {
      AppSnackBar.warning(message: 'Choose category and item first.');
      return;
    }
    final qty = _asNum(_qtyController.text.trim());
    final rate = _asNum(_rateController.text.trim());
    if (qty <= 0 || rate < 0) {
      AppSnackBar.warning(message: 'Enter valid qty and rate.');
      return;
    }
    setState(() {
      _items.add(
        _CreateOrderItem(
          category: _selectedCategory!,
          itemName: _selectedItem!.itemName,
          sku: _selectedItem!.sku,
          qty: qty,
          rate: rate,
        ),
      );
      _qtyController.text = '1';
      _rateController.text = _selectedItem!.rate.toStringAsFixed(2);
    });
  }

  double get _grandTotal =>
      _items.fold<double>(0, (sum, item) => sum + item.lineTotal);

  double get _netTotal {
    final discount = _asNum(_discountController.text.trim());
    final freight = _asNum(_freightController.text.trim());
    final other = _asNum(_otherChargesController.text.trim());
    final value = _grandTotal - discount + freight + other;
    return value < 0 ? 0 : value;
  }

  double get advanceAmount => double.tryParse(advanceController.text) ?? 0;

  double get balanceAmount => _netTotal - advanceAmount;
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 34, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 760),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x240A1833),
              blurRadius: 28,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF0FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add New Order',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Create a new order for the customer',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 190,
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFBFF),
                        border: Border(
                          right: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          _OrderStepMenuTile(
                            label: 'Order Details',
                            icon: Icons.receipt_long_rounded,
                            selected:
                                _activeStep == _CreateOrderStep.orderDetails,
                            onTap: () =>
                                _selectStep(_CreateOrderStep.orderDetails),
                          ),
                          const SizedBox(height: 7),
                          _OrderStepMenuTile(
                            label: 'Customer & Shop',
                            icon: Icons.storefront_rounded,
                            selected:
                                _activeStep == _CreateOrderStep.customerShop,
                            onTap: () =>
                                _selectStep(_CreateOrderStep.customerShop),
                          ),
                          const SizedBox(height: 7),
                          _OrderStepMenuTile(
                            label: 'Items',
                            icon: Icons.inventory_2_rounded,
                            selected: _activeStep == _CreateOrderStep.items,
                            onTap: () => _selectStep(_CreateOrderStep.items),
                          ),
                          const SizedBox(height: 7),
                          _OrderStepMenuTile(
                            label: 'Pricing & Charges',
                            icon: Icons.sell_rounded,
                            selected: _activeStep == _CreateOrderStep.pricing,
                            onTap: () => _selectStep(_CreateOrderStep.pricing),
                          ),
                          const SizedBox(height: 7),
                          _OrderStepMenuTile(
                            label: 'Payment',
                            icon: Icons.payments_rounded,
                            selected: _activeStep == _CreateOrderStep.payment,
                            onTap: () => _selectStep(_CreateOrderStep.payment),
                          ),
                          const SizedBox(height: 7),
                          _OrderStepMenuTile(
                            label: 'Delivery & Dispatch',
                            icon: Icons.local_shipping_rounded,
                            selected: _activeStep == _CreateOrderStep.delivery,
                            onTap: () => _selectStep(_CreateOrderStep.delivery),
                          ),
                          const SizedBox(height: 7),
                          _OrderStepMenuTile(
                            label: 'Notes & Attachments',
                            icon: Icons.attach_file_rounded,
                            selected:
                                _activeStep == _CreateOrderStep.attachments,
                            onTap: () =>
                                _selectStep(_CreateOrderStep.attachments),
                          ),
                          const SizedBox(height: 7),
                          _OrderStepMenuTile(
                            label: 'Summary',
                            icon: Icons.summarize_rounded,
                            selected: _activeStep == _CreateOrderStep.summary,
                            onTap: () => _selectStep(_CreateOrderStep.summary),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _contentScrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KeyedSubtree(
                              key: _stepKeys[_CreateOrderStep.orderDetails],
                              child: const SizedBox.shrink(),
                            ),
                            Text(
                              'Order Details',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    itemHeight: 56,
                                    value: _orderType,
                                    decoration: premiumDecoration(
                                      label: 'Order Type *',
                                    ),
                                    items: _orderTypes
                                        .map(
                                          (v) => DropdownMenuItem(
                                            value: v,
                                            child: Text(v),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _orderType = value);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _salesRegion,
                                    decoration: premiumDecoration(
                                      label: 'Sales Region',
                                    ),
                                    items: _regions
                                        .map(
                                          (r) => DropdownMenuItem(
                                            value: r,
                                            child: Text(r),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() => _salesRegion = value);
                                    },
                                  ),
                                ),
                                //
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _priority,
                                    decoration: premiumDecoration(
                                      label: 'Priority',
                                    ),
                                    items: _priorities
                                        .map(
                                          (p) => DropdownMenuItem(
                                            value: p,
                                            child: Text(p),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _priority = value);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _orderIdController,
                                    readOnly: true,
                                    decoration: premiumDecoration(
                                      label: 'Order ID',
                                      hint: 'Auto Generate',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _orderDateController,
                                    readOnly: true,
                                    decoration: premiumDecoration(
                                      label: 'Order Date *',
                                      suffixIcon: IconButton(
                                        onPressed: () => _pickOrderDate(
                                          _orderDateController,
                                        ),
                                        icon: const Icon(
                                          Icons.calendar_month_rounded,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                Expanded(
                                  child: TextFormField(
                                    controller: _poDateController,
                                    readOnly: true,
                                    decoration: premiumDecoration(
                                      label: 'PO Date (Optional)',
                                      suffixIcon: IconButton(
                                        onPressed: () =>
                                            _pickOrderDate(_poDateController),
                                        icon: const Icon(
                                          Icons.calendar_month_rounded,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _salesmanController,
                                    decoration: premiumDecoration(
                                      label: 'Salesman *',
                                    ),
                                    validator: (value) =>
                                        (value ?? '').trim().isEmpty
                                        ? 'Required'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _referenceController,
                                    decoration: premiumDecoration(
                                      label: 'Reference No. (Optional)',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _poNumberController,
                                    decoration: premiumDecoration(
                                      label: 'PO Number (Optional)',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                            const SizedBox(height: 12),
                            KeyedSubtree(
                              key: _stepKeys[_CreateOrderStep.customerShop],
                              child: const SizedBox.shrink(),
                            ),
                            Text(
                              'Customer & Shop',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),

                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                print(
                                  "Widget Customer Length: ${widget.customers.length}",
                                );

                                for (final c in widget.customers) {
                                  print(
                                    "Customer => ${c.id} | ${c.companyName}",
                                  );
                                }

                                return const SizedBox.shrink();
                              },
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child:
                                      DropdownButtonFormField<_CustomerProfile>(
                                        value: _selectedCustomer,
                                        decoration: premiumDecoration(
                                          label: 'Customer *',
                                        ),
                                        items: widget.customers
                                            .map(
                                              (c) =>
                                                  DropdownMenuItem<
                                                    _CustomerProfile
                                                  >(
                                                    value: c,
                                                    child: Text(c.companyName),
                                                  ),
                                            )
                                            .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedCustomer = value;
                                            _shippingAddressController.text =
                                                value?.address ?? '';
                                          });
                                        },
                                        validator: (value) =>
                                            value == null ? 'Required' : null,
                                      ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _shopBranchController,
                                    decoration: premiumDecoration(
                                      label: 'Shop / Branch',
                                      hintText: 'Select shop / branch',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    readOnly: true,
                                    decoration: premiumDecoration(
                                      label: 'Billing Address',
                                      hintText:
                                          _selectedCustomer
                                                  ?.address
                                                  .isNotEmpty ==
                                              true
                                          ? _selectedCustomer!.address
                                          : 'Select customer to load address',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _shippingAddressController,
                                    decoration: premiumDecoration(
                                      label: 'Shipping Address',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _CustomerSummaryCard(customer: _selectedCustomer),
                            const SizedBox(height: 12),
                            KeyedSubtree(
                              key: _stepKeys[_CreateOrderStep.items],
                              child: const SizedBox.shrink(),
                            ),
                            Text(
                              'Items',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            _ItemPickerCard(
                              categories: _categories,
                              selectedCategory: _selectedCategory,
                              itemsForCategory: _itemsForCategory,
                              selectedItem: _selectedItem,
                              qtyController: _qtyController,
                              rateController: _rateController,
                              onCategoryChanged: (value) {
                                setState(() {
                                  _selectedCategory = value;
                                  _selectedItem = null;
                                  _rateController.text = '0';
                                });
                              },
                              onItemChanged: (value) {
                                setState(() {
                                  _selectedItem = value;
                                  _rateController.text = value == null
                                      ? '0'
                                      : value.rate.toStringAsFixed(2);
                                });
                              },
                              onAdd: _addItem,
                            ),
                            const SizedBox(height: 8),
                            _OrderItemsTable(
                              items: _items,
                              onDelete: (index) =>
                                  setState(() => _items.removeAt(index)),
                            ),
                            const SizedBox(height: 10),
                            KeyedSubtree(
                              key: _stepKeys[_CreateOrderStep.pricing],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pricing & Charges',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _discountController,
                                          keyboardType: TextInputType.number,
                                          decoration: premiumDecoration(
                                            label: 'Discount',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _freightController,
                                          keyboardType: TextInputType.number,
                                          decoration: premiumDecoration(
                                            label: 'Freight',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _otherChargesController,
                                          keyboardType: TextInputType.number,
                                          decoration: premiumDecoration(
                                            label: 'Other Charges',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FBFF),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Subtotal: ${_rupee(_grandTotal)}',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Net Total: ${_rupee(_netTotal)}',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            KeyedSubtree(
                              key: _stepKeys[_CreateOrderStep.payment],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payment Information',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),

                                  const SizedBox(height: 15),

                                  paymentSection(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            KeyedSubtree(
                              key: _stepKeys[_CreateOrderStep.delivery],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Delivery & Dispatch',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 12),
                                  deliverySection(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            KeyedSubtree(
                              key: _stepKeys[_CreateOrderStep.attachments],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Notes & Attachments',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _attachmentReferenceController,
                                    decoration: const InputDecoration(
                                      labelText: 'Attachment Reference',
                                      isDense: true,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _notesController,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      labelText: 'Notes',
                                      isDense: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            KeyedSubtree(
                              key: _stepKeys[_CreateOrderStep.summary],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Summary',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FBFF),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Customer: ${_selectedCustomer?.companyName ?? '-'}',
                                          style: const TextStyle(
                                            color: AppColors.text,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Items: ${_items.length} • Qty: ${_items.fold<double>(0, (sum, e) => sum + e.qty).toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Total: ${_rupee(_netTotal)}',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
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
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _saveAsDraft,
                          onChanged: (value) {
                            setState(() => _saveAsDraft = value ?? false);
                          },
                        ),
                        const Text(
                          'Save as draft',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) {
                          _selectStep(_CreateOrderStep.orderDetails);
                          AppSnackBar.warning(
                            message:
                                'Fill required fields in Order Details first.',
                          );
                          return;
                        }
                        if (_selectedCustomer == null || _items.isEmpty) {
                          _selectStep(
                            _selectedCustomer == null
                                ? _CreateOrderStep.customerShop
                                : _CreateOrderStep.items,
                          );
                          AppSnackBar.warning(
                            message:
                                'Select customer and add at least one item.',
                          );
                          return;
                        }
                        Navigator.of(context).pop(
                          _CreateOrderDraft(
                            customer: _selectedCustomer!,
                            salesmanName: _salesmanController.text.trim(),
                            notes: _notesController.text.trim(),
                            items: List<_CreateOrderItem>.from(_items),
                            isDraft: _saveAsDraft,
                          ),
                        );
                      },
                      icon: const Icon(Icons.save_rounded, size: 16),
                      label: const Text('Create Order'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget paymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: paymentStatus,
                decoration: const InputDecoration(
                  labelText: "Payment Status",
                  isDense: true,
                ),
                items: paymentStatusList
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => paymentStatus = v);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: const InputDecoration(
                  labelText: "Payment Method",
                  isDense: true,
                ),
                items: paymentMethodList
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => paymentMethod = v);
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
                controller: advanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Advance Amount",
                  prefixText: "₹ ",
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: "Reference Number",
                  isDense: true,
                ),
              ),
            ),
          ],
        ),

        if (paymentMethod == "Credit") ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: creditDaysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Credit Days",
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    dueDate == null
                        ? "Select Due Date"
                        : "${dueDate!.day}/${dueDate!.month}/${dueDate!.year}",
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dueDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );

                    if (picked != null) {
                      setState(() => dueDate = picked);
                    }
                  },
                ),
              ),
            ],
          ),
        ],

        if (paymentMethod == "Bank Transfer" || paymentMethod == "Cheque") ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: bankController,
            decoration: const InputDecoration(
              labelText: "Bank Name",
              isDense: true,
            ),
          ),
        ],

        if (paymentMethod == "UPI" || paymentMethod == "Bank Transfer") ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: transactionController,
            decoration: const InputDecoration(
              labelText: "Transaction ID",
              isDense: true,
            ),
          ),
        ],

        const SizedBox(height: 10),

        TextFormField(
          controller: remarksController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: "Remarks",
            isDense: true,
          ),
        ),

        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              summaryRow("Order Total", "₹ ${_netTotal.toStringAsFixed(2)}"),
              const Divider(height: 18),
              summaryRow("Advance", "₹ ${advanceAmount.toStringAsFixed(2)}"),
              const Divider(height: 18),
              summaryRow("Balance", "₹ ${balanceAmount.toStringAsFixed(2)}"),
              const Divider(height: 18),
              summaryRow("Payment Status", paymentStatus),
            ],
          ),
        ),
      ],
    );
  }

  Future<DateTime?> _showPremiumDatePicker(DateTime? selectedDate) async {
    return await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xff2563EB),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Widget deliverySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _transportNameController,
                decoration: const InputDecoration(
                  labelText: 'Transport Company *',
                  isDense: true,
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: TextFormField(
                controller: _transportPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Transport Contact No.',
                  isDense: true,
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _invoiceNumberController,
                decoration: const InputDecoration(
                  labelText: 'Invoice Number',
                  isDense: true,
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: TextFormField(
                controller: _lrNumberController,
                decoration: const InputDecoration(
                  labelText: 'LR / Consignment No.',
                  isDense: true,
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: buildDateField(
                label: "Dispatch Date",
                value: dispatchDate,
                onTap: () async {
                  final picked = await _showPremiumDatePicker(
                    expectedDeliveryDate,
                  );

                  if (picked != null) {
                    setState(() => dispatchDate = picked);
                  }
                },
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: buildDateField(
                label: "Expected Delivery",
                value: expectedDeliveryDate,
                onTap: () async {
                  final picked = await _showPremiumDatePicker(
                    expectedDeliveryDate,
                  );

                  if (picked != null) {
                    setState(() => expectedDeliveryDate = picked);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: _deliveryInstructionController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Delivery Instructions',
            isDense: true,
            prefixIcon: Icon(Icons.notes_outlined),
            alignLabelWithHint: true,
          ),
        ),

        const SizedBox(height: 18),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xffF8FBFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              summaryRow(
                "Transport",
                _transportNameController.text.isEmpty
                    ? "-"
                    : _transportNameController.text,
              ),

              const Divider(),

              summaryRow(
                "Invoice",
                _invoiceNumberController.text.isEmpty
                    ? "-"
                    : _invoiceNumberController.text,
              ),

              const Divider(),

              summaryRow(
                "Dispatch",
                dispatchDate == null
                    ? "-"
                    : DateFormat('dd MMM yyyy').format(dispatchDate!),
              ),

              const Divider(),

              summaryRow(
                "Expected Delivery",
                expectedDeliveryDate == null
                    ? "-"
                    : DateFormat('dd MMM yyyy').format(expectedDeliveryDate!),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          suffixIcon: const Icon(Icons.arrow_drop_down, size: 20),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
        child: Text(
          value == null ? "Select Date" : _formatDate(value),
          style: TextStyle(
            fontSize: 13,
            color: value == null ? Colors.grey.shade600 : AppColors.text,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget summaryRow(String title, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _OrderStepMenuTile extends StatelessWidget {
  const _OrderStepMenuTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF4FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFFC5D7FF) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.text,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CreateOrderStep {
  orderDetails,
  customerShop,
  items,
  pricing,
  payment,
  delivery,
  attachments,
  summary,
}

class _CustomerSummaryCard extends StatelessWidget {
  const _CustomerSummaryCard({required this.customer});

  final _CustomerProfile? customer;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: c == null
          ? const Text(
              'Choose a company to auto-fill customer details.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            )
          : Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _kv('Owner', c.ownerName),
                _kv('Mobile', c.mobile),
                _kv('Email', c.email),
                _kv('GSTIN', c.gstin),
                _kv('Region', c.region),
                _kv('Address', c.address),
              ],
            ),
    );
  }

  Widget _kv(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: AppColors.text, fontSize: 12),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value.isEmpty ? '-' : value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ItemPickerCard extends StatelessWidget {
  const _ItemPickerCard({
    required this.categories,
    required this.selectedCategory,
    required this.itemsForCategory,
    required this.selectedItem,
    required this.qtyController,
    required this.rateController,
    required this.onCategoryChanged,
    required this.onItemChanged,
    required this.onAdd,
  });

  final List<String> categories;
  final String? selectedCategory;
  final List<_CatalogItem> itemsForCategory;
  final _CatalogItem? selectedItem;
  final TextEditingController qtyController;
  final TextEditingController rateController;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<_CatalogItem?> onItemChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    isDense: true,
                  ),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: onCategoryChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<_CatalogItem>(
                  value: selectedItem,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    isDense: true,
                  ),
                  items: itemsForCategory
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.itemName),
                        ),
                      )
                      .toList(),
                  onChanged: onItemChanged,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 86,
                child: TextFormField(
                  controller: qtyController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Qty',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: rateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Rate',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Item'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderItemsTable extends StatelessWidget {
  const _OrderItemsTable({required this.items, required this.onDelete});

  final List<_CreateOrderItem> items;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F8FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 16, child: Text('Category')),
                Expanded(flex: 24, child: Text('Item Name')),
                Expanded(flex: 12, child: Text('SKU')),
                Expanded(flex: 8, child: Text('Qty')),
                Expanded(flex: 10, child: Text('Rate')),
                Expanded(flex: 14, child: Text('Total')),
                Expanded(flex: 8, child: Text('Action')),
              ],
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No items added yet.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            )
          else
            Column(
              children: List.generate(items.length, (index) {
                final item = items[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 16, child: Text(item.category)),
                      Expanded(flex: 24, child: Text(item.itemName)),
                      Expanded(flex: 12, child: Text(item.sku)),
                      Expanded(
                        flex: 8,
                        child: Text(item.qty.toStringAsFixed(2)),
                      ),
                      Expanded(flex: 10, child: Text(_rupee(item.rate))),
                      Expanded(
                        flex: 14,
                        child: Text(
                          _rupee(item.lineTotal),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        flex: 8,
                        child: IconButton(
                          onPressed: () => onDelete(index),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _BadgeCell extends StatelessWidget {
  const _BadgeCell(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: StatusBadge(label: label, color: color, compact: true),
    );
  }
}

class _ActionCell extends StatelessWidget {
  const _ActionCell({this.compact = false, this.onTap});

  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(Icons.visibility_outlined, size: compact ? 16 : 18),
          ),
        ),
      ],
    );
  }
}

class _ScrollableTableTextCell extends StatelessWidget {
  const _ScrollableTableTextCell(this.title, {this.compact = false});

  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text(
        title,
        maxLines: 1,
        softWrap: false,
        style:
            (compact
                    ? Theme.of(context).textTheme.bodyMedium
                    : Theme.of(context).textTheme.bodyLarge)
                ?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 12.5 : null,
                ),
      ),
    );
  }
}

pw.Widget _pdfHeaderCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromHex('#2C4167'),
      ),
    ),
  );
}

pw.Widget _pdfBodyCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(
      text,
      textAlign: align,
      style: const pw.TextStyle(fontSize: 9),
      maxLines: 2,
    ),
  );
}

pw.Widget _pdfTotalRow(String label, String value, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColor.fromHex('#2C4167'),
            ),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: bold ? 11 : 9.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}

/// Builds the customer-facing A4 tax invoice used by the print preview.
/// Company master data can later replace the address/bank placeholders below.
pw.Document _buildProfessionalInvoice({
  required _OrderTableRow order,
  required List<_OrdersLineItem> items,
  required String invoiceNo,
  required double taxableValue,
  required double taxAmount,
  required double totalQty,
}) {
  final navy = PdfColor.fromHex('#12377D');
  final blue = PdfColor.fromHex('#1665D8');
  final paleBlue = PdfColor.fromHex('#F2F7FF');
  final border = PdfColor.fromHex('#D6E2F5');
  final muted = PdfColor.fromHex('#63708A');
  const taxRate = 18.0;
  final cgst = taxAmount / 2;
  final dueDate = order.orderDate.add(const Duration(days: 15));

  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 22),
      footer: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 14),
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: border)),
        ),
        child: pw.Column(
          children: [
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 180,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(height: 0.8, color: navy),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Authorized Signatory',
                      style: pw.TextStyle(
                        color: navy,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Warehouse Pvt. Ltd.',
                      style: pw.TextStyle(color: muted, fontSize: 8),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(
                    color: navy,
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'This is a computer-generated invoice.',
                  style: pw.TextStyle(color: muted, fontSize: 8),
                ),
              ],
            ),
          ],
        ),
      ),
      build: (context) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(color: border),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 46,
                height: 46,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: blue,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'S',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 27,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Warehouse',
                      style: pw.TextStyle(
                        color: navy,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'FIELD SALES & DISTRIBUTION',
                      style: pw.TextStyle(
                        color: blue,
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Stock. Store. Deliver.\nChennai, Tamil Nadu, India  |  +91 98765 43210\naccounts@saleserp.in  |  www.saleserp.in',
                      style: pw.TextStyle(
                        color: muted,
                        fontSize: 8.3,
                        lineSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(width: 0.8, height: 105, color: border),
              pw.SizedBox(width: 16),
              pw.SizedBox(
                width: 165,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'TAX INVOICE',
                      style: pw.TextStyle(
                        color: navy,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 7),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: pw.BoxDecoration(
                        color: blue,
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Text(
                        invoiceNo,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    _invoiceKeyValue(
                      'Invoice date',
                      _invoiceDate(order.orderDate),
                      muted,
                    ),
                    _invoiceKeyValue('Due date', _invoiceDate(dueDate), muted),
                    _invoiceKeyValue('Order / PO no.', order.orderId, muted),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _invoiceInfoCard(
                title: 'BILL TO',
                accent: blue,
                border: border,
                children: [
                  _invoiceStrong(order.shop, navy),
                  _invoiceText('Customer address as per order record', muted),
                  _invoiceText('Sales contact: ${order.salesman}', muted),
                  _invoiceText('GSTIN: Not provided', muted),
                ],
              ),
            ),
            pw.SizedBox(width: 9),
            pw.Expanded(
              child: _invoiceInfoCard(
                title: 'SHIP TO',
                accent: PdfColor.fromHex('#0A9E68'),
                border: border,
                children: [
                  _invoiceStrong(order.shop, navy),
                  _invoiceText('Delivery address as per order record', muted),
                  _invoiceText('Dispatch status: ${order.status}', muted),
                  _invoiceText('Delivery mode: Standard dispatch', muted),
                ],
              ),
            ),
            pw.SizedBox(width: 9),
            pw.Expanded(
              child: _invoiceInfoCard(
                title: 'INVOICE DETAILS',
                accent: PdfColor.fromHex('#D88A00'),
                border: border,
                children: [
                  _invoiceText('Invoice type: Sales', muted),
                  _invoiceText('Payment terms: Net 15 days', muted),
                  _invoiceText('Currency: INR', muted),
                  _invoiceText('Sales executive: ${order.salesman}', muted),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Table(
          border: pw.TableBorder.all(color: border, width: 0.7),
          columnWidths: {
            0: const pw.FlexColumnWidth(0.48),
            1: const pw.FlexColumnWidth(1.12),
            2: const pw.FlexColumnWidth(2.25),
            3: const pw.FlexColumnWidth(0.72),
            4: const pw.FlexColumnWidth(0.8),
            5: const pw.FlexColumnWidth(1.08),
            6: const pw.FlexColumnWidth(0.7),
            7: const pw.FlexColumnWidth(1.2),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: navy),
              children: [
                '#',
                'ITEM CODE',
                'ITEM DESCRIPTION',
                'UOM',
                'QTY',
                'UNIT PRICE',
                'TAX',
                'AMOUNT',
              ].map(_professionalInvoiceHeaderCell).toList(),
            ),
            ...items.asMap().entries.map((entry) {
              final item = entry.value;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: entry.key.isEven ? PdfColors.white : paleBlue,
                ),
                children:
                    [
                      '${entry.key + 1}',
                      item.sku.isEmpty ? '-' : item.sku,
                      item.name,
                      'PCS',
                      item.quantity.toStringAsFixed(2),
                      _invoiceMoney(item.unitPrice),
                      '${taxRate.toStringAsFixed(0)}%',
                      _invoiceMoney(item.lineTotal),
                    ].asMap().entries.map((cell) {
                      final align = cell.key == 2
                          ? pw.TextAlign.left
                          : cell.key == 5 || cell.key == 7
                          ? pw.TextAlign.right
                          : pw.TextAlign.center;
                      return _professionalInvoiceBodyCell(
                        cell.value,
                        align: align,
                      );
                    }).toList(),
              );
            }),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _invoiceInfoCard(
                    title: 'NOTES & TERMS',
                    accent: navy,
                    border: border,
                    children: [
                      _invoiceText(
                        order.notes.isEmpty
                            ? 'Goods once sold will not be taken back.'
                            : order.notes,
                        muted,
                      ),
                      _invoiceText(
                        'Please inspect goods at the time of delivery.',
                        muted,
                      ),
                      _invoiceText(
                        'Payment is due within 15 days of invoice date.',
                        muted,
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 9),
                  _invoiceInfoCard(
                    title: 'BANK DETAILS',
                    accent: blue,
                    border: border,
                    children: [
                      _invoiceText(
                        'Bank: HDFC Bank  |  A/c Name: Warehouse Pvt. Ltd.',
                        muted,
                      ),
                      _invoiceText(
                        'Account no.: 50200012345678  |  IFSC: HDFC0001234',
                        muted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 14),
            pw.SizedBox(
              width: 230,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(13),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: border),
                ),
                child: pw.Column(
                  children: [
                    _professionalTotalRow(
                      'Sub total',
                      _invoiceMoney(
                        items.fold<double>(
                          0,
                          (sum, item) => sum + item.lineTotal,
                        ),
                      ),
                      muted,
                    ),
                    _professionalTotalRow(
                      'Taxable amount',
                      _invoiceMoney(taxableValue),
                      muted,
                    ),
                    _professionalTotalRow(
                      'CGST (9%)',
                      _invoiceMoney(cgst),
                      muted,
                    ),
                    _professionalTotalRow(
                      'SGST (9%)',
                      _invoiceMoney(cgst),
                      muted,
                    ),
                    pw.Divider(color: border),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 7,
                        horizontal: 8,
                      ),
                      color: paleBlue,
                      child: _professionalTotalRow(
                        'TOTAL AMOUNT',
                        _invoiceMoney(order.amount),
                        navy,
                        bold: true,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Amount in words',
                        style: pw.TextStyle(
                          color: navy,
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Indian Rupees ${_amountInWords(order.amount)} only',
                        style: pw.TextStyle(color: muted, fontSize: 8.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return document;
}

pw.Widget _invoiceInfoCard({
  required String title,
  required PdfColor accent,
  required PdfColor border,
  required List<pw.Widget> children,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(11),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(8),
      border: pw.Border.all(color: border),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            color: accent,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 7),
        ...children.expand((child) => [child, pw.SizedBox(height: 3)]),
      ],
    ),
  );
}

pw.Widget _invoiceStrong(String text, PdfColor color) => pw.Text(
  text,
  style: pw.TextStyle(
    color: color,
    fontSize: 11,
    fontWeight: pw.FontWeight.bold,
  ),
);

pw.Widget _invoiceText(String text, PdfColor color) =>
    pw.Text(text, style: pw.TextStyle(color: color, fontSize: 8.2));

pw.Widget _invoiceKeyValue(String label, String value, PdfColor muted) =>
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(color: muted, fontSize: 7.8)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 8.2)),
        ],
      ),
    );

pw.Widget _professionalInvoiceHeaderCell(String text) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 7),
  child: pw.Text(
    text,
    textAlign: pw.TextAlign.center,
    style: pw.TextStyle(
      color: PdfColors.white,
      fontSize: 7.2,
      fontWeight: pw.FontWeight.bold,
    ),
  ),
);

pw.Widget _professionalInvoiceBodyCell(
  String text, {
  required pw.TextAlign align,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 7),
  child: pw.Text(
    text,
    textAlign: align,
    maxLines: 2,
    style: const pw.TextStyle(fontSize: 8.3),
  ),
);

pw.Widget _professionalTotalRow(
  String label,
  String value,
  PdfColor color, {
  bool bold = false,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 3),
  child: pw.Row(
    children: [
      pw.Expanded(
        child: pw.Text(
          label,
          style: pw.TextStyle(
            color: color,
            fontSize: bold ? 10 : 8.6,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(
          color: color,
          fontSize: bold ? 12 : 8.6,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    ],
  ),
);

String _invoiceMoney(double value) => 'Rs. ${value.toStringAsFixed(2)}';

String _invoiceDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.year}';

String _amountInWords(double amount) {
  final value = amount.round();
  if (value == 0) return 'Zero';
  if (value >= 10000000)
    return '${(value / 10000000).toStringAsFixed(2)} crore';
  if (value >= 100000) return '${(value / 100000).toStringAsFixed(2)} lakh';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)} thousand';
  return value.toString();
}

class _OrdersOrderDetailsDialog extends StatelessWidget {
  const _OrdersOrderDetailsDialog({
    required this.order,
    required this.onApprove,
    required this.onReject,
    required this.onExportInvoice,
  });

  final _OrderTableRow order;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final Future<void> Function() onExportInvoice;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    final items = order.productsForDialog;
    final statusColor = _statusColor(order.status);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.white,
          boxShadow: const [
            BoxShadow(
              color: Color(0x2A102A62),
              blurRadius: 46,
              offset: Offset(0, 24),
            ),
            BoxShadow(
              color: Color(0x14102A62),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 880, maxHeight: maxHeight),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- Header ----------
                Container(
                  padding: const EdgeInsets.fromLTRB(26, 22, 20, 22),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFF0E2557), Color(0xFF1D56C3)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Order Details',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 21,
                                      ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: Colors.white.withValues(alpha: 0.16),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.28,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF4ADE80),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Live Order',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.orderId,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
                // ---------- Body ----------
                Flexible(
                  child: Container(
                    color: const Color(0xFFF7F9FD),
                    padding: const EdgeInsets.fromLTRB(26, 20, 26, 6),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _OrdersMetaGrid(
                            order: order,
                            statusColor: statusColor,
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Text(
                                'Items',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1B2B4B),
                                    ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE9EFFC),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${items.length}',
                                  style: const TextStyle(
                                    color: Color(0xFF1D56C3),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _OrdersItemsTable(items: items),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                // ---------- Footer / Actions ----------
                Container(
                  padding: const EdgeInsets.fromLTRB(26, 16, 26, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE7ECF6))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onReject,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFF3C4C4)),
                            backgroundColor: const Color(0xFFFFF6F6),
                            minimumSize: const Size(0, 48),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onApprove,
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Approve'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            minimumSize: const Size(0, 48),
                            elevation: 0,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: onExportInvoice,
                          icon: const Icon(Icons.print_outlined, size: 18),
                          label: const Text('Preview & Print Invoice'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1D56C3),
                            minimumSize: const Size(0, 48),
                            elevation: 0,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
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
      ),
    );
  }
}

class _OrdersMetaGrid extends StatelessWidget {
  const _OrdersMetaGrid({required this.order, required this.statusColor});

  final _OrderTableRow order;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final columnWidth = compact
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: columnWidth,
              child: _OrdersMetaItem(
                icon: Icons.tag_rounded,
                label: 'Order ID',
                value: order.orderId,
              ),
            ),
            SizedBox(
              width: columnWidth,
              child: _OrdersMetaItem(
                icon: Icons.storefront_rounded,
                label: 'Shop Information',
                value: order.shop,
              ),
            ),
            SizedBox(
              width: columnWidth,
              child: _OrdersMetaItem(
                icon: Icons.badge_outlined,
                label: 'Salesman Information',
                value: order.salesman,
              ),
            ),
            SizedBox(
              width: columnWidth,
              child: _OrdersMetaItem(
                icon: Icons.event_rounded,
                label: 'Order Date',
                value: order.dateText,
              ),
            ),
            SizedBox(
              width: columnWidth,
              child: _OrdersMetaItem(
                icon: Icons.local_shipping_outlined,
                label: 'Status',
                value: order.status,
                accentColor: statusColor,
                isStatus: true,
              ),
            ),
            SizedBox(
              width: columnWidth,
              child: _OrdersMetaItem(
                icon: Icons.currency_rupee_rounded,
                label: 'Amount',
                value: _rupee(order.amount),
                highlight: true,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrdersMetaItem extends StatelessWidget {
  const _OrdersMetaItem({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
    this.isStatus = false,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  final bool isStatus;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? const Color(0xFF1D56C3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? const Color(0xFFBBD3FF) : const Color(0xFFE7ECF6),
          width: highlight ? 1.4 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08102A62),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (highlight ? const Color(0xFF1D56C3) : accent).withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 17,
              color: highlight ? const Color(0xFF1D56C3) : accent,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8592AB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                isStatus
                    ? Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      )
                    : Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: highlight ? 16 : 13.5,
                          fontWeight: FontWeight.w800,
                          color: highlight
                              ? const Color(0xFF1D56C3)
                              : const Color(0xFF1B2B4B),
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

InputDecoration premiumDecoration({
  required String label,
  String? hint,
  Widget? suffixIcon,
  String? hintText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffixIcon,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
  );
}

class _OrdersItemsTable extends StatelessWidget {
  const _OrdersItemsTable({required this.items});

  final List<_OrdersLineItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7ECF6)),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Color(0x08102A62),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF4F7FE),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 36,
                    child: Text(
                      'Product',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: Color(0xFF6C7A94),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 16,
                    child: Text(
                      'SKU',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: Color(0xFF6C7A94),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 16,
                    child: Text(
                      'Qty',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: Color(0xFF6C7A94),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 16,
                    child: Text(
                      'Price',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: Color(0xFF6C7A94),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 16,
                    child: Text(
                      'Total',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: Color(0xFF6C7A94),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: Scrollbar(
              thumbVisibility: items.length > 5,
              child: SingleChildScrollView(
                child: Column(
                  children: items.asMap().entries.map((entry) {
                    final isLast = entry.key == items.length - 1;
                    return Container(
                      decoration: BoxDecoration(
                        color: entry.key.isEven
                            ? Colors.white
                            : const Color(0xFFFAFBFF),
                        border: isLast
                            ? null
                            : const Border(
                                bottom: BorderSide(color: Color(0xFFF0F3FA)),
                              ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 36,
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF1D56C3,
                                    ).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 14,
                                    color: Color(0xFF1D56C3),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    entry.value.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Color(0xFF1B2B4B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 16,
                            child: Text(
                              entry.value.sku,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF6C7A94),
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 16,
                            child: Text(
                              entry.value.quantity.toStringAsFixed(0),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 16,
                            child: Text(
                              _rupee(entry.value.unitPrice),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 16,
                            child: Text(
                              _rupee(entry.value.lineTotal),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Color(0xFF1B2B4B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF4F7FE),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Text(
                  'Order Total',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: Color(0xFF6C7A94),
                  ),
                ),
                const Spacer(),
                Text(
                  _rupee(items.fold<double>(0, (sum, i) => sum + i.lineTotal)),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF1D56C3),
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

String _normalizeStatus(String raw) {
  final value = raw.toLowerCase();
  if (value.contains('pending') || value.contains('new')) return 'Pending';
  if (value.contains('process') || value.contains('approve')) return 'Approved';
  if (value.contains('ready')) return 'Ready to Dispatch';
  if (value.contains('transit') || value.contains('dispatch'))
    return 'In Transit';
  if (value.contains('deliver')) return 'Delivered';
  if (value.contains('reject')) return 'Rejected';
  return 'Pending';
}

Color _statusColor(String status) {
  switch (status) {
    case 'Pending':
      return const Color(0xFFFFB547);
    case 'Approved':
      return const Color(0xFF22C55E);
    case 'Ready to Dispatch':
      return const Color(0xFF0EA5E9);
    case 'In Transit':
      return const Color(0xFF6C7AFF);
    case 'Delivered':
      return const Color(0xFF22C55E);
    case 'Rejected':
      return AppColors.danger;
    default:
      return AppColors.textMuted;
  }
}

double _asNum(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _rupee(double value) {
  final rounded = value.round().toString();
  final chars = rounded.split('').reversed.toList();
  final out = <String>[];
  for (var i = 0; i < chars.length; i++) {
    if (i == 3 || (i > 3 && (i - 3) % 2 == 0)) {
      out.add(',');
    }
    out.add(chars[i]);
  }
  return '₹ ${out.reversed.join()}';
}

enum _OrdersDateFilter { all, today, last7Days, thisMonth, custom }
