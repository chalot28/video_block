import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_block/main.dart';

void main() {
  testWidgets('App boots and shows browser shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MiniBrowserApp());
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Tab mới'), findsOneWidget);
  });
}
