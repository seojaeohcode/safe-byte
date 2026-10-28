import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safebyte_mobile/main.dart';
import 'package:safebyte_mobile/workspace.dart';

class TestApi extends SafeByteApi {
  TestApi() : super('http://localhost');
  @override
  Future<Map<String, dynamic>> request(String method, String path, String token,
          {Map<String, dynamic>? body}) async =>
      {
        'cart': {'status': 'closed'},
        'items': [],
        'counts': {},
        'final_level': 'EMPTY',
        'total_quantity': 0,
        'nutrition': {
          'totals': {},
          'covered_quantity': {},
          'note': 'No verified values'
        },
      };
}

void main() {
  testWidgets('editing family keeps its name and offers no language of its own',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: ProfileEditor(
            initialProfiles: ['vegan'], cart: false, initialName: '가족 A')));
    expect(find.text('가족 A'), findsOneWidget);
    // Language belongs to the interface now, not to each set of criteria.
    expect(find.text('결과 언어'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closed cart does not permit scans or pairing', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: CartScreen(
            api: TestApi(),
            token: 'test',
            cart: const {'id': 'cart', 'name': 'Family'})));
    await tester.pumpAndSettle();
    expect(find.text('아직 담은 상품이 없어요'), findsOneWidget);
    expect(find.text('이 기준으로 스캔'), findsNothing);
    expect(find.text('카트 기기 연결'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('family editor requires a name and criteria', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: ProfileEditor(initialProfiles: [], cart: false)));
    await tester.scrollUntilVisible(find.text('저장'), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('저장'));
    await tester.pump();
    expect(find.text('이름과 검사 기준을 입력해주세요.'), findsOneWidget);
  });
}
