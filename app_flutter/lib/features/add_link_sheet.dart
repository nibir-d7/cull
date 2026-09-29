import 'package:flutter/widgets.dart';

import '../data/hoard_repository.dart';
import '../design/components.dart';
import '../design/controls.dart';
import '../design/glyphs.dart';
import '../design/shell.dart';
import '../design/tokens.g.dart';
import '../design/type.dart';
import '../engine/cull_ffi.dart';

class AddLinkSheet extends StatefulWidget {
  const AddLinkSheet({super.key, required this.repository, this.initialUrl});

  final HoardRepository repository;
  final String? initialUrl;

  static Future<bool?> show(
    BuildContext context, {
    required HoardRepository repository,
    String? initialUrl,
  }) {
    return cullSheet<bool>(
      context,
      AddLinkSheet(repository: repository, initialUrl: initialUrl),
    );
  }

  @override
  State<AddLinkSheet> createState() => _AddLinkSheetState();
}

class _AddLinkSheetState extends State<AddLinkSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialUrl ?? '',
  );
  final FocusNode _focus = FocusNode();
  bool _busy = false;
  String? _error;
  SaveOutcome? _result;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focus.requestFocus(),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'A URL, or a title. Anything at all.');
      return;
    }
    _focus.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await widget.repository.save(url);
      if (mounted) setState(() => _result = outcome);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CullScrim(
      onDismiss: () => Navigator.of(context).pop(false),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: CullTokens.surface4,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(CullTokens.radiusXl),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              CullTokens.spaceLg,
              CullTokens.spaceXl,
              CullTokens.spaceLg,
              MediaQuery.viewInsetsOf(context).bottom + CullTokens.spaceXl,
            ),
            child: _result != null ? _done() : _form(),
          ),
        ],
      ),
    );
  }

  Widget _form() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('SAVE A LINK', style: CullType.monoXs),
            const Spacer(),
            CullGlyphButton(
              icon: CullIcon.close,
              label: 'Close',
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
        const SizedBox(height: CullTokens.spaceMd),
        Text('Paste a link', style: CullType.displayS),
        const SizedBox(height: CullTokens.spaceSm),
        Text(
          'Or share one to CULL from any other app, which is the quicker way.',
          style: CullType.bodyM,
        ),
        const SizedBox(height: CullTokens.spaceLg),
        CullField(
          controller: _controller,
          hint: 'https://example.com/the-thing-you-will-not-read',
          onSubmitted: (_) => _save(),
          keyboardType: TextInputType.url,
        ),
        if (_error != null) ...[
          const SizedBox(height: CullTokens.spaceSm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CullGlyph(
                CullIcon.close,
                size: 14,
                color: CullTokens.dangerDim,
              ),
              const SizedBox(width: CullTokens.spaceSm),
              Expanded(
                child: Text(
                  _error!,
                  style: CullType.bodyS.copyWith(color: CullTokens.dangerDim),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: CullTokens.spaceLg),
        CullButton(
          label: _busy ? 'Fetching and scoring' : 'Save it',
          expand: true,
          onPressed: _busy ? null : _save,
        ),
      ],
    );
  }

  Widget _done() {
    final r = _result!;
    final band = r.score >= 86
        ? 3
        : r.score >= 60
        ? 2
        : r.score >= 30
        ? 1
        : 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('SAVED', style: CullType.monoXs),
            const Spacer(),
            CullGlyphButton(
              icon: CullIcon.close,
              label: 'Close',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
        const SizedBox(height: CullTokens.spaceLg),
        Wrap(
          spacing: CullTokens.spaceSm,
          runSpacing: CullTokens.spaceSm,
          children: [
            CategoryPill(category: r.category),
            CullTag(
              label: 'score ${r.score.round()}',
              foreground: bandGraphic(band),
              background: bandColor(band).withValues(alpha: 0.22),
              monospace: true,
            ),
          ],
        ),
        if (r.roast.isNotEmpty) ...[
          const SizedBox(height: CullTokens.spaceLg),
          RoastCard(line: r.roast),
        ],
        const SizedBox(height: CullTokens.spaceLg),
        CullButton(
          label: 'Back to the hoard',
          expand: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
