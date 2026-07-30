import 'package:flutter/material.dart';

class ErpSearchDropdown<T> extends StatefulWidget {
  const ErpSearchDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.items,
    required this.itemText,
    required this.onSelected,
    this.selectedItem,
    this.onAddNew,
    this.width,
    this.maxHeight = 260,
  });

  final String label;
  final String hint;

  final List<T> items;

  final T? selectedItem;

  final String Function(T item) itemText;

  final ValueChanged<T> onSelected;

  final ValueChanged<String>? onAddNew;
  final double? width;

  final double maxHeight;

  @override
  State<ErpSearchDropdown<T>> createState() => _ErpSearchDropdownState<T>();
}

class _ErpSearchDropdownState<T> extends State<ErpSearchDropdown<T>> {
  final LayerLink _layerLink = LayerLink();

  final TextEditingController _controller = TextEditingController();

  final FocusNode _focusNode = FocusNode();

  OverlayEntry? _overlay;

  List<T> _filtered = [];

  @override
  void initState() {
    super.initState();

    _filtered = List.from(widget.items);

    if (widget.selectedItem != null) {
  _controller.text = widget.itemText(widget.selectedItem as T);
} else {
  _controller.clear();
}

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _showOverlay();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ErpSearchDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.items != widget.items) {
      _filtered = List.from(widget.items);

      if (_overlay != null) {
        _overlay!.markNeedsBuild();
      }
    }

   if (widget.selectedItem != null) {
  _controller.text = widget.itemText(widget.selectedItem as T);
} else {
  _controller.clear();
}
  }

  @override
  void dispose() {
    _hideOverlay();

    _controller.dispose();
    _focusNode.dispose();

    super.dispose();
  }

  void _filter(String value) {
    if (value.trim().isEmpty) {
      _filtered = List.from(widget.items);
    } else {
      _filtered = widget.items.where((item) {
        return widget
            .itemText(item)
            .toLowerCase()
            .contains(value.toLowerCase());
      }).toList();
    }

    if (_overlay != null) {
      _overlay!.markNeedsBuild();
    }

    setState(() {});
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _selectItem(T item) {
    _controller.text = widget.itemText(item);

    widget.onSelected(item);

    _focusNode.unfocus();

    _hideOverlay();
  }

  void _showOverlay() {
    _hideOverlay();

    _filtered = List.from(widget.items);

    final RenderBox renderBox = context.findRenderObject() as RenderBox;

    final size = renderBox.size;

    _overlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _focusNode.unfocus();
                  _hideOverlay();
                },
                child: const SizedBox(),
              ),
            ),

            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 66),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: widget.width ?? size.width,
                  constraints: BoxConstraints(maxHeight: widget.maxHeight),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _filtered.isEmpty
                          ? (widget.onAddNew != null ? 2 : 1)
                          : _filtered.length +
                                (widget.onAddNew != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_filtered.isEmpty) {
                          if (index == 0) {
                            return const ListTile(
                              dense: true,
                              title: Text(
                                "No records found",
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          return InkWell(
                            onTap: () {
                              _hideOverlay();

                              widget.onAddNew?.call(_controller.text.trim());
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.add_circle,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "Add New",
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        if (widget.onAddNew != null &&
                            index == _filtered.length) {
                          return InkWell(
                            onTap: () {
                              _hideOverlay();
                              widget.onAddNew?.call(_controller.text.trim());
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.add_circle,
                                    size: 20,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "Add New",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final item = _filtered[index];

                        return InkWell(
                          onTap: () => _selectItem(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text(
                              widget.itemText(item),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
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

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 6),

          SizedBox(
            width: widget.width,
            height: 30,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: (value) {
                _filter(value);
              },
              decoration: InputDecoration(
                hintText: widget.hint,

                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),

                filled: true,
                fillColor: Colors.white,

                isDense: true,

                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),

                suffixIcon: InkWell(
                  onTap: () {
                    if (_overlay == null) {
                      _focusNode.requestFocus();
                      _showOverlay();
                    } else {
                      _focusNode.unfocus();
                      _hideOverlay();
                    }
                  },
                  child: Icon(
                    _overlay == null
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: Colors.grey.shade700,
                  ),
                ),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue, width: 1.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
