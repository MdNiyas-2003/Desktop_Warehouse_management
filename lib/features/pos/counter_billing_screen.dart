
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'counter_billing_widgets.dart';
part 'counter_billing_methods.dart';

const Color navy = Color(0xFF082D68);
const Color blue = Color(0xFF1167E8);
const Color headerBlue = Color(0xFFDDEEFF);
const Color tableBlue = Color(0xFF28567F);
const Color border = Color(0xFFD4DEE8);
const Color green = Color(0xFF159447);
const Color red = Color(0xFFE52D2D);
const Color pageBg = Color(0xFFF4F7FB);

class _ResetBillIntent extends Intent {
  const _ResetBillIntent();
}

class CounterBillingScreen extends StatefulWidget {
  const CounterBillingScreen({super.key});

  @override
  State<CounterBillingScreen> createState() => _CounterBillingScreenState();
}

abstract class _CounterBillingScreenStateBase extends State<CounterBillingScreen> {
  // ============================================================
  // COLORS
  // ============================================================








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

  final ScrollController _itemsScrollController = ScrollController();

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

  void _calculateEntryAmount();
  void _addItem();
  void _resetBill();

}

class _CounterBillingScreenState extends _CounterBillingScreenStateBase with _CounterBillingWidgets, _CounterBillingMethods {
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
          SingleActivator(LogicalKeyboardKey.f10): _ResetBillIntent(),
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
    _itemsScrollController.dispose();
    super.dispose();
  }
}
