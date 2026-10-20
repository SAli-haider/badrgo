import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reusable loading indicator for async ops views.
class OpsLoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;

  const OpsLoadingIndicator({
    super.key,
    this.message,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
