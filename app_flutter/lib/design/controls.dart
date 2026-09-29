import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'tokens.g.dart';
import 'type.dart';

enum CullButtonKind { primary, quiet, outline, danger, ghost }

class CullButton extends StatefulWidget {
  const CullButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = CullButtonKind.primary,
    this.icon,
    this.expand = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final CullButtonKind kind;
  final Widget? icon;
  final bool expand;
  final bool dense;

  @override
  State<CullButton> createState() => _CullButtonState();
}

class _CullButtonState extends State<CullButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final palette = _palette(widget.kind, enabled);
    final text = CullType.withColor(
      widget.dense ? CullType.label : CullType.titleM,
      palette.foreground,
    );
    final height = widget.dense ? 40.0 : CullTokens.minTouchTarget;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          widget.icon!,
          SizedBox(width: CullTokens.spaceSm),
        ],
        Flexible(
          child: Text(
            widget.label,
            style: text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: _down ? CullTokens.motionInstant : CullTokens.motionSettle,
          height: height,
          width: widget.expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: widget.dense ? CullTokens.spaceMd : CullTokens.spaceXl,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _down ? palette.pressed : palette.background,
            borderRadius: BorderRadius.circular(
              widget.dense ? CullTokens.radiusSm : CullTokens.radiusPill,
            ),
            border: palette.border,
            boxShadow: palette.shadow,
          ),
          child: content,
        ),
      ),
    );
  }
}

class _ButtonPalette {
  const _ButtonPalette(
    this.background,
    this.foreground,
    this.pressed,
    this.border,
    this.shadow,
  );

  final Color background;
  final Color foreground;
  final Color pressed;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;
}

_ButtonPalette _palette(CullButtonKind kind, bool enabled) {
  if (!enabled) {
    return const _ButtonPalette(
      CullTokens.surface2,
      CullTokens.inkDisabled,
      CullTokens.surface3,
      null,
      null,
    );
  }
  switch (kind) {
    case CullButtonKind.primary:
      return const _ButtonPalette(
        CullTokens.signal,
        CullTokens.inkOnAccent,
        CullTokens.signalSoft,
        null,
        null,
      );
    case CullButtonKind.danger:
      return const _ButtonPalette(
        CullTokens.danger,
        CullTokens.inkOnAccent,
        CullTokens.dangerSoft,
        null,
        null,
      );
    case CullButtonKind.outline:
      return const _ButtonPalette(
        CullTokens.canvas,
        CullTokens.inkPrimary,
        CullTokens.surface2,
        Border.fromBorderSide(
          BorderSide(color: CullTokens.inkDisabled, width: 1.5),
        ),
        null,
      );
    case CullButtonKind.quiet:
      return const _ButtonPalette(
        CullTokens.surface2,
        CullTokens.inkPrimary,
        CullTokens.surface3,
        null,
        null,
      );
    case CullButtonKind.ghost:
      return const _ButtonPalette(
        Color(0x00000000),
        CullTokens.inkSecondary,
        CullTokens.surface2,
        null,
        null,
      );
  }
}

class CullSurface extends StatefulWidget {
  const CullSurface({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(CullTokens.spaceLg),
    this.background,
    this.radius = CullTokens.radiusLg,
    this.border,
    this.selected = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? background;
  final double radius;
  final Border? border;
  final bool selected;

  @override
  State<CullSurface> createState() => _CullSurfaceState();
}

class _CullSurfaceState extends State<CullSurface> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final tappable = widget.onTap != null;
    return Semantics(
      button: tappable,
      selected: widget.selected,
      child: GestureDetector(
        onTapDown: tappable ? (_) => setState(() => _down = true) : null,
        onTapUp: tappable ? (_) => setState(() => _down = false) : null,
        onTapCancel: tappable ? () => setState(() => _down = false) : null,
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: CullTokens.motionInstant,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.background ?? CullTokens.surface1,
            borderRadius: BorderRadius.circular(widget.radius),
            border: widget.border ?? _border(_down),
            boxShadow: _down ? null : _shadow,
          ),
          child: widget.child,
        ),
      ),
    );
  }

  Border? _border(bool down) {
    if (widget.selected) {
      return Border.all(color: CullTokens.signalDim, width: 2);
    }
    if (down) return null;
    return Border.all(color: CullTokens.inkDisabled.withValues(alpha: 0.28));
  }

  List<BoxShadow> get _shadow => const [
    BoxShadow(color: Color(0x1F8A6A3A), blurRadius: 3, offset: Offset(0, 1)),
  ];
}

class CullIconButton extends StatelessWidget {
  const CullIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.color,
    this.size = 22,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: CullTokens.minTouchTarget,
          child: Center(
            child: SizedBox.square(dimension: size, child: icon),
          ),
        ),
      ),
    );
  }
}

class CullTag extends StatelessWidget {
  const CullTag({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
    this.leading,
    this.monospace = false,
    this.dense = false,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Widget? leading;
  final bool monospace;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final style = monospace
        ? (dense ? CullType.monoXs : CullType.monoS)
        : CullType.label;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? CullTokens.spaceSm : CullTokens.spaceMd,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(CullTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 5)],
          Text(label.toUpperCase(), style: style.copyWith(color: foreground)),
        ],
      ),
    );
  }
}

class CullRule extends StatelessWidget {
  const CullRule({super.key, this.indent = 0, this.color});

  final double indent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: CullTokens.spaceMd),
      child: Row(
        children: [
          if (indent > 0) SizedBox(width: indent),
          Expanded(
            child: SizedBox(
              height: 1,
              child: ColoredBox(color: color ?? CullTokens.inkDisabled),
            ),
          ),
        ],
      ),
    );
  }
}

class CullBar extends StatelessWidget {
  const CullBar({
    super.key,
    required this.value,
    this.color = CullTokens.signalDim,
    this.track,
    this.height = 6,
  });

  final double value;
  final Color color;
  final Color? track;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: track ?? CullTokens.surface3,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
              AnimatedContainer(
                duration: CullTokens.motionSettle,
                width: (w * value.clamp(0, 1)),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CullToggle extends StatelessWidget {
  const CullToggle({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: CullTokens.motionSettle,
          curve: Curves.easeOutCubic,
          width: 52,
          height: 30,
          padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? CullTokens.signalDim : CullTokens.surface3,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: CullTokens.surface1,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class CullField extends StatefulWidget {
  const CullField({
    super.key,
    required this.controller,
    this.hint,
    this.onSubmitted,
    this.keyboardType,
    this.autofocus = false,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final bool autofocus;
  final int maxLines;

  @override
  State<CullField> createState() => _CullFieldState();
}

class _CullFieldState extends State<CullField> {
  final FocusNode _node = FocusNode();
  bool _focused = false;

  late final TextEditingController _controller = widget.controller
    ..addListener(_onText);

  void _onText() => setState(() {});

  @override
  void initState() {
    super.initState();
    _node.addListener(() => setState(() => _focused = _node.hasFocus));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CullTokens.spaceMd,
        vertical: CullTokens.spaceMd,
      ),
      decoration: BoxDecoration(
        color: CullTokens.surface1,
        borderRadius: BorderRadius.circular(CullTokens.radiusMd),
        border: Border.all(
          color: _focused ? CullTokens.focus : CullTokens.inkDisabled,
          width: _focused ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          if (widget.hint != null && _controller.text.isEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    widget.hint!,
                    style: CullType.bodyM.copyWith(
                      color: CullTokens.inkTertiary,
                    ),
                  ),
                ),
              ),
            ),
          EditableText(
            controller: _controller,
            focusNode: _node,
            style: CullType.bodyM.copyWith(color: CullTokens.inkPrimary),
            cursorColor: CullTokens.signalDim,
            backgroundCursorColor: CullTokens.surface3,
            maxLines: widget.maxLines,
            autofocus: widget.autofocus,
            keyboardType: widget.keyboardType,
            textInputAction: widget.onSubmitted == null
                ? TextInputAction.done
                : TextInputAction.go,
            onSubmitted: widget.onSubmitted,
            selectionColor: CullTokens.signalSoft,
          ),
        ],
      ),
    );
  }
}
