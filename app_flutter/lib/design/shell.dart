import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'controls.dart';
import 'glyphs.dart';
import 'tokens.g.dart';
import 'type.dart';

class CullApp extends StatelessWidget {
  const CullApp({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: WidgetsApp(
        color: CullTokens.canvas,
        textStyle: CullType.bodyM,
        title: 'CULL',
        onGenerateRoute: (_) => CullRoute<void>(builder: (_) => child),
        builder: (context, navigator) => ColoredBox(
          color: CullTokens.canvas,
          child: CullToastHost(
            child: MediaQuery.withClampedTextScaling(
              minScaleFactor: 1,
              maxScaleFactor: 2,
              child: navigator ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }

  static const SystemUiOverlayStyle overlay = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: CullTokens.canvas,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Color(0x00000000),
  );
}

class CullPage extends StatelessWidget {
  const CullPage({
    super.key,
    required this.child,
    this.title,
    this.eyebrow,
    this.trailing,
    this.padded = true,
    this.controller,
  });

  final Widget child;
  final String? title;
  final String? eyebrow;
  final Widget? trailing;
  final bool padded;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CullTokens.canvas,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              CullPageHeader(
                title: title!,
                eyebrow: eyebrow,
                trailing: trailing,
              ),
            Expanded(
              child: padded
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CullTokens.spaceLg,
                      ),
                      child: child,
                    )
                  : child,
            ),
          ],
        ),
      ),
    );
  }
}

class CullPageHeader extends StatelessWidget {
  const CullPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CullTokens.spaceLg,
        CullTokens.spaceMd,
        CullTokens.spaceLg,
        CullTokens.spaceLg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (canPop) ...[
            CullIconButton(
              icon: const CullGlyph(CullIcon.back),
              label: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: CullTokens.spaceSm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: CullType.monoXs.copyWith(
                      color: CullTokens.inkTertiary,
                    ),
                  ),
                  const SizedBox(height: CullTokens.spaceXs),
                ],
                Text(title, style: CullType.titleL),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: CullTokens.spaceMd),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class CullScroll extends StatelessWidget {
  const CullScroll({
    super.key,
    required this.child,
    this.controller,
    this.padding = const EdgeInsets.only(bottom: CullTokens.spaceN4xl),
  });

  final Widget child;
  final ScrollController? controller;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return RawScrollbar(
      controller: controller,
      thumbColor: CullTokens.inkDisabled.withValues(alpha: 0.5),
      radius: const Radius.circular(999),
      thickness: 4,
      child: SingleChildScrollView(
        controller: controller,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

class CullToast {
  const CullToast(this.dismissed);

  final VoidCallback dismissed;

  static CullToast show(BuildContext context, String message, {Color? tint}) {
    final host = CullToastHost.of(context);
    host?.push(message, tint: tint);
    return CullToast(() => host?.clear());
  }
}

class CullToastHost extends StatefulWidget {
  const CullToastHost({super.key, required this.child});

  final Widget child;

  static ToastController? of(BuildContext context) =>
      context.findAncestorStateOfType<_CullToastHostState>();

  @override
  State<CullToastHost> createState() => _CullToastHostState();
}

abstract class ToastController {
  void push(String message, {Color? tint});
  void clear();
}

class _CullToastHostState extends State<CullToastHost>
    implements ToastController {
  ToastMessage? _current;
  int _token = 0;
  Timer? _timer;

  @override
  void push(String message, {Color? tint}) {
    _timer?.cancel();
    final token = ++_token;
    setState(() => _current = ToastMessage(message: message, tint: tint));
    _timer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted || token != _token) return;
      clear();
    });
  }

  @override
  void clear() {
    _timer?.cancel();
    _timer = null;
    if (!mounted) return;
    if (_current == null) return;
    setState(() => _current = null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_current != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Toast(message: _current!),
          ),
      ],
    );
  }
}

class ToastMessage {
  const ToastMessage({required this.message, this.tint});

  final String message;
  final Color? tint;
}

class _Toast extends StatelessWidget {
  const _Toast({required this.message});

  final ToastMessage message;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: CullTokens.motionSettle,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 24),
          child: child,
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: CullTokens.spaceLg,
          vertical: CullTokens.spaceMd,
        ),
        decoration: BoxDecoration(
          color: message.tint ?? CullTokens.signalDeep,
          border: Border(
            top: BorderSide(
              color: (message.tint ?? CullTokens.signalDeep).withValues(
                alpha: 0.9,
              ),
              width: 2,
            ),
          ),
        ),
        child: Text(
          message.message,
          style: CullType.titleM.copyWith(color: CullTokens.inkInverse),
        ),
      ),
    );
  }
}

Future<bool> cullConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Do it',
  String cancelLabel = 'Back',
  bool destructive = true,
}) async {
  final result = await Navigator.of(context).push<bool>(
    CullRoute(
      modal: true,
      builder: (context) => _CullConfirm(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    ),
  );
  return result ?? false;
}

class _CullConfirm extends StatelessWidget {
  const _CullConfirm({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return CullScrim(
      onDismiss: () => Navigator.of(context).pop(false),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(CullTokens.spaceXl),
          child: CullSurface(
            background: CullTokens.surface4,
            radius: CullTokens.radiusLg,
            padding: const EdgeInsets.all(CullTokens.spaceXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: CullType.displayS),
                const SizedBox(height: CullTokens.spaceMd),
                Text(message, style: CullType.bodyM),
                const SizedBox(height: CullTokens.spaceXl),
                CullButton(
                  label: confirmLabel,
                  kind: destructive
                      ? CullButtonKind.danger
                      : CullButtonKind.primary,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
                const SizedBox(height: CullTokens.spaceSm),
                CullButton(
                  label: cancelLabel,
                  kind: CullButtonKind.ghost,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> cullSheet<T>(BuildContext context, Widget child) {
  return Navigator.of(context)
      .push<T>(CullRoute(modal: true, builder: (_) => child));
}

class CullScrim extends StatelessWidget {
  const CullScrim({super.key, required this.child, this.onDismiss});

  final Widget child;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: CullTokens.scrim,
        child: SafeArea(child: child),
      ),
    );
  }
}

class CullRoute<T> extends PageRouteBuilder<T> {
  CullRoute({required WidgetBuilder builder, bool modal = false})
    : super(
        opaque: !modal,
        barrierColor: modal ? CullTokens.scrim : const Color(0x00000000),
        barrierDismissible: modal,
        transitionDuration: CullTokens.motionSettle,
        reverseTransitionDuration: CullTokens.motionInstant,
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
}

class CullLoading extends StatefulWidget {
  const CullLoading({super.key, this.label});

  final String? label;

  @override
  State<CullLoading> createState() => _CullLoadingState();
}

class _CullLoadingState extends State<CullLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 34,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _PulsePainter(_c.value, CullTokens.signalDim),
              ),
            ),
          ),
          if (widget.label != null) ...[
            const SizedBox(height: CullTokens.spaceMd),
            Text(widget.label!, style: CullType.bodyS),
          ],
        ],
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  const _PulsePainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(r, r);
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      final radius = r * (0.35 + p * 0.65);
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withValues(alpha: (1 - p) * 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t;
}
