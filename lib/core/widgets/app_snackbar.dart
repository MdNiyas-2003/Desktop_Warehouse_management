import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppSnackBar {
  AppSnackBar({
    required this.title,
    required this.message,
    this.titleFontSize = 16.0,
  });
  AppSnackBar.alert({
    required this.message,
    this.title = "Alert",
    this.titleFontSize = 16.0,
    final Icon? icon,
  }) {
    _show(
      title: title,
      message: message,
      backgroundColor: const Color.fromARGB(255, 244, 17, 17),
      duration: const Duration(seconds: 5),
      titleFontSize: titleFontSize,
      icon: icon?.icon ?? Icons.warning,
    );
  }

  AppSnackBar.success({
    required this.message,
    this.title = "Success",
    this.titleFontSize = 16.0,
  }) {
    _show(
      title: title,
      message: message,
      backgroundColor: const Color.fromARGB(255, 71, 182, 75),
      duration: const Duration(seconds: 3),
      titleFontSize: titleFontSize,
      icon: Icons.check_circle,
    );
  }

  AppSnackBar.failed({
    required this.message,
    this.title = "Failed",
    this.titleFontSize = 16.0,
  }) {
    _show(
      title: title,
      message: message,
      backgroundColor: const Color.fromRGBO(255, 0, 0, 1),
      duration: const Duration(seconds: 3),
      titleFontSize: titleFontSize,
      icon: Icons.error,
    );
  }

  AppSnackBar.warning({
    required this.message,
    this.title = "Warning",
    this.titleFontSize = 16.0,
    final Icon? icon,
  }) {
    _show(
      title: title,
      message: message,
      backgroundColor: Colors.orangeAccent,
      duration: const Duration(seconds: 5),
      titleFontSize: titleFontSize,
      icon: icon?.icon ?? Icons.warning,
    );
  }
  static OverlayEntry? _overlayEntry;
  static VoidCallback? _requestHide;

  String title;
  String message;
  double titleFontSize;

  static void _clearCurrent({final bool animated = true}) {
    if (animated && _requestHide != null) {
      _requestHide!();
      return;
    }
    _requestHide = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  static void clear({final bool animated = true}) {
    appScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    _clearCurrent(animated: animated);
  }

  static void _show({
    required final String title,
    required final String message,
    required final Color backgroundColor,
    required final Duration duration,
    final double titleFontSize = 16.0,
    final IconData? icon,
  }) {
    final ScaffoldMessengerState? messenger =
        appScaffoldMessengerKey.currentState;
    if (messenger == null) {
      return;
    }

    final OverlayState? overlay = appNavigatorKey.currentState?.overlay;

    if (overlay == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(10),
            backgroundColor: backgroundColor,
            duration: duration,
            content: Row(
              children: <Widget>[
                Icon(icon ?? Icons.info_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "$title: $message",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      return;
    }

    _clearCurrent(animated: false);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (final BuildContext context) => _TopFloatingSnackBar(
        title: title,
        message: message,
        backgroundColor: backgroundColor,
        duration: duration,
        titleFontSize: titleFontSize,
        icon: icon ?? Icons.info_outline,
        onRegisterHide: (final VoidCallback hide) {
          if (_overlayEntry == entry) {
            _requestHide = hide;
          }
        },
        onHidden: () {
          if (_overlayEntry == entry) {
            _requestHide = null;
            _overlayEntry?.remove();
            _overlayEntry = null;
          }
        },
      ),
    );

    _overlayEntry = entry;
    overlay.insert(entry);
  }
}

class _TopFloatingSnackBar extends StatefulWidget {
  const _TopFloatingSnackBar({
    required this.title,
    required this.message,
    required this.backgroundColor,
    required this.duration,
    required this.titleFontSize,
    required this.icon,
    required this.onHidden,
    required this.onRegisterHide,
  });
  final String title;
  final String message;
  final Color backgroundColor;
  final Duration duration;
  final double titleFontSize;
  final IconData icon;
  final VoidCallback onHidden;
  final ValueChanged<VoidCallback> onRegisterHide;

  @override
  State<_TopFloatingSnackBar> createState() => _TopFloatingSnackBarState();

  @override
  void debugFillProperties(final DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty("title", title))
      ..add(StringProperty("message", message))
      ..add(ColorProperty("backgroundColor", backgroundColor))
      ..add(DiagnosticsProperty<Duration>("duration", duration))
      ..add(DoubleProperty("titleFontSize", titleFontSize))
      ..add(DiagnosticsProperty<IconData>("icon", icon))
      ..add(ObjectFlagProperty<VoidCallback>.has("onHidden", onHidden))
      ..add(
        ObjectFlagProperty<ValueChanged<VoidCallback>>.has(
          "onRegisterHide",
          onRegisterHide,
        ),
      );
  }
}

class _TopFloatingSnackBarState extends State<_TopFloatingSnackBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isHiding = false;
  double _dragOffsetY = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 220),
    );

    widget.onRegisterHide(_hideAnimated);
    unawaited(_controller.forward());

    unawaited(Future<void>.delayed(widget.duration, _hideAnimated));
  }

  Future<void> _hideAnimated() async {
    if (_isHiding || !mounted) {
      return;
    }
    _isHiding = true;
    try {
      await _controller.reverse();
    } finally {
      if (mounted) {
        widget.onHidden();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final CurvedAnimation animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: AnimatedBuilder(
            animation: animation,
            builder: (final BuildContext context, final Widget? child) {
              final double v = animation.value.clamp(0.0, 1.0);
              return Opacity(
                opacity: v,
                child: Transform.translate(
                  offset: Offset(0, (1 - v) * -22),
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (final DragUpdateDetails details) {
                final double next = _dragOffsetY + details.delta.dy;
                setState(() {
                  _dragOffsetY = next.clamp(-120.0, 0.0);
                });
              },
              onVerticalDragEnd: (final DragEndDetails details) {
                final bool shouldDismiss =
                    _dragOffsetY <= -36 ||
                    (details.primaryVelocity != null &&
                        details.primaryVelocity! < -420);

                if (shouldDismiss) {
                  unawaited(_hideAnimated());
                  return;
                }

                setState(() {
                  _dragOffsetY = 0;
                });
              },
              child: Transform.translate(
                offset: Offset(0, _dragOffsetY),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 74),
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(widget.icon, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                widget.title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: widget.titleFontSize,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.message,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget loadingWidget() => const Center(
  child: CircularProgressIndicator(
    valueColor: AlwaysStoppedAnimation<Color>(
      Color.fromARGB(255, 251, 252, 253),
    ),
  ),
);
