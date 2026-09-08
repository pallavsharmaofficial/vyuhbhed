import 'package:flutter/material.dart';

/// Asks for one piece of text and returns it, or null if cancelled.
///
/// The controller lives inside the dialog rather than at the call site. A
/// caller that creates a controller, awaits `showDialog` and then disposes it
/// disposes it *during the dialog's exit animation*, while the TextField is
/// still rebuilding — which throws "A TextEditingController was used after
/// being disposed" and takes the frame with it.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  required String saveLabel,
  required String cancelLabel,
  String initialValue = '',
  String? label,
  String? hint,
  String? helper,
  int maxLines = 1,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextPromptDialog(
      title: title,
      saveLabel: saveLabel,
      cancelLabel: cancelLabel,
      initialValue: initialValue,
      label: label,
      hint: hint,
      helper: helper,
      maxLines: maxLines,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.saveLabel,
    required this.cancelLabel,
    required this.initialValue,
    required this.maxLines,
    this.label,
    this.hint,
    this.helper,
  });

  final String title;
  final String saveLabel;
  final String cancelLabel;
  final String initialValue;
  final String? label;
  final String? hint;
  final String? helper;
  final int maxLines;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: widget.maxLines,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: widget.maxLines == 1
            ? (value) => Navigator.of(context).pop(value)
            : null,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          helperText: widget.helper,
          helperMaxLines: 3,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.saveLabel),
        ),
      ],
    );
  }
}
