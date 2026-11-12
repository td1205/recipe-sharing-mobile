import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A predictable back action for screens that may also be opened by deep link.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, required this.fallbackLocation});

  final String fallbackLocation;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('app-back-button'),
    tooltip: 'Quay lại',
    onPressed: () {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(fallbackLocation);
      }
    },
    icon: const Icon(Icons.arrow_back_rounded),
  );
}
