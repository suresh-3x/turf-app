import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void showSnackBar(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final scheme = Theme.of(context).colorScheme;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? scheme.error : null),
    );
}

/// Turns an exception from Supabase or elsewhere into a sentence for the user.
String friendlyError(Object error) {
  if (error is AuthException) return error.message;
  if (error is PostgrestException) {
    switch (error.code) {
      case '23P01':
        return 'That time overlaps a slot you already have.';
      case '23505':
        return 'That already exists.';
      case '23514':
        return 'Some of the values are not allowed. Please check and try again.';
      case '42501':
        return "You don't have permission to do that.";
      // Messages raised by our own database functions are written for users.
      case 'P0001':
        return error.message;
    }
    return error.message;
  }
  final text = error.toString();
  if (text.contains('SocketException') || text.contains('ClientException')) {
    return 'Could not reach the server. Check your internet connection.';
  }
  return text.replaceFirst('Exception: ', '');
}

/// Asks the user to confirm an action. Returns true if they did.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Back')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
