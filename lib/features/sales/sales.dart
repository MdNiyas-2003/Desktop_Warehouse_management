
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _ResetBillIntent extends Intent {
  const _ResetBillIntent();
}

class CounterBillingScreen extends StatefulWidget {
  const CounterBillingScreen({super.key});

  @override
  State<CounterBillingScreen> createState() => _CounterBillingScreenState();
}

class _CounterBillingScreenState extends State<CounterBillingScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color navy = Color(0xFF082D68);
  static const Color blue = Color(0xFF1167E8);
  static const Color headerBlue = Color(0xFFDDEEFF);
  static const Color tableBlue = Color(0xFF28567F);
  static const Color border = Color(0xFFD4DEE8);
  static const Color green = Color(0xFF159447);
  static const Color red = Color(0xFFE52D2D);
  static const Color pageBg = Color(0xFFF4F7FB);

  // ============================================================
  // BILL FIELDS
  // ============================================================
  final mobileController =
      TextEditingController(text: '9829500343');
  final customerController =
      TextEditingController(text: 'RISHI ACHARYA');
  final addressController =
      TextEditingController(text: 'BIKANER');

  final billNoController =
      TextEditingController(text: '2');


  final discountController =
      TextEditingController(text: '10');


  final receivedController =
      TextEditingController();
  final cardController =
      TextEditingController();
  final upiController =
      TextEditingController();
  final FocusNode _cardFocusNode = FocusNode();
  final FocusNode _upiFocusNode = FocusNode();
  final FocusNode _receivedFocusNode = FocusNode();
  final FocusNode _discountFocusNode = FocusNode();

  final givenByController =
      TextEditingController();

  // ============================================================
  // ITEM ENTRY FIELDS
  // ============================================================

  final itemCodeController = TextEditingController();
  final itemNameController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final rateController = TextEditingController();
  final amountController = TextEditingController();
  final FocusNode _mobileFocus = FocusNode();
  final FocusNode _customerFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _itemCodeFocus = FocusNode();
  final FocusNode _itemNameFocus = FocusNode();
  final FocusNode _qtyFocus = FocusNode();
  final FocusNode _rateFocus = FocusNode();

  // ============================================================
  // OPTIONS
  // ============================================================

  String salesman = 'Select Salesman...';
  String invoiceType = 'Sale Invoice';
  String unit = 'PCS';
  String discountReason = 'Select Reason';

  bool discountEnabled = true;

  // ============================================================
  // ITEMS
  // ============================================================

  final List<Map<String, dynamic>> items = [
    {
      'code': '434',
      'name': 'PATANJALI COW GHEE 500ML',
      'qty': 1,
      'unit': 'PCS',
      'rate': 286.15,
    },
    {
      'code': '435',
      'name': 'PATANJALI COW GHEE 200ML',
      'qty': 1,
      'unit': 'PCS',
      'rate': 121.25,
    },
    {
      'code': '464',
      'name': 'Appy FIZZ 1000ml',
      'qty': 1,
      'unit': 'PCS',
      'rate': 56.26,
    },
    {
      'code': '322',
      'name': 'PATANJALI DW BAR 175G',
      'qty': 1,
      'unit': 'PCS',
      'rate': 9.70,
    },
    {
      'code': '466',
      'name': 'Appy FIZZ 600ml',
      'qty': 1,
      'unit': 'PCS',
      'rate': 32.01,
    },
  ];

  // ============================================================
  // CALCULATIONS
  // ============================================================

  double get subtotal {
    return items.fold<double>(
      0,
      (sum, item) =>
          sum +
          ((item['qty'] as num).toDouble() *
              (item['rate'] as num).toDouble()),
    );
  }

  double get gst {
    // GST is 5% of subtotal.
    return subtotal * 0.05;
  }


  double get discount {
    if (!discountEnabled) return 0;

    final percentage =
        double.tryParse(discountController.text) ?? 0;

    return subtotal * percentage / 100;
  }


  double get amountBeforeRoundOff {
    return subtotal + gst - discount;
  }

  double get roundOff {
    return amountBeforeRoundOff.roundToDouble() - amountBeforeRoundOff;
  }

  double get total {
    return amountBeforeRoundOff + roundOff;
  }

  int get totalQty {
    return items.fold<int>(
      0,
      (sum, item) => sum + (item['qty'] as num).toInt(),
    );
  }

  double get received {
    final cash = double.tryParse(receivedController.text) ?? 0;
    final card = double.tryParse(cardController.text) ?? 0;
    final upi = double.tryParse(upiController.text) ?? 0;
    return cash + card + upi;
  }


  double get balanceAmount {
    return received - total;
  }

  String money(double value) => value.toStringAsFixed(2);

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.f8): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.f10): const _ResetBillIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (intent) {
                _saveBill();
                return null;
              },
            ),
            _ResetBillIntent: CallbackAction<_ResetBillIntent>(
              onInvoke: (intent) {
                _resetBill();
                return null;
              },
            ),
          },
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    _titleBar(),
                    Expanded(
                      child: Column(
                        children: [
                          _customerSection(),
                          Expanded(
                            child: _itemsTable(),
                          ),
                          _bottomSection(),
                        ],
                      ),
                    ),
                    _footer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TITLE
  // ============================================================

  Widget _titleBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: headerBlue,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(6),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.point_of_sale,
            color: blue,
            size: 23,
          ),
          const SizedBox(width: 8),
          const Text(
            'Counter Billing',
            style: TextStyle(
              color: navy,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '( Bill Amount : ₹ ${money(total)} )',
            style: const TextStyle(
              color: navy,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CUSTOMER / BILL DETAILS
  // All fields use the same compact field style.
  // ============================================================

  Widget _customerSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              children: [
                _fieldRow(
                  Icons.phone_outlined,
                  'Mobile No.',
                  mobileController,
                  focusNode: _mobileFocus,
                  nextFocus: _customerFocus,
                ),
                _space(7),
                _fieldRow(
                  Icons.groups_outlined,
                  'Customer',
                  customerController,
                  search: true,
                  focusNode: _customerFocus,
                  nextFocus: _addressFocus,
                ),
                _space(7),
                _fieldRow(
                  Icons.location_on_outlined,
                  'Address',
                  addressController,
                  focusNode: _addressFocus,
                ),
              ],
            ),
          ),
          _verticalDivider(),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                _dropdownRow(
                  Icons.person_add_alt_1_outlined,
                  'Salesman',
                  salesman,
                  [
                    'Select Salesman...',
                    'Salesman 1',
                    'Salesman 2',
                    'Salesman 3',
                  ],
                  (value) {
                    if (value != null) {
                      setState(() => salesman = value);
                    }
                  },
                ),
                _space(7),
                _fieldDropdownRow(
                  Icons.local_offer_outlined,
                  'Discount',
                  discountReason,
                  [
                    'Select Reason',
                    'Customer Discount',
                    'Festival Offer',
                    'Special Discount',
                  ],
                  (value) {
                    if (value != null) {
                      setState(() => discountReason = value);
                    }
                  },
                ),
                _space(7),
                _fieldRow(
                  Icons.person_outline,
                  'Given By',
                  givenByController,
                ),
              ],
            ),
          ),
          _verticalDivider(),
          Expanded(
            flex: 5,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _dropdownRow(
                        Icons.description_outlined,
                        'Type',
                        invoiceType,
                        [
                          'Sale Invoice',
                          'Return Invoice',
                          'Quotation',
                        ],
                        (value) {
                          if (value != null) {
                            setState(() => invoiceType = value);
                          }
                        },
                      ),
                      _space(7),
                      _dateRow(),
                      _space(7),
                      _fieldRow(
                        Icons.description_outlined,
                        'Bill No.',
                        billNoController,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _netAmount(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _space([double height = 5]) {
    return SizedBox(height: height);
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 125,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: border,
    );
  }

  // ============================================================
  // COMMON FIELD
  // ============================================================

  Widget _fieldRow(
    IconData icon,
    String label,
    TextEditingController controller, {
    bool search = false,
    FocusNode? focusNode,
    FocusNode? nextFocus,
  }) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: navy,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF17213B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onSubmitted: (_) {
                if (nextFocus != null) {
                  FocusScope.of(context).requestFocus(nextFocus);
                } else {
                  FocusScope.of(context).unfocus();
                }
              },
              textInputAction:
                  nextFocus != null ? TextInputAction.next : TextInputAction.done,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF17213B),
              ),
              decoration: _inputDecoration(
                search: search,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    bool search = false,
  }) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      suffixIcon: search
          ? const Icon(
              Icons.search,
              size: 18,
              color: navy,
            )
          : null,
      suffixIconConstraints: const BoxConstraints(
        minWidth: 30,
        minHeight: 28,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(
          color: border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(
          color: border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(
          color: blue,
        ),
      ),
    );
  }

  // ============================================================
  // DROPDOWN
  // ============================================================

  Widget _membershipStyleDropdown({
    bool compact = false,
    required String value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.maxWidth;

        return SizedBox(
          height: compact ? 34 : 32,
          child: MenuAnchor(
            // Keep the popup directly below the field without changing
            // the size/position of the surrounding layout.
            alignmentOffset: const Offset(0, 4),
            style: MenuStyle(
              backgroundColor: const WidgetStatePropertyAll(Colors.white),
              elevation: const WidgetStatePropertyAll(6),
              surfaceTintColor:
                  const WidgetStatePropertyAll(Colors.transparent),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(vertical: 4),
              ),
              minimumSize: WidgetStatePropertyAll(
                Size(fieldWidth, 0),
              ),
            ),
            menuChildren: values.map((item) {
              return SizedBox(
                width: fieldWidth,
                height: 32,
                child: MenuItemButton(
                  onPressed: () => onChanged(item),
                  style: ButtonStyle(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 10),
                    ),
                    overlayColor: const WidgetStatePropertyAll(
                      Color(0xFFEAF2FF),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF17213B),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            builder: (context, controller, child) {
              return InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                child: InputDecorator(
                  isEmpty: value.isEmpty,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 17,
                      color: navy,
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 28,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: blue),
                    ),
                  ),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF17213B),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _dropdownRow(
    IconData icon,
    String label,
    String value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Row(
              children: [
                Icon(icon, size: 17, color: navy),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF17213B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _membershipStyleDropdown(
              value: value,
              values: values,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldDropdownRow(
    IconData icon,
    String label,
    String value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Row(
              children: [
                Icon(icon, size: 17, color: navy),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF17213B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _membershipStyleDropdown(
              value: value,
              values: values,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateRow() {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          const SizedBox(
            width: 112,
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 17,
                  color: navy,
                ),
                SizedBox(width: 7),
                Text(
                  'Date',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF17213B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              readOnly: true,
              controller: TextEditingController(
                text: '24-Oct-2020',
              ),
              style: const TextStyle(fontSize: 12.5),
              decoration: _inputDecoration().copyWith(
                suffixIcon: const Icon(
                  Icons.calendar_month,
                  size: 17,
                  color: navy,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _netAmount() {
    return Container(
      width: 145,
      height: 84,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8FF),
        border: Border.all(
          color: const Color(0xFFD7E8F8),
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          const Text(
            'Net Amount',
            style: TextStyle(
              color: navy,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '₹ ${money(total)} /-',
            style: const TextStyle(
              color: blue,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABLE
  // ============================================================

  Widget _itemsTable() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 270,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border, width: 1),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              _tableHeader(),
              _newItemRow(),
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  thickness: 5,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    itemExtent: 32,
                    itemBuilder: (context, index) {
                      return _savedItemRow(index);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      height: 34,
      color: tableBlue,
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(80),
          1: FixedColumnWidth(120),
          2: FlexColumnWidth(2.0),
          3: FixedColumnWidth(70),
          4: FixedColumnWidth(110),
          5: FixedColumnWidth(120),
          6: FixedColumnWidth(72),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              _headerCell('S.No'),
              _headerCell('Item Code'),
              _headerCell('Item Name'),
              _headerCell('Qty'),
              _headerCell('Rate (₹)'),
              _headerCell('Amount (₹)'),
              const SizedBox(width: 72),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text) {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8,vertical: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NEW ITEM ROW
  // ============================================================

  Widget _newItemRow() {
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: border),
          right: BorderSide(color: border),
          bottom: BorderSide(color: border),
        ),
      ),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(80),
          1: FixedColumnWidth(120),
          2: FlexColumnWidth(2.0),
          3: FixedColumnWidth(70),
          4: FixedColumnWidth(110),
          5: FixedColumnWidth(120),
          6: FixedColumnWidth(72),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: TextEditingController(text: '${items.length + 1}'),
                    style: const TextStyle(fontSize: 12.5),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: _tableDecoration(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: itemCodeController,
                    focusNode: _itemCodeFocus,
                    onSubmitted: (_) => FocusScope.of(context).requestFocus(_itemNameFocus),
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontSize: 12.5),
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (_) => _calculateEntryAmount(),
                    decoration: _tableDecoration(suffix: Icons.search),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: itemNameController,
                    focusNode: _itemNameFocus,
                    onSubmitted: (_) => FocusScope.of(context).requestFocus(_qtyFocus),
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontSize: 12.5),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: _tableDecoration(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: qtyController,
                    focusNode: _qtyFocus,
                    onSubmitted: (_) => FocusScope.of(context).requestFocus(_rateFocus),
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontSize: 12.5),
                    keyboardType: TextInputType.number,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (_) => _calculateEntryAmount(),
                    decoration: _tableDecoration(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: rateController,
                    focusNode: _rateFocus,
                    style: const TextStyle(fontSize: 12.5),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (_) => _calculateEntryAmount(),
                    onSubmitted: (_) => _addItem(),
                    textInputAction: TextInputAction.done,
                    decoration: _tableDecoration(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: amountController,
                    readOnly: true,
                    style: const TextStyle(fontSize: 12.5),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: _tableDecoration(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 68,
                    height: 28,
                    child: ElevatedButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add, size: 13),
                      label: const Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(68, 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableInput(Widget child, double flex) {
    return Expanded(
      flex: (flex * 100).round(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: SizedBox(
          height: 34,
          child: child,
        ),
      ),
    );
  }

  InputDecoration _tableDecoration({
    IconData? suffix,
  }) {
    const radius = BorderRadius.all(Radius.circular(4));
    const normal = BorderSide(color: border, width: 1);
    const focused = BorderSide(color: blue, width: 1);

    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      suffixIcon: suffix == null
          ? null
          : const Icon(Icons.search, size: 16, color: navy),
      suffixIconConstraints: const BoxConstraints(
        minWidth: 25,
        minHeight: 25,
      ),
      border: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: normal,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: normal,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: focused,
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: normal,
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: focused,
      ),
    );
  }

  // ============================================================
  // SAVED ITEM ROW
  // ============================================================

  Widget _savedItemRow(int index) {
    final item = items[index];

    final double itemQty = (item['qty'] as num).toDouble();
    final double itemRate = (item['rate'] as num).toDouble();
    final itemAmount = itemQty * itemRate;

    return Container(
      height: 29,
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFFBFDFF),
        border: const Border(
          left: BorderSide(color: border),
          right: BorderSide(color: border),
          bottom: BorderSide(color: border),
        ),
      ),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(80),
          1: FixedColumnWidth(120),
          2: FlexColumnWidth(2.0),
          3: FixedColumnWidth(70),
          4: FixedColumnWidth(110),
          5: FixedColumnWidth(120),
          6: FixedColumnWidth(72),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              _valueCell('${index + 1}', Alignment.center),
              _valueCell(item['code'].toString(), Alignment.centerLeft),
              _valueCell(item['name'].toString(), Alignment.centerLeft),
              _valueCell(item['qty'].toString(), Alignment.center),
              _valueCell(money(itemRate), Alignment.centerRight),
              _valueCell(money(itemAmount), Alignment.centerRight),
              SizedBox(
                width: 72,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() {
                      items.removeAt(index);
                    });
                  },
                  icon: const Icon(Icons.delete_outline, color: red, size: 17),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valueCell(String value, Alignment alignment) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF17213B),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM
  // ============================================================

  Widget _bottomSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        8,
        14,
        7,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: _paymentCard(),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 5,
            child: _summary(),
          ),
        ],
      ),
    );
  }

  Widget _paymentCard() {
    return Container(
      height: 198,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        border: Border.all(color: const Color(0xFFDCE7F2)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.payments_outlined,
                color: navy,
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'Payment Details',
                style: TextStyle(
                  color: navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _paymentField(
            'Cash Received',
            receivedController,
            Icons.payments_outlined,
          ),
          const SizedBox(height: 7),
          _paymentField(
            'Card Amount',
            cardController,
            Icons.credit_card_outlined,
          ),
          const SizedBox(height: 7),
          _paymentField(
            'UPI Amount',
            upiController,
            Icons.account_balance_wallet_outlined,
          ),
        ],
      ),
    );
  }

  Widget _paymentField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          SizedBox(
            width: 145,
            child: Row(
              children: [
                Icon(icon, size: 19, color: navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF17213B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: controller == receivedController
                  ? _receivedFocusNode
                  : controller == cardController
                      ? _cardFocusNode
                      : _upiFocusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _focusNextPaymentField(controller),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF17213B),
                fontWeight: FontWeight.w600,
              ),
              decoration: _paymentDecoration(),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _paymentDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: blue, width: 1.2),
      ),
    );
  }

  void _focusNextPaymentField(TextEditingController current) {
    if (current == receivedController) {
      FocusScope.of(context).requestFocus(_cardFocusNode);
    } else if (current == cardController) {
      FocusScope.of(context).requestFocus(_upiFocusNode);
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  // ============================================================
  // SUMMARY - REAL CALCULATIONS
  // ============================================================

  Widget _summary() {
    return Column(
      children: [
        _summaryLine('SubTotal :', money(subtotal)),
        _summaryLine('GST 5% :', money(gst)),
        _discountLine(),
        _summaryLine('Round Off :', money(roundOff)),
        const SizedBox(height: 5),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: headerBlue,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              const Text(
                'Total Amount :',
                style: TextStyle(
                  color: navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '₹ ${money(total)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: blue,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 24,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Total Qty :',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF17213B),
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  totalQty.toString(),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: navy,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryLine(String title, String value) {
    return SizedBox(
      height: 29,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _discountLine() {
    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Text(
              '(-) Discount :',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 30,
            height: 30,
            child: Center(
              child: Checkbox(
                value: discountEnabled,
                activeColor: blue,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                onChanged: (value) {
                  setState(() => discountEnabled = value ?? false);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 58,
            height: 30,
            child: TextField(
              controller: discountController,
              focusNode: _discountFocusNode,
              onSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_receivedFocusNode),
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: _compactSummaryDecoration(),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 82,
            child: Text(
              money(discount),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _compactSummaryDecoration() {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: blue, width: 1),
      ),
    );
  }

  // ============================================================
  // FOOTER
  // ============================================================

  Widget _footer() {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          const Spacer(),
          _footerButton(
            Icons.save_outlined,
            'Save (F8)',
            blue,
            Colors.white,
          ),
          const SizedBox(width: 6),
          _footerButton(
            Icons.delete_outline,
            'Delete (F10)',
            red,
            Colors.white,
            _resetBill,
          ),
          const SizedBox(width: 12),
          Container(
            height: 45,
            width: 280,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F9EC),
              border: Border.all(color: const Color(0xFFC6EEDD)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                const Text(
                  'Balance Amount :',
                  style: TextStyle(
                    color: Color(0xFF11683A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${balanceAmount >= 0 ? '+' : ''}₹ ${money(balanceAmount)}',
                  style: TextStyle(
                    color: balanceAmount < 0
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFF08763B),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REAL ITEM CALCULATION
  // ============================================================

  void _calculateEntryAmount() {
    final q = double.tryParse(qtyController.text) ?? 0;
    final r = double.tryParse(rateController.text) ?? 0;

    amountController.text = q > 0 && r > 0
        ? money(q * r)
        : '';
  }

  // ============================================================
  // ADD ITEM BELOW TABLE
  // ============================================================

  void _addItem() {
    final code = itemCodeController.text.trim();
    final name = itemNameController.text.trim();

    final itemQty =
        int.tryParse(qtyController.text.trim()) ?? 0;

    final itemRate =
        double.tryParse(rateController.text.trim()) ?? 0;

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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _footerButton(
    IconData icon,
    String text,
    Color color,
    Color foreground, [
    VoidCallback? onPressed,
  ]) {
    return SizedBox(
      width: 125,
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onPressed ?? () {},
        icon: Icon(
          icon,
          size: 18,
        ),
        label: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foreground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }


  void _saveBill() {
    _showMessage('Bill saved successfully');
  }

  void _resetBill() {
    setState(() {
      items
        ..clear()
        ..addAll([
          {
            'code': '434',
            'name': 'PATANJALI COW GHEE 500ML',
            'qty': 1,
            'unit': 'PCS',
            'rate': 286.15,
          },
          {
            'code': '435',
            'name': 'PATANJALI COW GHEE 200ML',
            'qty': 1,
            'unit': 'PCS',
            'rate': 121.25,
          },
          {
            'code': '464',
            'name': 'Appy FIZZ 1000ml',
            'qty': 1,
            'unit': 'PCS',
            'rate': 56.26,
          },
          {
            'code': '322',
            'name': 'PATANJALI DW BAR 175G',
            'qty': 1,
            'unit': 'PCS',
            'rate': 9.70,
          },
          {
            'code': '466',
            'name': 'Appy FIZZ 600ml',
            'qty': 1,
            'unit': 'PCS',
            'rate': 32.01,
          },
        ]);

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


  @override
  void dispose() {
    mobileController.dispose();
    customerController.dispose();
    addressController.dispose();
    billNoController.dispose();
    discountController.dispose();
    receivedController.dispose();
    givenByController.dispose();
    itemCodeController.dispose();
    itemNameController.dispose();
    qtyController.dispose();
    rateController.dispose();
    amountController.dispose();
    cardController.dispose();
    upiController.dispose();
    _mobileFocus.dispose();
    _customerFocus.dispose();
    _addressFocus.dispose();
    _itemCodeFocus.dispose();
    _itemNameFocus.dispose();
    _qtyFocus.dispose();
    _rateFocus.dispose();
    _cardFocusNode.dispose();
    _upiFocusNode.dispose();
    _receivedFocusNode.dispose();
    _discountFocusNode.dispose();
    super.dispose();
  }


}
