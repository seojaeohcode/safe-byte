import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_data.dart';
import 'v2_strings.dart';

/// Languages the whole interface can switch to, labelled in their own script.
const uiLanguages = <String, String>{
  'ko': '한국어',
  'en': 'English',
  'ar': 'العربية',
  'zh': '中文',
  'ja': '日本語',
};

const _storageKey = 'safeByteUiLanguage';

class AppLanguage extends ChangeNotifier {
  String _code = 'ko';

  String get code => _code;
  Locale get locale => Locale(_code);
  TextDirection get direction =>
      _code == 'ar' ? TextDirection.rtl : TextDirection.ltr;

  Future<void> restore() async {
    final saved =
        (await SharedPreferences.getInstance()).getString(_storageKey);
    if (saved != null && uiLanguages.containsKey(saved) && saved != _code) {
      _code = saved;
      notifyListeners();
    }
  }

  Future<void> select(String code) async {
    if (!uiLanguages.containsKey(code) || code == _code) return;
    _code = code;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(_storageKey, code);
  }
}

final appLanguage = AppLanguage();

/// Korean source text in, the current interface language out.
///
/// The Korean string is the catalogue key, so a string that has not been
/// translated yet still renders as readable Korean instead of a blank label.
String t(String korean) {
  if (appLanguage.code == 'ko') return korean;
  return v2Strings[korean]?[appLanguage.code] ??
      uiStrings[korean]?[appLanguage.code] ??
      korean;
}

/// Same lookup for copy with `{0}`, `{1}` … placeholders.
String tf(String korean, List<Object?> values) {
  var text = t(korean);
  for (var index = 0; index < values.length; index++) {
    text = text.replaceAll('{$index}', '${values[index]}');
  }
  return text;
}

/// A readable title for an analysis record.
///
/// Camera and gallery files arrive as `scaled_<uuid>.jpg`, which tells the user
/// nothing, so generated names are replaced with what the record actually is.
String analysisLabel(String? sourceName) {
  final raw = (sourceName ?? '').trim();
  if (raw.isEmpty) return t('라벨 사진');
  if (raw == 'direct_text') return t('직접 입력한 텍스트');
  final base = raw.split(RegExp(r'[\\/]')).last;
  final withoutExtension =
      base.contains('.') ? base.substring(0, base.lastIndexOf('.')) : base;
  final generated =
      RegExp(r'^(scaled_|image_picker|rn_image_picker|IMG_|PXL_|photo|capture)|'
          r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}|^\d{6,}$');
  if (generated.hasMatch(withoutExtension)) return t('라벨 사진');
  return withoutExtension.length > 40
      ? '${withoutExtension.substring(0, 40)}…'
      : withoutExtension;
}

/// Language sheet, reachable before signing in as well as from the account tab.
Future<void> showLanguagePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // A short window (landscape phone, small browser) must still reach every language.
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(t('언어'),
                    style: Theme.of(sheetContext).textTheme.titleLarge),
              ),
            ),
            for (final entry in uiLanguages.entries)
              ListTile(
                title: Text(entry.value),
                trailing: entry.key == appLanguage.code
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  appLanguage.select(entry.key);
                  Navigator.of(sheetContext).pop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Compact switch for screens without the account tab, such as sign-in.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Listens itself so the label still updates when the caller builds it as const.
    return ListenableBuilder(
      listenable: appLanguage,
      builder: (context, _) => TextButton.icon(
        onPressed: () => showLanguagePicker(context),
        icon: const Icon(Icons.language_outlined, size: 20),
        label: Text(uiLanguages[appLanguage.code] ?? ''),
      ),
    );
  }
}
