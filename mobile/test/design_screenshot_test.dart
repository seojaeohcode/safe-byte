import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safebyte_mobile/l10n.dart';
import 'package:safebyte_mobile/main.dart';
import 'package:safebyte_mobile/workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadKoreanFonts);

  testWidgets('bottom navigation connects cart history and saved products', (tester) async {
    await _setPhoneViewport(tester);
    final api = _PreviewApi();
    await tester.pumpWidget(_PreviewShell(child: HomeScreen(api: api, token: 'preview', user: _previewUser, onLogout: () {}, onUserChanged: (_) {})));
    await _settlePreview(tester);
    await tester.tap(find.text('장바구니').last);
    await tester.pumpAndSettle();
    expect(find.text('주말 장보기'), findsOneWidget);
    await tester.tap(find.text('기록').last);
    await tester.pumpAndSettle();
    expect(find.text('아직 분석 기록이 없습니다.'), findsOneWidget);
    await tester.tap(find.text('내 정보').last);
    await tester.pumpAndSettle();
    await _capture('my_account.png');
    await tester.tap(find.text('저장한 상품'));
    await tester.pumpAndSettle();
    expect(find.text('쌀과자'), findsOneWidget);
    expect(api.paths, containsAll(['/api/v1/carts', '/api/v1/history', '/api/v1/family', '/api/v1/products']));
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture family editor in existing design', (tester) async {
    await _setPhoneViewport(tester);
    await tester.pumpWidget(const _PreviewShell(child: ProfileEditor(
      initialProfiles: ['vegan'], cart: false, initialName: '우리 가족')));
    await _settlePreview(tester);
    expect(tester.takeException(), isNull);
    await _capture('family_profile.png');
  });

  testWidgets('capture cart in existing design', (tester) async {
    await _setPhoneViewport(tester);
    await tester.pumpWidget(_PreviewShell(child: CartScreen(api: _PreviewApi(), token: 'preview',
      cart: const {'id': 'preview', 'name': '오늘 장보기'})));
    await _settlePreview(tester);
    expect(tester.takeException(), isNull);
    await _capture('shopping_cart.png');
  });

  testWidgets('capture auth screen', (tester) async {
    await _setPhoneViewport(tester);
    await tester.pumpWidget(
      _PreviewShell(
        child: AuthScreen(
          api: _PreviewApi(),
          onAuthenticated: (_) async {},
        ),
      ),
    );
    await _settlePreview(tester);
    await _capture('auth_onboarding.png');
  });

  testWidgets('interface follows the chosen language, right to left for Arabic',
      (tester) async {
    await _setPhoneViewport(tester);
    addTearDown(() => appLanguage.select('ko'));

    await appLanguage.select('en');
    await tester.pumpWidget(_PreviewShell(
        child: AuthScreen(api: _PreviewApi(), onAuthenticated: (_) async {})));
    await _settlePreview(tester);
    expect(find.text('Login'), findsWidgets);
    expect(find.text('로그인'), findsNothing);
    await _capture('auth_english.png');

    await appLanguage.select('ar');
    await tester.pumpWidget(_PreviewShell(
        child: AuthScreen(api: _PreviewApi(), onAuthenticated: (_) async {})));
    await _settlePreview(tester);
    expect(Directionality.of(tester.element(find.byType(AuthScreen))),
        TextDirection.rtl);
    expect(find.text('로그인'), findsNothing);
    expect(tester.takeException(), isNull);
    await _capture('auth_arabic.png');
  });

  testWidgets('capture home scan screen', (tester) async {
    await _setPhoneViewport(tester);
    await tester.pumpWidget(
      _PreviewShell(
        child: HomeScreen(
          api: _PreviewApi(),
          token: 'preview',
          user: _previewUser,
          onLogout: () {},
          onUserChanged: (_) {},
        ),
      ),
    );
    await _settlePreview(tester);
    await _capture('home_scan.png');
  });

  testWidgets('capture preferences screen', (tester) async {
    await _setPhoneViewport(tester);
    await tester.pumpWidget(
      _PreviewShell(
        child: PreferencesScreen(
          api: _PreviewApi(),
          token: 'preview',
          user: _previewUser,
        ),
      ),
    );
    await _settlePreview(tester);
    await _capture('preferences_allergy.png');
  });

  testWidgets('capture result screen', (tester) async {
    await _setPhoneViewport(tester);
    await tester.pumpWidget(
      const _PreviewShell(
        child: ResultScreen(result: _previewResult),
      ),
    );
    await _settlePreview(tester);
    await _capture('result_danger.png');
  });
}

Future<void> _loadKoreanFonts() async {
  final loader = FontLoader('NotoSansKR');
  for (final suffix in ['Regular', 'Bold']) {
    final bytes = await File('assets/fonts/NotoSansKR-$suffix.ttf').readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();

  // Arabic is a theme fallback family, so the RTL screenshots need it too.
  final arabic = FontLoader('NotoSansArabic');
  final arabicBytes =
      await File('assets/fonts/NotoSansArabic-Regular.ttf').readAsBytes();
  arabic.addFont(Future.value(ByteData.sublistView(arabicBytes)));
  await arabic.load();

  final iconFile = File(
    r'C:\flutter_sdk\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
  );
  if (iconFile.existsSync()) {
    final iconLoader = FontLoader('MaterialIcons');
    final bytes = await iconFile.readAsBytes();
    iconLoader.addFont(
      Future.value(ByteData.sublistView(Uint8List.fromList(bytes))),
    );
    await iconLoader.load();
  }
}

const _previewUser = AppUser(
  userId: 'preview-user',
  email: 'preview@safebyte.test',
  displayName: '테스터',
  profiles: [
    'halal',
    'vegan',
    'allergy:milk',
    'allergy:wheat',
    'allergy:peanut',
  ],
  allergyNotes: '',
);

const _previewResult = AnalysisResult(
  requestId: 'preview-001',
  finalLevel: 'DANGER',
  summary: '직접 함유 위험 성분: 우유/유제품, 밀/글루텐. 제조시설 공유 표기: 땅콩.',
  ocrProvider: 'clova',
  cacheLabel: 'miss',
  paid: true,
  ocrText: '원재료명: 밀가루, 전지분유, 대두레시틴\n우유, 밀, 대두 함유',
  directDetections: [
    Detection(
      category: 'allergy',
      severity: 'danger',
      name: '우유/유제품',
      keyword: '전지분유',
      reason: '사용자 기준에 포함된 우유 성분이 원재료명에서 확인되었습니다.',
      occurrenceType: 'ingredient',
      label: '직접 함유',
    ),
    Detection(
      category: 'allergy',
      severity: 'danger',
      name: '밀/글루텐',
      keyword: '밀가루',
      reason: '사용자 기준에 포함된 밀 성분이 원재료명에서 확인되었습니다.',
      occurrenceType: 'ingredient',
      label: '직접 함유',
    ),
  ],
  facilityDetections: [
    Detection(
      category: 'allergy',
      severity: 'caution',
      name: '땅콩',
      keyword: '땅콩',
      reason: '직접 원재료가 아니라 같은 제조시설 문구에서 감지되었습니다.',
      occurrenceType: 'cross_contact',
      label: '제조시설 공유',
    ),
  ],
);

class _PreviewApi extends SafeByteApi {
  _PreviewApi() : super('http://preview.local');
  final paths = <String>[];

  @override
  Future<Map<String, dynamic>> request(String method, String path, String token, {Map<String, dynamic>? body}) async {
    paths.add(path);
    if (path == '/api/v1/family') return {'profiles': []};
    if (path == '/api/v1/history') return {'analyses': []};
    if (path == '/api/v1/products') return {'products': [{'id': 'product', 'name': '쌀과자', 'category': '과자', 'source_request_id': 'preview'}]};
    if (path == '/api/v1/carts') return {'carts': [{'id': 'preview', 'name': '주말 장보기', 'status': 'active', 'profiles': ['vegan'], 'language': 'ko'}]};
    return {
    'cart': {'status': 'active'}, 'items': [], 'counts': {'SAFE': 0, 'CAUTION': 0, 'DANGER': 0},
    'final_level': 'EMPTY', 'total_quantity': 0,
    'nutrition': {'totals': {}, 'covered_quantity': {}, 'note': '확인하지 않은 값은 합계에 포함하지 않습니다.'},
    };
  }

  @override
  Future<OcrHealth> ocrHealth() async {
    return const OcrHealth(dailyLimit: 10, usageToday: 2);
  }

  @override
  Future<CostSummary> costs() async {
    return const CostSummary(
      ncloudCostKrw: 0,
      ocrCostKrw: 0,
      cacheConnected: true,
    );
  }
}

class _PreviewShell extends StatelessWidget {
  const _PreviewShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(key: _captureKey, child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: safeByteTheme(),
      locale: appLanguage.locale,
      supportedLocales: uiLanguages.keys.map(Locale.new),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      localeResolutionCallback: (_, __) => appLanguage.locale,
      builder: (context, inner) => Directionality(
          textDirection: appLanguage.direction,
          child: inner ?? const SizedBox.shrink()),
        home: child,
      ),
    );
  }
}

final _captureKey = GlobalKey();

Future<void> _setPhoneViewport(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(786, 1704);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _settlePreview(WidgetTester tester) async {
  await tester.runAsync(() => precacheImage(const AssetImage('assets/app_logo.png'), tester.element(find.byKey(_captureKey))));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _capture(String fileName) async {
  await expectLater(
    find.byKey(_captureKey),
    matchesGoldenFile('design_review/$fileName'),
  );
}
