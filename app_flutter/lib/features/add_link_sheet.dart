import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/hoard_repository.dart';
import '../design/components.dart';
import '../design/tokens.g.dart';
import '../engine/cull_ffi.dart';

class AddLinkSheet extends StatefulWidget {
  const AddLinkSheet({
    super.key,
    required this.repository,
    this.initialUrl,
  });

  final HoardRepository repository;
  final String? initialUrl;

  static Future<bool?> show(
    BuildContext context, {
    required HoardRepository repository,
    String? initialUrl,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddLinkSheet(
        repository: repository,
        initialUrl: initialUrl,
      ),
    );
  }

  @override
  State<AddLinkSheet> createState() => _AddLinkSheetState();
}

class _AddLinkSheetState extends State<AddLinkSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialUrl ?? '',
  );
  bool _busy = false;
  String? _error;
  SaveOutcome? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'A URL, please. Or a title. Literally anything.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await widget.repository.save(url);
      if (mounted) setState(() => _result = outcome);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: const BoxDecoration(
          color: CullTokens.surface3,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(CullTokens.radiusXl),
          ),
        ),
        padding: const EdgeInsets.all(CullTokens.spaceLg),
        child: _result != null ? _done(t) : _form(t),
      ),
    );
  }

  Widget _form(ThemeData t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Save a link', style: t.textTheme.headlineMedium),
        const SizedBox(height: CullTokens.spaceSm),
        Text(
          'Paste it, or share it to CULL from any other app.',
          style: t.textTheme.bodyMedium,
        ),
        const SizedBox(height: CullTokens.spaceLg),
        TextField(
          controller: _controller,
          autofocus: widget.initialUrl == null,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _save(),
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          decoration: InputDecoration(
            hintText: 'https://example.com/the-thing-you-will-not-read',
            errorText: _error,
            suffixIcon: IconButton(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: CullTokens.signal,
                      ),
                    )
                  : const Icon(Icons.arrow_downward),
              tooltip: 'Save',
            ),
          ),
        ),
        const SizedBox(height: CullTokens.spaceMd),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Fetching and judging' : 'Save it'),
        ),
      ],
    );
  }

  Widget _done(ThemeData t) {
    final r = _result!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: CullTokens.spaceXs,
          runSpacing: CullTokens.spaceXs,
          children: [
            Pill(
              label: r.category,
              color: categoryColor(r.category),
              surface: categorySurface(r.category),
            ),
            Pill(
              label: 'score ${r.score.round()}',
              color: bandColor(
                r.score >= 86
                    ? 3
                    : r.score >= 60
                    ? 2
                    : r.score >= 30
                    ? 1
                    : 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: CullTokens.spaceMd),
        if (r.roast.isNotEmpty)
          RoastCard(line: r.roast, tone: RoastAccent.blunt),
        const SizedBox(height: CullTokens.spaceMd),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Fine'),
        ),
      ],
    );
  }
}
