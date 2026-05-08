import 'package:flutter/material.dart';
import 'package:pointer_app/core/errors/app_exceptions.dart';
import 'package:pointer_app/core/utils/l10n_ext.dart';

class ErrorBoundary extends StatelessWidget {
  const ErrorBoundary({
    super.key,
    required this.exception,
    required this.onRetry,
    required this.child,
  });

  final AppException? exception;
  final VoidCallback onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final exception = this.exception;
    if (exception == null) return child;

    final scheme = Theme.of(context).colorScheme;
    final msg = exception.userMessage(context.l10n);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onRetry,
                  child: Text(context.l10n.retry),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
