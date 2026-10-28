import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safebyte_mobile/main.dart';
import 'package:safebyte_mobile/main_preview.dart';
import 'package:safebyte_mobile/preview_api.dart';
import 'package:safebyte_mobile/l10n.dart';
import 'package:safebyte_mobile/v2_strings.dart';
import 'package:safebyte_mobile/workspace.dart';

final captureKey = GlobalKey();
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in [
      'NotoSansKR',
      'NotoSansArabic',
      'NotoSansJP',
      'NotoSansSC'
    ]) {
      final loader = FontLoader(family);
      for (final weight
          in family == 'NotoSansArabic' ? ['Regular'] : ['Regular', 'Bold']) {
        loader.addFont(Future.value(ByteData.sublistView(
            await File('assets/fonts/$family-$weight.ttf').readAsBytes())));
      }
      await loader.load();
    }
    final flutterRoot =
        Platform.environment['FLUTTER_ROOT'] ?? r'C:\flutter_sdk\flutter';
    final loader = FontLoader('MaterialIcons');
    loader.addFont(Future.value(ByteData.sublistView(await File(
            '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
        .readAsBytes())));
    await loader.load();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  for (final name in [
    'splash',
    'login',
    'criteria',
    'home_scan',
    'analyzing',
    'result_safe',
    'result_caution',
    'result_danger',
    'detail',
    'cart',
    'pairing_code',
    'family'
  ]) {
    testWidgets('1080 × 2340 / $name', (tester) async {
      await viewport(tester);
      await tester.pumpWidget(shell(previewScreen(name, PreviewApi())));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await capture(tester, name);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
      'bottom navigation, account, history, saved products and cart detail',
      (tester) async {
    await viewport(tester);
    final api = PreviewApi();
    await tester.pumpWidget(shell(previewScreen('home_scan', api)));
    await settle(tester);
    await tester.tap(find.text('기록').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('scaled_'), findsNothing);
    expect(find.text('라벨 사진'), findsOneWidget);
    await capture(tester, 'history');
    await tester.tap(find.text('내 정보').last);
    await tester.pumpAndSettle();
    await capture(tester, 'account');
    await tester.tap(find.text('저장한 상품'));
    await tester.pumpAndSettle();
    expect(find.text('쌀과자'), findsOneWidget);
    Navigator.of(tester.element(find.byType(SavedProductsScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('장바구니').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('주말 장보기'));
    await tester.pumpAndSettle();
    expect(find.byType(CartScreen), findsOneWidget);
    expect(find.text('420 kcal'), findsOneWidget);
    await tester.tap(find.byTooltip('카트 기기 연결'));
    await tester.pumpAndSettle();
    expect(find.text('482619'), findsOneWidget);
    expect(api.paths, contains('/api/v1/carts/preview/pair'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('criteria search, selection and saving keep existing tokens',
      (tester) async {
    await viewport(tester);
    AppUser? saved;
    await tester.pumpWidget(shell(PreferencesScreen(
        api: PreviewApi(),
        token: 'preview',
        user: previewUser,
        onSaved: (user) => saved = user)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '대두');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('기준 저장'));
    await tester.pumpAndSettle();
    expect(saved!.profiles, contains('allergy:soy'));
    expect(saved!.profiles, contains('halal'));
    expect(saved!.profiles, contains('allergy:milk'));
  });
  testWidgets('result opens direct and shared facility evidence and OCR',
      (tester) async {
    await viewport(tester);
    await tester
        .pumpWidget(shell(previewScreen('result_danger', PreviewApi())));
    await tester.pumpAndSettle();
    expect(find.text('위험'), findsOneWidget);
    await tester.tap(find.text('세부 설명 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(ResultDetailScreen), findsOneWidget);
    expect(find.text('직접 함유'), findsOneWidget);
    expect(find.text('같은 제조시설'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('OCR 원문'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text(previewResult.ocrText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final language in uiLanguages.keys) {
    testWidgets('five languages and direction / $language', (tester) async {
      await viewport(tester);
      await appLanguage.select(language);
      addTearDown(() => appLanguage.select('ko'));
      for (final screen in [
        'login',
        'criteria',
        'home_scan',
        'result_caution',
        'pairing_code'
      ]) {
        await tester.pumpWidget(shell(previewScreen(screen, PreviewApi()),
            key: ValueKey('$language-$screen')));
        await settle(tester);
        expect(Directionality.of(tester.element(find.byType(Scaffold).first)),
            language == 'ar' ? TextDirection.rtl : TextDirection.ltr);
        expect(tester.takeException(), isNull, reason: '$language/$screen');
        if (language == 'ar' && screen == 'result_caution') {
          await capture(tester, 'rtl_result');
        }
        if (language != 'ko' && screen == 'login') {
          await capture(tester, 'login_$language');
        }
      }
    });
  }
  testWidgets('small screen and enlarged text remain scrollable',
      (tester) async {
    await viewport(tester, size: const Size(320, 740));
    for (final screen in [
      'login',
      'criteria',
      'home_scan',
      'result_danger',
      'detail',
      'cart',
      'pairing_code'
    ]) {
      await tester.pumpWidget(shell(previewScreen(screen, PreviewApi()),
          key: ValueKey(screen), textScale: 1.5));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: screen);
    }
  });
  test('all added interface copy has four translations', () {
    for (final row in v2Strings.values) {
      expect(row.keys, containsAll(['en', 'ar', 'zh', 'ja']));
      expect(row.values.every((value) => value.isNotEmpty), isTrue);
    }
  });
  test('text and verdict colors meet WCAG AA contrast', () {
    double ratio(Color a, Color b) {
      final first = a.computeLuminance(), second = b.computeLuminance();
      return first > second
          ? (first + .05) / (second + .05)
          : (second + .05) / (first + .05);
    }

    final theme = safeByteTheme();
    expect(ratio(theme.colorScheme.primary, Colors.white),
        greaterThanOrEqualTo(4.5));
    expect(ratio(theme.colorScheme.onSurface, Colors.white),
        greaterThanOrEqualTo(4.5));
    expect(ratio(const Color(0xff626e68), const Color(0xfff4f6f5)),
        greaterThanOrEqualTo(4.5));
    for (final level in ['SAFE', 'CAUTION', 'DANGER']) {
      final scheme = resultScheme(level);
      expect(ratio(scheme.foreground, Colors.white), greaterThanOrEqualTo(4.5));
      expect(ratio(scheme.foreground, scheme.panel), greaterThanOrEqualTo(4.5));
    }
    expect(ratio(theme.colorScheme.outline, Colors.white),
        greaterThanOrEqualTo(3));
  });
}

Widget shell(Widget child, {Key? key, double textScale = 1}) => RepaintBoundary(
    key: captureKey,
    child: MaterialApp(
      key: key,
      debugShowCheckedModeBanner: false,
      theme: safeByteTheme(),
      locale: appLanguage.locale,
      supportedLocales: uiLanguages.keys.map(Locale.new),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, inner) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Directionality(
              textDirection: appLanguage.direction, child: inner!)),
      home: child,
    ));
Future<void> viewport(WidgetTester tester,
    {Size size = const Size(360, 780)}) async {
  await appLanguage.select('ko');
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = size * 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> capture(WidgetTester tester, String name) async {
  final boundary =
      captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    image.dispose();
    await expectLater(bytes, matchesGoldenFile('../../screenshots/$name.png'));
  });
}
