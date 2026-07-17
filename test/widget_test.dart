import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:desktop/app/sales_erp_app.dart';

void main() {
  testWidgets('shows the sales ERP login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SalesErpApp());

    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Sales ERP'), findsWidgets);
  });
}
