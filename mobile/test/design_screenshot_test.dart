import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safebyte_mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadKoreanFonts);

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
  final loader = FontLoader('Malgun Gothic');
  for (final path in [
    r'C:\Windows\Fonts\malgun.ttf',
    r'C:\Windows\Fonts\malgunbd.ttf',
  ]) {
    final file = File(path);
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      loader.addFont(
          Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    }
  }
  await loader.load();

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
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff2de2c6),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xff2de2c6),
      secondary: const Color(0xff87a9ff),
      tertiary: const Color(0xff30d989),
      error: const Color(0xffff6f61),
      surface: const Color(0xff252a32),
      surfaceContainerHighest: const Color(0xff191b20),
      onSurface: const Color(0xfff7fbfa),
      outline: const Color(0xff3a404b),
    );

    return RepaintBoundary(
      key: _captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: scheme,
          scaffoldBackgroundColor: const Color(0xff191b20),
          fontFamily: 'Malgun Gothic',
          fontFamilyFallback: const [
            'Noto Sans CJK KR',
            'Apple SD Gothic Neo',
            'Malgun Gothic',
          ],
          textTheme: const TextTheme(
            displaySmall: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              height: 1.08,
              letterSpacing: 0,
            ),
            headlineMedium: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.12,
              letterSpacing: 0,
            ),
            headlineSmall: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.18,
              letterSpacing: 0,
            ),
            titleLarge: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
            titleMedium: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
            bodyLarge: TextStyle(fontSize: 16, height: 1.45, letterSpacing: 0),
            bodyMedium: TextStyle(fontSize: 14, height: 1.45, letterSpacing: 0),
            bodySmall: TextStyle(fontSize: 12, height: 1.35, letterSpacing: 0),
            labelLarge: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ).apply(
            bodyColor: const Color(0xfff7fbfa),
            displayColor: const Color(0xfff7fbfa),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xff252a32),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xff3a404b)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xff3a404b)),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff2de2c6),
              foregroundColor: const Color(0xff191b20),
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xfff7fbfa),
              side: const BorderSide(color: Color(0xff3a404b)),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
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
