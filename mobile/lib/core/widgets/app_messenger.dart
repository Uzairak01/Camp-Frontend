import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Global root ScaffoldMessengerKey used to surface notifications and error snackbars
/// across the application, including from controllers and services.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Displays the standardized failure snackbar "Could not save, please try again".
void showSaveErrorSnackBar([BuildContext? context]) {
  final messenger = context != null
      ? ScaffoldMessenger.maybeOf(context) ?? rootScaffoldMessengerKey.currentState
      : rootScaffoldMessengerKey.currentState;
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(
    const SnackBar(
      content: Text('Could not save, please try again'),
      duration: Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.alertRed,
    ),
  );
}
