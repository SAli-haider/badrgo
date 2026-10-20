import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:badrgo_ops_console/core/theme/app_colors.dart';
import 'package:badrgo_ops_console/core/widgets/ops_badge.dart';

void main() {
  testWidgets('OpsBadge renders label and color correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OpsBadge(
            label: 'AVAILABLE',
            color: AppColors.success,
          ),
        ),
      ),
    );

    expect(find.text('AVAILABLE'), findsOneWidget);
  });
}
