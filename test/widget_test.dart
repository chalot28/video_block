import 'package:flutter_test/flutter_test.dart';

import 'package:video_block/main.dart';

void main() {
  testWidgets('Video app renders source actions', (WidgetTester tester) async {
    await tester.pumpWidget(const VideoBlockApp());
    await tester.pump();

    expect(find.text('Load URL'), findsOneWidget);
    expect(find.text('Pick File'), findsOneWidget);
    expect(find.text('Ad-block'), findsOneWidget);
  });
}
