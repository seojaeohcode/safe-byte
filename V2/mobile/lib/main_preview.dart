/// Offline entry point for review. No backend is started or contacted.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'main.dart';
import 'l10n.dart';
import 'preview_api.dart';
import 'workspace.dart';

void main() => runApp(const PreviewApp());

Widget previewScreen(String name, PreviewApi api) {
  switch (name) {
    case 'splash':
      return const SplashScreen();
    case 'login':
      return AuthScreen(api: api, onAuthenticated: (_) async {});
    case 'criteria':
      return PreferencesScreen(api: api, token: 'preview', user: previewUser);
    case 'analyzing':
      return const AnalyzingScreen();
    case 'result_safe':
      return ResultScreen(result: previewVerdict('SAFE'));
    case 'result_caution':
      return ResultScreen(result: previewVerdict('CAUTION'));
    case 'result_danger':
      return ResultScreen(result: previewVerdict('DANGER'));
    case 'detail':
      return const ResultDetailScreen(result: previewResult);
    case 'cart':
      return CartScreen(api: api, token: 'preview', cart: const {
        'id': 'preview',
        'name': '오늘 장보기',
        'profiles': ['allergy:milk']
      });
    case 'pairing_code':
      return const PairingCodeScreen(code: '482619');
    case 'family':
      return const ProfileEditor(
          initialProfiles: ['allergy:milk', 'allergy:peanut'],
          cart: false,
          initialName: '우리 가족');
    default:
      return HomeScreen(
          api: api,
          token: 'preview',
          user: previewUser,
          onLogout: () {},
          onUserChanged: (_) {});
  }
}

class PreviewApp extends StatelessWidget {
  const PreviewApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: appLanguage,
      builder: (context, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: safeByteTheme(),
            locale: appLanguage.locale,
            supportedLocales: uiLanguages.keys.map(Locale.new),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => Directionality(
                textDirection: appLanguage.direction, child: child!),
            home: previewScreen(
                const String.fromEnvironment('PREVIEW_SCREEN',
                    defaultValue: 'home_scan'),
                PreviewApi()),
          ));
}
