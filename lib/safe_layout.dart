import 'package:flutter/material.dart';

import 'brand.dart';

/// Shared inset policy for Progression Lab. Decorative surfaces may draw
/// edge-to-edge, but every interactive control stays outside system UI.
class LabSafeScreen extends StatelessWidget {
  const LabSafeScreen({
    super.key,
    required this.child,
    this.bottomAction,
    this.top = true,
    this.left = true,
    this.right = true,
    this.backgroundColor = BrandColors.ink,
  });

  final Widget child;
  final Widget? bottomAction;
  final bool top;
  final bool left;
  final bool right;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: backgroundColor,
    child: SafeArea(
      top: top,
      left: left,
      right: right,
      bottom: bottomAction == null,
      child: Column(
        children: [
          Expanded(child: child),
          if (bottomAction != null) LabSafeBottomAction(child: bottomAction!),
        ],
      ),
    ),
  );
}

class LabSafeBottomAction extends StatelessWidget {
  const LabSafeBottomAction({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 16),
    this.color = BrandColors.ink,
    this.showDivider = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                top: BorderSide(color: Colors.white.withValues(alpha: .08)),
              )
            : null,
      ),
      child: SafeArea(top: false, minimum: padding, child: child),
    ),
  );
}

class LabSafeBottomSheet extends StatelessWidget {
  const LabSafeBottomSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 16),
    this.scrollable = false,
    this.maxWidth = 760,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool scrollable;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final body = Padding(
      padding: padding.copyWith(bottom: padding.bottom + keyboard),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
    return Material(
      color: BrandColors.panel,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: scrollable ? SingleChildScrollView(child: body) : body,
        ),
      ),
    );
  }
}

class LabKeyboardAwareForm extends StatelessWidget {
  const LabKeyboardAwareForm({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 24),
    this.controller,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      controller: controller,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: padding.copyWith(
        bottom: padding.bottom + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: children,
    ),
  );
}

Future<T?> showLabBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: isDismissible,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: .72),
  builder: builder,
);
