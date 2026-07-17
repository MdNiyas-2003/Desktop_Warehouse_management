import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DraftOrder {
  final String id;
  final String orderId;
  final String customerName;
  final String salesmanName;
  final double amount;
  final int quantity;
  final DateTime createdAt;

  const DraftOrder({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.salesmanName,
    required this.amount,
    required this.quantity,
    required this.createdAt,
  });

  factory DraftOrder.fromJson(Map<String, dynamic> json) {
    return DraftOrder(
      id: json["id"],
      orderId: json["orderId"],
      customerName: json["customerName"],
      salesmanName: json["salesmanName"],
      amount: (json["amount"] as num).toDouble(),
      quantity: (json["quantity"] as num).toInt(),
      createdAt: DateTime.parse(json["createdAt"]),
    );
  }
}

class DraftOrdersDialog extends StatefulWidget {
  final List<DraftOrder> drafts;

  const DraftOrdersDialog({
    super.key,
    required this.drafts,
  });

  @override
  State<DraftOrdersDialog> createState() =>
      _DraftOrdersDialogState();
}

class _DraftOrdersDialogState
    extends State<DraftOrdersDialog> {

  final TextEditingController searchController =
      TextEditingController();

  late List<DraftOrder> filteredDrafts;

  @override
  void initState() {
    super.initState();
    filteredDrafts = widget.drafts;
  }

  void search(String value) {
    final keyword = value.toLowerCase();

    setState(() {
      filteredDrafts = widget.drafts.where((e) {
        return e.orderId
                .toLowerCase()
                .contains(keyword) ||
            e.customerName
                .toLowerCase()
                .contains(keyword);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {

    return Dialog(

      backgroundColor: Colors.transparent,

      child: Container(

        width: 980,
        height: 680,

        decoration: BoxDecoration(

          color: Colors.white,

          borderRadius:
              BorderRadius.circular(24),

          boxShadow: [

            BoxShadow(

              color: Colors.black.withOpacity(.15),

              blurRadius: 40,

              offset: const Offset(0,20),

            )

          ],

        ),

        child: Column(

          children: [

            //==========================
            // HEADER
            //==========================

            Container(

              padding:
                  const EdgeInsets.all(24),

              decoration: const BoxDecoration(

                gradient: LinearGradient(

                  colors: [

                    Color(0xff2563EB),

                    Color(0xff1E40AF),

                  ],

                ),

                borderRadius:

                    BorderRadius.vertical(

                  top: Radius.circular(24),

                ),

              ),

              child: Row(

                children: [

                  Container(

                    height: 56,

                    width: 56,

                    decoration:

                        BoxDecoration(

                      color: Colors.white,

                      borderRadius:

                          BorderRadius.circular(
                              16),

                    ),

                    child: const Icon(

                      Icons.description,

                      color: Color(0xff2563EB),

                      size: 30,

                    ),

                  ),

                  const SizedBox(width:18),

                  Expanded(

                    child: Column(

                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [

                        const Text(

                          "Draft Orders",

                          style: TextStyle(

                            color: Colors.white,

                            fontWeight:
                                FontWeight.bold,

                            fontSize: 26,

                          ),

                        ),

                        const SizedBox(height:6),

                        Text(

                          "Continue editing unfinished sales orders",

                          style: TextStyle(

                            color: Colors.white
                                .withOpacity(.9),

                          ),

                        )

                      ],

                    ),

                  ),

                  FilledButton.icon(

                    style:
                        FilledButton.styleFrom(

                      backgroundColor:
                          Colors.white,

                      foregroundColor:
                          const Color(
                              0xff2563EB),

                    ),

                    onPressed: (){

                      Navigator.pop(
                        context,
                        "new",
                      );

                    },

                    icon:
                        const Icon(Icons.add),

                    label: const Text(
                      "New Order",
                    ),

                  ),

                  const SizedBox(width:10),

                  IconButton(

                    onPressed: (){

                      Navigator.pop(context);

                    },

                    icon: const Icon(

                      Icons.close,

                      color: Colors.white,

                    ),

                  ),

                ],

              ),

            ),

            //======================
            // SEARCH
            //======================

            Padding(

              padding:
                  const EdgeInsets.all(22),

              child: TextField(

                controller:
                    searchController,

                onChanged: search,

                decoration: InputDecoration(

                  hintText:
                      "Search Order Number or Customer",

                  prefixIcon: const Icon(
                    Icons.search,
                  ),

                  filled: true,

                  fillColor:
                      const Color(
                          0xffF7F9FC),

                  border:
                      OutlineInputBorder(

                    borderRadius:
                        BorderRadius.circular(
                            14),

                    borderSide:
                        BorderSide.none,

                  ),

                ),

              ),

            ),

            //====================
            // DASHBOARD
            //====================

            Padding(

              padding: const EdgeInsets.symmetric(
                  horizontal: 22),

              child: Row(

                children: [

                  _infoCard(

                    "Drafts",

                    filteredDrafts.length
                        .toString(),

                    Icons.description,

                    Colors.orange,

                  ),

                  const SizedBox(width:16),

                  _infoCard(

                    "Total Value",

                    "₹${filteredDrafts.fold<double>(0, (a,b)=>a+b.amount).toStringAsFixed(0)}",

                    Icons.currency_rupee,

                    Colors.green,

                  ),

                  const SizedBox(width:16),

                  _infoCard(

                    "Items",

                    filteredDrafts
                        .fold<int>(
                          0,
                          (a,b)=>a+b.quantity,
                        )
                        .toString(),

                    Icons.inventory,

                    Colors.blue,

                  ),

                ],

              ),

            ),

            const SizedBox(height:22),

           Expanded(
  child: filteredDrafts.isEmpty
      ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_open_outlined,
                size: 90,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 20),
              const Text(
                "No Draft Orders Found",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Create a new sales order or save one as draft.",
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 25),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context, "new");
                },
                icon: const Icon(Icons.add),
                label: const Text("Create New Order"),
              ),
            ],
          ),
        )
      : ListView(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          children: [
            ...filteredDrafts.map((draft) {

  return _MouseHoverCard(
    margin: const EdgeInsets.only(bottom: 18),

    child: Container(

      decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),

      border: Border.all(
        color: const Color(0xffE6ECF5),
      ),

      boxShadow: [

        BoxShadow(
          color: Colors.grey.withOpacity(.08),
          blurRadius: 18,
          offset: const Offset(0,8),
        )

      ],
    ),

    child: Padding(

      padding: const EdgeInsets.all(20),

      child: Column(

        children: [

          //------------------------------------------------
          // FIRST ROW
          //------------------------------------------------

          Row(

            children: [

              Container(

                height: 60,

                width: 60,

                decoration: BoxDecoration(

                  color: const Color(0xffEEF4FF),

                  borderRadius:
                      BorderRadius.circular(16),

                ),

                child: const Icon(

                  Icons.receipt_long,

                  color: Color(0xff2563EB),

                  size: 30,

                ),

              ),

              const SizedBox(width:18),

              Expanded(

                child: Column(

                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Row(

                      children: [

                        Text(

                          draft.orderId,

                          style: const TextStyle(

                            fontWeight:
                                FontWeight.bold,

                            fontSize: 18,

                          ),

                        ),

                        const SizedBox(width:10),

                        Container(

                          padding:
                              const EdgeInsets.symmetric(

                            horizontal: 10,

                            vertical: 5,

                          ),

                          decoration: BoxDecoration(

                            color: Colors.orange.shade100,

                            borderRadius:
                                BorderRadius.circular(20),

                          ),

                          child: const Text(

                            "Draft",

                            style: TextStyle(

                              color: Colors.orange,

                              fontWeight:
                                  FontWeight.bold,

                            ),

                          ),

                        ),

                      ],

                    ),

                    const SizedBox(height:8),

                    Text(

                      draft.customerName,

                      style: TextStyle(

                        color: Colors.grey.shade700,

                        fontSize: 15,

                      ),

                    ),

                  ],

                ),

              ),

              Text(

                "₹ ${draft.amount.toStringAsFixed(2)}",

                style: const TextStyle(

                  fontWeight: FontWeight.bold,

                  fontSize: 22,

                  color: Color(0xff16A34A),

                ),

              ),

            ],

          ),

          const SizedBox(height:18),

          Divider(
            color: Colors.grey.shade300,
          ),

          const SizedBox(height:12),

          //------------------------------------------------
          // INFORMATION ROW
          //------------------------------------------------

          Row(

            children: [

              Expanded(

                child: _detailTile(

                  Icons.person_outline,

                  "Salesman",

                  draft.salesmanName,

                ),

              ),

              Expanded(

                child: _detailTile(

                  Icons.inventory_2_outlined,

                  "Items",

                  "${draft.quantity}",

                ),

              ),

              Expanded(

                child: _detailTile(

                  Icons.calendar_today_outlined,

                  "Saved",

                  DateFormat(
                    "dd MMM yyyy",
                  ).format(
                    draft.createdAt,
                  ),

                ),

              ),

            ],

          ),

          const SizedBox(height:18),

          Divider(
            color: Colors.grey.shade300,
          ),

          const SizedBox(height:16),

          //------------------------------------------------
          // BUTTONS
          //------------------------------------------------

          Row(

            children: [

              OutlinedButton.icon(

                style: OutlinedButton.styleFrom(

                  foregroundColor: Colors.red,

                  side: const BorderSide(
                    color: Colors.red,
                  ),

                ),

                onPressed: () {

                  Navigator.pop(
                    context,
                    {
                      "action":"delete",
                      "id":draft.id,
                    },
                  );

                },

                icon: const Icon(Icons.delete),

                label: const Text("Delete"),

              ),

              const Spacer(),

              FilledButton.icon(

                style: FilledButton.styleFrom(

                  backgroundColor:
                      const Color(0xff2563EB),

                  padding:
                      const EdgeInsets.symmetric(

                    horizontal: 24,

                    vertical: 15,

                  ),

                ),

                onPressed: () {

                  Navigator.pop(
                    context,
                    {
                      "action":"open",
                      "id":draft.id,
                    },
                  );

                },

                icon: const Icon(Icons.folder_open),

                label: const Text(

                  "Continue Editing",

                ),

              ),

            ],

          ),

        ],

      ),

    ),
    )
  );

}).toList(),
                ],

              ),

            ),
          ],
        ),
      ),
    );
  }
  //----------------------------------------------------------
// INFO CARD
//----------------------------------------------------------

Widget _infoCard(
  String title,
  String value,
  IconData icon,
  Color color,
) {
  return Expanded(
    child: Container(
      height: 92,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xffE8EEF7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

////////////////////////////////////////////////////////////
/// DETAIL TILE
////////////////////////////////////////////////////////////

Widget _detailTile(
  IconData icon,
  String title,
  String value,
) {
  return Row(
    children: [
      Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: const Color(0xffF5F8FD),
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: const Color(0xff2563EB),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

////////////////////////////////////////////////////////////
/// FORMAT DATE
////////////////////////////////////////////////////////////

String formatDate(DateTime date) {
  return DateFormat(
    "dd MMM yyyy • hh:mm a",
  ).format(date);
}

////////////////////////////////////////////////////////////
/// DELETE CONFIRMATION
////////////////////////////////////////////////////////////

Future<bool> confirmDelete(
  BuildContext context,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(20),
            ),
            title: const Text(
              "Delete Draft?",
            ),
            content: const Text(
              "This draft order will be permanently removed.",
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () =>
                    Navigator.pop(context, true),
                child: const Text("Delete"),
              ),
            ],
          );
        },
      ) ??
      false;
}
    }
    ////////////////////////////////////////////////////////////
/// PREMIUM HOVER CARD
////////////////////////////////////////////////////////////

class _MouseHoverCard extends StatefulWidget {
  const _MouseHoverCard({
    required this.child,
    required this.margin,
  });

  final Widget child;
  final EdgeInsets margin;

  @override
  State<_MouseHoverCard> createState() =>
      _MouseHoverCardState();
}

class _MouseHoverCardState
    extends State<_MouseHoverCard> {

  bool hover = false;

  @override
  Widget build(BuildContext context) {

    return MouseRegion(

      cursor: SystemMouseCursors.click,

      onEnter: (_) {
        setState(() {
          hover = true;
        });
      },

      onExit: (_) {
        setState(() {
          hover = false;
        });
      },

      child: AnimatedContainer(

        duration:
            const Duration(milliseconds: 180),

        margin: widget.margin,

        transform: Matrix4.identity()
          ..translate(
            0.0,
            hover ? -4.0 : 0.0,
          ),

        decoration: BoxDecoration(

          borderRadius:
              BorderRadius.circular(18),

          boxShadow: [

            BoxShadow(

              color: hover

                  ? Colors.blue.withOpacity(.15)

                  : Colors.grey.withOpacity(.08),

              blurRadius: hover ? 28 : 14,

              offset: Offset(
                0,
                hover ? 12 : 6,
              ),

            )

          ],

        ),

        child: widget.child,

      ),

    );

  }
}