import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// DELETE CONFIRM DIALOG
///
/// Reusable confirmation dialog for destructive actions.
/// Returns true if the user confirms, false/null otherwise.
/// ─────────────────────────────────────────────────────────────────────────────
class DeleteConfirmDialog extends StatelessWidget {
  final String title;
  final String message;

  const DeleteConfirmDialog({
    super.key,
    required this.title,
    required this.message,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) =>
          DeleteConfirmDialog(title: title, message: message),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Icon(Icons.delete_outline_rounded,
          color: colorScheme.error, size: 32),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
