// test/widget/id_presentation_enhanced_test.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/id_presentation_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureCalls = <String>[];
  setUp(() {
    secureCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.suivault.app/secure'),
      (call) async {
        secureCalls.add(call.method);
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('github.com/aaassseee/screen_brightness'),
      (call) async {
        if (call.method == 'getApplicationScreenBrightness') {
          return 0.5;
        }
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.suivault.app/secure'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('github.com/aaassseee/screen_brightness'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  testWidgets('large text mode can be toggled by tapping number bar or 放大 button',
      (tester) async {
    final now = DateTime.now();
    final record = RecordDetail(
      record: RecordModel(
        id: 'id-test',
        title: '我的身份证',
        body: '证件类型：居民身份证\n姓名：王五\n证件号码：310101199001011234',
        isFavorite: false,
        createdAt: now,
        updatedAt: now,
      ),
      tags: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: IdPresentationPage(record: record),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial display: number bar contains formatted number
    expect(find.textContaining('3101'), findsWidgets);

    // Tap "放大" button -> toggles large text mode
    await tester.tap(find.text('放大'));
    await tester.pumpAndSettle();

    // Zoom-out indicator icon appears when large text is active
    expect(find.byIcon(Icons.zoom_out_map_rounded), findsOneWidget);

    // Tap number bar again -> toggles back
    await tester.tap(find.byIcon(Icons.zoom_out_map_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.zoom_out_map_rounded), findsNothing);
  });

  testWidgets('pull-down drag closes IdPresentationPage', (tester) async {
    final now = DateTime.now();
    final record = RecordDetail(
      record: RecordModel(
        id: 'id-test',
        title: '测试证件',
        body: '证件类型：护照\n姓名：赵六\n证件号码：E12345678',
        isFavorite: false,
        createdAt: now,
        updatedAt: now,
      ),
      tags: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => IdPresentationPage.show(context, record),
              child: const Text('Open ID'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open presentation page
    await tester.tap(find.text('Open ID'));
    await tester.pumpAndSettle();

    expect(find.text('测试证件'), findsOneWidget);

    // Drag downward on screen (fling down)
    await tester.fling(find.text('测试证件'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    // Presentation page closed, back to previous page
    expect(find.text('Open ID'), findsOneWidget);
  });
}
