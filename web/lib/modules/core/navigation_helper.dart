import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class NavigationHelper {
  static void pushReplacement(BuildContext context, Widget destination) {
    if (context.mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => destination));
    }
  }

  static Future<T?> push<T>(BuildContext context, Widget destination) {
    return Navigator.of(
      context,
    ).push<T>(MaterialPageRoute(builder: (context) => destination));
  }

  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.of(context).pop(result);
  }

  static bool canPop(BuildContext context) {
    return Navigator.of(context).canPop();
  }

  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration? duration,
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : null,
          duration: duration ?? const Duration(seconds: 3),
        ),
      );
    }
  }
}
