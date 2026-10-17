// test/widget/record_card_iddoc_test.dart
// Round 6 §1: RecordCard with a new-format ID document body must never
// show raw JSON, must show the per-type icon and "type · masked number"
// preview, and must expose the copy button.

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/records/domain/id_doc_codec.dart';
import 'package:suicun/features/records/domain/id_doc_data.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/home_sort_provider.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/shared/utils/mask_doc_number.dart';
import 'package:suicun/shared/widgets/record_card.dart';

RecordDetail _idDocRecord({required String body}) {
  final now = DateTime.now();
  return RecordDetail(
    record: RecordModel(
      id: 'iddoc-1',
      title: '',
      body: body,
      isFavorite: false,
      createdAt: now,
      updatedAt: now,
    ),
    tags: const [],
  );
}

Widget _wrap(RecordDetail record) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SlidableAutoCloseBehavior(
        child: ListView(
          children: [
            RecordCard(
              record: record,
              sortMode: RecordSortMode.byUpdatedAt,
              isSelected: false,
              isMultiSelectMode: false,
              onTap: () {},
              onLongPress: () {},
              onFavoriteToggle: () {},
              isQuickAccess: false,
              onQuickAccessToggle: () {},
              onEdit: () {},
              onChangeCategory: () {},
              onDelete: () {},
              untitledLabel: '无标题',
              uncategorizedLabel: '未分类',
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'new-format ID body renders type + masked number, never raw JSON, '
      'and shows copy button', (tester) async {
    final body = encodeIdDocBody(
      const IdDocData(
        type: 'passport',
        name: '张三',
        number: 'E12345678',
      ),
    );
    // Sanity: the body really is the new JSON format.
    expect(isIdDocBody(body), isTrue);

    await tester.pumpWidget(_wrap(_idDocRecord(body: body)));
    await tester.pumpAndSettle();

    // The masked number for E12345678 is E1*****78.
    final masked = maskDocNumber('E12345678');
    expect(masked, 'E1*****78');

    // Preview row shows "护照 · E1*****78".
    expect(find.textContaining('护照'), findsWidgets);
    expect(find.textContaining(masked), findsOneWidget);

    // Raw JSON must never appear.
    expect(find.textContaining('suivault:id_doc'), findsNothing);
    expect(find.textContaining('{"type"'), findsNothing);
    expect(find.textContaining('"passport"'), findsNothing);

    // Copy button is shown (idDocument now has extractable number).
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

    // Per-type icon: passport -> flight_takeoff_outlined.
    expect(find.byIcon(Icons.flight_takeoff_outlined), findsOneWidget);
    // Generic badge icon must not be used for ID documents.
    expect(find.byIcon(Icons.badge_outlined), findsNothing);
  });

  testWidgets('legacy label:value ID body also renders without raw text',
      (tester) async {
    const legacyBody = '证件类型：护照\n姓名：张三\n证件号码：E12345678';
    expect(isIdDocBody(legacyBody), isTrue);

    await tester.pumpWidget(_wrap(_idDocRecord(body: legacyBody)));
    await tester.pumpAndSettle();

    expect(find.textContaining('护照'), findsWidgets);
    expect(find.textContaining('E12345678'), findsNothing);
    expect(find.textContaining('证件类型'), findsNothing);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
  });
}
