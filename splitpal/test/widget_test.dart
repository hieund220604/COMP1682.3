import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:splitpal/core/theme/app_theme.dart';
import 'package:splitpal/core/widgets/app_card.dart';
import 'package:splitpal/core/widgets/app_empty_state.dart';

void main() {
  test('AppTheme.light builds', () {
    final theme = AppTheme.light();
    expect(theme.useMaterial3, isTrue);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'BeVietnamPro');
    expect(theme.colorScheme.primary, isNotNull);
  });

  testWidgets('AppCard renders its child', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppCard(child: Text('Hello')),
        ),
      ),
    );
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('AppEmptyState renders title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppEmptyState(title: 'Nothing here'),
        ),
      ),
    );
    expect(find.text('Nothing here'), findsOneWidget);
  });
}
