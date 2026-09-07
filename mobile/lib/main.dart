import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'workspace.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const apiBaseUrl = String.fromEnvironment(
  'SAFE_BYTE_API_BASE',
  defaultValue: 'http://127.0.0.1:8000',
);

// Safe-Byte: restrained commercial palette for a utility-style product app.
const _ink = Color(0xff1f242b);
const _mutedInk = Color(0xff66727f);
const _canvas = Color(0xfff3f5f8);
const _paper = Color(0xffffffff);
const _paperWarm = Color(0xfff7f8fb);
const _line = Color(0xffdce2ea);
const _teal = Color(0xff00b28d);
const _actionTeal = Color(0xff0d8f76);
const _blue = Color(0xff3f6fa3);
const _leaf = Color(0xff1c8a63);
const _amber = Color(0xff9a6f00);
const _danger = Color(0xffce4c49);
const _softTeal = Color(0xffe4f5f1);
const _softBlue = Color(0xffe8f1f8);
const _softAmber = Color(0xfffff3d9);
const _softDanger = Color(0xffffefec);
const _softLeaf = Color(0xffe9f7f1);
const _white = Color(0xffffffff);
const _clear = Color(0x00000000);
const _scrim = Color(0x99000000);
const _softShadow = Color(0x11000000);
const _scanSurface = Color(0xffedf4f2);
const _facilitySurface = Color(0xffedf3f9);
const _ingredientSurface = Color(0xfff8f1ea);
const _dangerBackground = Color(0xfffff4f2);
const _amberBackground = Color(0xfffff9ee);
const _passBackground = Color(0xfff2f8f4);

ThemeData safeByteTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _teal,
    brightness: Brightness.light,
  ).copyWith(
    primary: _actionTeal,
    secondary: _blue,
    tertiary: _leaf,
    error: _danger,
    surface: _paper,
    surfaceContainerHighest: _canvas,
    onSurface: _ink,
    outline: _line,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: _canvas,
    fontFamily: 'NotoSansKR',
    iconTheme: const IconThemeData(size: 22, color: _mutedInk),
    dividerTheme: const DividerThemeData(color: _line, thickness: 1, space: 1),
    listTileTheme: const ListTileThemeData(
      iconColor: _mutedInk,
      minVerticalPadding: 14,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    fontFamilyFallback: const [
      'NotoSansArabic',
      'Noto Sans CJK KR',
      'Apple SD Gothic Neo',
      'Malgun Gothic',
    ],
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.08,
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: 0,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.45, letterSpacing: 0),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, letterSpacing: 0),
      bodySmall: TextStyle(fontSize: 12, height: 1.35, letterSpacing: 0),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    ).apply(bodyColor: _ink, displayColor: _ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _blue, width: 1.2),
      ),
      prefixIconColor: _mutedInk,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: _paper,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _actionTeal,
        foregroundColor: _white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _ink,
        side: const BorderSide(color: _line),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      titleSpacing: 18,
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: _ink,
      ),
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: _paper,
      foregroundColor: _ink,
      surfaceTintColor: _clear,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: _paper,
      elevation: 0,
      selectedItemColor: _actionTeal,
      unselectedItemColor: _mutedInk,
      selectedLabelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      unselectedLabelStyle: TextStyle(fontSize: 11, height: 1.2),
      showUnselectedLabels: true,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: const BorderSide(color: _line),
      backgroundColor: _paper,
      selectedColor: _softTeal,
      checkmarkColor: _teal,
    ),
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _ink,
      contentTextStyle: TextStyle(color: _white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      insetPadding: EdgeInsets.fromLTRB(16, 8, 16, 8),
    ),
  );
}

void main() {
  runApp(const SafeByteApp());
}

class SafeByteApp extends StatefulWidget {
  const SafeByteApp({super.key});

  @override
  State<SafeByteApp> createState() => _SafeByteAppState();
}

class _SafeByteAppState extends State<SafeByteApp> {
  final _api = SafeByteApi(kIsWeb ? Uri.base.origin : apiBaseUrl);
  AppUser? _user;
  String? _token;
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    appLanguage.addListener(_onLanguageChanged);
    appLanguage.restore();
    _restoreSession();
  }

  @override
  void dispose() {
    appLanguage.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() => setState(() {});

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('safeByteToken');
    if (token == null) {
      setState(() => _booting = false);
      return;
    }
    try {
      final user = await _api.me(token);
      setState(() {
        _token = token;
        _user = user;
        _booting = false;
      });
    } catch (_) {
      await prefs.remove('safeByteToken');
      setState(() => _booting = false);
    }
  }

  Future<void> _saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('safeByteToken', session.token);
    setState(() {
      _token = session.token;
      _user = session.user;
    });
  }

  Future<void> _logout() async {
    if (_token != null) {
      try {
        await _api.request('POST', '/api/v1/auth/logout', _token!);
      } catch (error) {
        if (mounted) showSnack(context, error.toString());
        return;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('safeByteToken');
    setState(() {
      _token = null;
      _user = null;
    });
  }

  void _replaceUser(AppUser user) {
    setState(() => _user = user);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Safe-Byte',
      theme: safeByteTheme(),
      locale: appLanguage.locale,
      supportedLocales: uiLanguages.keys.map(Locale.new),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      localeResolutionCallback: (_, __) => appLanguage.locale,
      // Arabic has to lay out right to left across every screen, not just the result text.
      builder: (context, child) => Directionality(
        textDirection: appLanguage.direction,
        child: child ?? const SizedBox.shrink(),
      ),
      home: _booting
          ? const SplashScreen()
          : _user == null || _token == null
              ? AuthScreen(api: _api, onAuthenticated: _saveSession)
              : _user!.profiles.isEmpty
                  ? PreferencesScreen(
                      api: _api,
                      token: _token!,
                      user: _user!,
                      initialSetup: true,
                      onSaved: _replaceUser,
                    )
                  : HomeScreen(
                      api: _api,
                      token: _token!,
                      user: _user!,
                      onLogout: _logout,
                      onUserChanged: _replaceUser,
                    ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 42,
          height: 42,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.api,
    required this.onAuthenticated,
    super.key,
  });

  final SafeByteApi api;
  final Future<void> Function(AuthSession session) onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final session = _isLogin
          ? await widget.api.login(_email.text, _password.text)
          : await widget.api.register(
              email: _email.text,
              password: _password.text,
              displayName: _name.text,
              profiles: const [],
              allergyNotes: '',
            );
      await widget.onAuthenticated(session);
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _BrandBackdrop(
        child: SafeArea(
          child: Column(children: [
            // Someone who cannot read Korean has to be able to switch before signing in.
            const Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                    padding: EdgeInsets.only(top: 8, left: 12, right: 12),
                    child: LanguageButton())),
            Expanded(
              child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 24 : 32,
                  compact ? 24 : 42,
                  compact ? 24 : 32,
                  28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 430,
                      minHeight: (constraints.maxHeight - 100)
                          .clamp(0, double.infinity),
                    ),
                    child: Align(
                      alignment: Alignment.center,
                      child: _AuthFormPanel(
                        formKey: _formKey,
                        email: _email,
                        password: _password,
                        name: _name,
                        isLogin: _isLogin,
                        loading: _loading,
                        onModeChanged: (value) =>
                            setState(() => _isLogin = value),
                        onSubmit: _submit,
                      ),
                    ),
                  ),
                ),
              );
            },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BrandBackdrop extends StatelessWidget {
  const _BrandBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _paper,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_paper, _paperWarm],
          stops: [0.0, 1.0],
        ),
      ),
      child: child,
    );
  }
}

class _AuthFormPanel extends StatelessWidget {
  const _AuthFormPanel({
    required this.formKey,
    required this.email,
    required this.password,
    required this.name,
    required this.isLogin,
    required this.loading,
    required this.onModeChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController name;
  final bool isLogin;
  final bool loading;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: AutofillGroup(
        child: SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _softTeal,
                    child:
                        Icon(Icons.verified_user_outlined, color: _actionTeal),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Safe-Byte',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: _ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(isLogin ? t('로그인') : t('회원가입'),
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(
                isLogin ? t('저장한 검사 기준과 기록을 불러와요.') : t('나에게 맞는 식품 선택을 시작해 보세요.'),
                style: const TextStyle(color: _mutedInk),
              ),
              const SizedBox(height: 32),
              if (!isLogin) ...[
                TextFormField(
                  controller: name,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: t('이름 또는 닉네임'),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: t('이메일'),
                  prefixIcon: const Icon(Icons.mail_outline),
                ),
                validator: (value) => (value?.trim() ?? '').contains('@')
                    ? null
                    : t('이메일을 입력해 주세요.'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: password,
                obscureText: true,
                autofillHints: [
                  isLogin ? AutofillHints.password : AutofillHints.newPassword
                ],
                decoration: InputDecoration(
                  labelText: t('비밀번호'),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                validator: (value) =>
                    (value ?? '').length >= 6 ? null : t('6자 이상 입력해 주세요.'),
                onFieldSubmitted: (_) => onSubmit(),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: loading ? null : onSubmit,
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isLogin ? t('로그인하고 시작하기') : t('가입하고 기준 설정')),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(isLogin ? t('처음 이용하시나요?') : t('이미 계정이 있나요?'),
                      style: const TextStyle(color: _mutedInk, fontSize: 13)),
                  TextButton(
                      onPressed: loading ? null : () => onModeChanged(!isLogin),
                      child: Text(isLogin ? t('회원가입') : t('로그인'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.api,
    required this.token,
    required this.user,
    required this.onLogout,
    required this.onUserChanged,
    super.key,
  });

  final SafeByteApi api;
  final String token;
  final AppUser user;
  final VoidCallback onLogout;
  final void Function(AppUser user) onUserChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  XFile? _image;
  bool _loading = false;
  bool _statusLoading = true;
  OcrHealth? _health;
  CostSummary? _costs;
  Map<String, dynamic>? _scanContext;
  int _section = 0;

  Future<void> _openWorkspace([int tab = 0]) async {
    final selected = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
          builder: (_) => WorkspaceScreen(
              api: widget.api,
              token: widget.token,
              user: widget.user,
              initialTab: tab)),
    );
    if (selected != null && mounted) _selectScanContext(selected);
  }

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() => _statusLoading = true);
    try {
      final health = await widget.api.ocrHealth();
      final costs = await widget.api.costs();
      if (!mounted) return;
      setState(() {
        _health = health;
        _costs = costs;
        _statusLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _statusLoading = false);
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (_loading) return;
    try {
      final image = await _picker.pickImage(
          source: source, maxWidth: 2200, imageQuality: 92);
      if (image != null && mounted) setState(() => _image = image);
    } catch (_) {
      if (mounted) showSnack(context, t('사진을 불러오지 못했어요. 카메라·사진 접근 권한을 확인해주세요.'));
    }
  }

  Future<void> _analyze() async {
    if (_image == null) {
      showSnack(context, t('라벨 사진을 먼저 선택해주세요.'));
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await widget.api.analyzeImage(
        token: widget.token,
        image: _image!,
        profiles: _scanContext == null
            ? widget.user.profiles
            : List<String>.from(_scanContext!['profiles']),
        language: _scanContext?['language'] as String? ?? 'ko',
      );
      if (_scanContext?['cart_id'] != null) {
        try {
          await widget.api.request('POST',
              '/api/v1/carts/${_scanContext!['cart_id']}/items', widget.token,
              body: {
                'request_id': result.requestId,
                'name': t('스캔한 상품'),
                'quantity': 1
              });
        } catch (_) {
          if (mounted) {
            showSnack(
                context, t('분석 결과는 저장했지만 장바구니에 담지 못했어요. 장보기가 종료됐는지 확인해주세요.'));
          }
        }
      }
      await _refreshStatus();
      if (!mounted) return;
      final selected = await Navigator.of(
        context,
      ).push<Map<String, dynamic>>(MaterialPageRoute(
          builder: (_) => ResultScreen(
              result: result, api: widget.api, token: widget.token)));
      if (selected != null && mounted) _selectScanContext(selected);
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSettings() async {
    final updated = await Navigator.of(context).push<AppUser>(
      MaterialPageRoute(
        builder: (_) => PreferencesScreen(
          api: widget.api,
          token: widget.token,
          user: widget.user,
        ),
      ),
    );
    if (updated != null) widget.onUserChanged(updated);
  }

  void _selectScanContext(Map<String, dynamic> selected) {
    setState(() {
      _scanContext = selected;
      _section = 0;
    });
  }

  Future<void> _openSavedProducts() async {
    final selected = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                SavedProductsScreen(api: widget.api, token: widget.token)));
    if (selected != null && mounted) _selectScanContext(selected);
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.user.displayName;
    final profiles = _scanContext == null
        ? widget.user.profiles
        : List<String>.from(_scanContext!['profiles']);
    return Stack(children: [
      Scaffold(
        appBar: _section == 0 || _section == 3
            ? AppBar(
                title: Text(_section == 0 ? 'Safe-Byte' : t('내 정보'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        letterSpacing: -0.5)),
                actions: [
                  IconButton(
                      tooltip: t('내 검사 기준'),
                      onPressed: _openSettings,
                      icon: const Icon(Icons.tune_outlined)),
                  const SizedBox(width: 12)
                ],
              )
            : null,
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _line))),
          child: BottomNavigationBar(
            currentIndex: _section,
            backgroundColor: _white,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: _actionTeal,
            unselectedItemColor: _mutedInk,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            selectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w700, height: 1.8),
            unselectedLabelStyle: const TextStyle(height: 1.8),
            onTap: (value) => setState(() => _section = value),
            items: [
              BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined),
                  activeIcon: const Icon(Icons.home),
                  label: t('홈')),
              BottomNavigationBarItem(
                  icon: const Icon(Icons.shopping_bag_outlined),
                  activeIcon: const Icon(Icons.shopping_bag),
                  label: t('장바구니')),
              BottomNavigationBarItem(
                  icon: const Icon(Icons.history_outlined), label: t('기록')),
              BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline),
                  activeIcon: const Icon(Icons.person),
                  label: t('내 정보')),
            ],
          ),
        ),
        body: _section == 1 || _section == 2
            ? WorkspaceScreen(
                key: ValueKey(_section),
                api: widget.api,
                token: widget.token,
                user: widget.user,
                initialTab: _section == 1 ? 1 : 2,
                embedded: true,
                onSelected: _selectScanContext,
                initialProfiles: _scanContext == null ? null : profiles,
                initialLanguage: _scanContext?['language'] as String? ?? 'ko')
            : SafeArea(
                child: Center(
                    child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                    children: _section == 3
                        ? [
                            Text(tf('{0}님', [userName]),
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 6),
                            Text(widget.user.email,
                                style: const TextStyle(color: _mutedInk)),
                            const SizedBox(height: 32),
                            const Divider(),
                            ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.tune_outlined),
                                title: Text(t('내 검사 기준')),
                                subtitle: Text(widget.user.profiles.isEmpty
                                    ? t('검사할 성분을 설정해 주세요')
                                    : widget.user.profiles
                                        .map(profileLabel)
                                        .join(', ')),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _openSettings),
                            ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.people_outline),
                                title: Text(t('가족 기준 관리')),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openWorkspace()),
                            ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.bookmark_border),
                                title: Text(t('저장한 상품')),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _openSavedProducts),
                            ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.language_outlined),
                                title: Text(t('언어')),
                                subtitle:
                                    Text(uiLanguages[appLanguage.code] ?? ''),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => showLanguagePicker(context)),
                            const SizedBox(height: 16),
                            const Divider(),
                            ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text(t('서비스 연결 상태')),
                                children: [
                                  _StatusPanel(
                                      health: _health,
                                      costs: _costs,
                                      loading: _statusLoading,
                                      onRefresh: _refreshStatus)
                                ]),
                            const SizedBox(height: 16),
                            Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                    onPressed: widget.onLogout,
                                    style: TextButton.styleFrom(
                                        foregroundColor: _mutedInk),
                                    child: Text(t('로그아웃')))),
                          ]
                        : [
                            Text(tf('{0}님, 안녕하세요', [userName]),
                                style: const TextStyle(
                                    color: _mutedInk, fontSize: 14)),
                            const SizedBox(height: 8),
                            Text(t('식품 라벨 확인'),
                                style:
                                    Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 8),
                            Text(t('피하고 싶은 성분이 있는지 확인해요.'),
                                style: const TextStyle(color: _mutedInk)),
                            const SizedBox(height: 28),
                            if (_scanContext != null) ...[
                              Row(children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 18, color: _actionTeal),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        tf('적용 중: {0}', [_scanContext!['name']]),
                                        style: const TextStyle(
                                            color: _actionTeal))),
                                IconButton(
                                    tooltip: t('내 기준으로 돌아가기'),
                                    onPressed: () =>
                                        setState(() => _scanContext = null),
                                    icon: const Icon(Icons.close, size: 20))
                              ]),
                              const SizedBox(height: 8),
                            ],
                            if (_image == null) ...[
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                    color: _paper,
                                    borderRadius: BorderRadius.circular(16)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Padding(
                                                padding:
                                                    EdgeInsets.only(top: 2),
                                                child: Icon(
                                                    Icons
                                                        .document_scanner_outlined,
                                                    color: _ink,
                                                    size: 24)),
                                            const SizedBox(width: 12),
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Text(t('원재료명을 찍어주세요'),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                      t('글자가 잘 보이도록 가까이 촬영해 주세요.'),
                                                      style: const TextStyle(
                                                          color: _mutedInk,
                                                          fontSize: 13,
                                                          height: 1.5)),
                                                ])),
                                          ]),
                                      const SizedBox(height: 24),
                                      FilledButton(
                                          onPressed: () =>
                                              _pick(ImageSource.camera),
                                          child: Text(t('라벨 촬영하기'))),
                                    ]),
                              ),
                              const SizedBox(height: 4),
                              Center(
                                  child: TextButton(
                                      onPressed: () =>
                                          _pick(ImageSource.gallery),
                                      style: TextButton.styleFrom(
                                          foregroundColor: _mutedInk,
                                          minimumSize: const Size(160, 48)),
                                      child: Text(t('앨범에서 불러오기')))),
                            ] else ...[
                              _CapturePanel(
                                  image: _image,
                                  loading: _loading,
                                  onCamera: () => _pick(ImageSource.camera),
                                  onGallery: () => _pick(ImageSource.gallery),
                                  onAnalyze: _analyze),
                              TextButton(
                                  onPressed: () =>
                                      setState(() => _image = null),
                                  child: Text(t('사진 선택 취소'))),
                            ],
                            const SizedBox(height: 20),
                            Row(children: [
                              Expanded(
                                  child: Text(t('검사 기준'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium)),
                              TextButton(
                                  onPressed: _openSettings,
                                  child: Text(t('변경')))
                            ]),
                            const SizedBox(height: 4),
                            if (profiles.isEmpty)
                              Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(t('알레르기나 식이 기준을 먼저 선택해 주세요.'),
                                      style: const TextStyle(color: _mutedInk)))
                            else
                              Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: profiles
                                      .map((profile) => Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                                color: _paper,
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            child: Text(profileLabel(profile),
                                                style: const TextStyle(
                                                    fontSize: 13)),
                                          ))
                                      .toList()),
                            const SizedBox(height: 28),
                            const Divider(),
                            const SizedBox(height: 8),
                            _HomeShortcut(
                                icon: Icons.people_outline,
                                title: t('가족 기준'),
                                subtitle: t('가족에게 맞는 성분도 함께 확인해요'),
                                onTap: () => _openWorkspace()),
                            const SizedBox(height: 12),
                            _HomeShortcut(
                                icon: Icons.shopping_bag_outlined,
                                title: t('장보기 시작'),
                                subtitle: t('확인한 상품을 장바구니에 모아요'),
                                onTap: () => setState(() => _section = 1)),
                            const SizedBox(height: 20),
                            Text(t('분석 결과와 함께 제품의 실제 표시사항을 확인해 주세요.'),
                                style: const TextStyle(
                                    color: _mutedInk,
                                    fontSize: 12,
                                    height: 1.6)),
                          ]),
              ))),
      ),
      if (_loading) const LoadingOverlay()
    ]);
  }
}

class _HomeShortcut extends StatelessWidget {
  const _HomeShortcut(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SurfacePanel(
        borderColor: _line,
        color: _paper,
        padding: const EdgeInsets.all(0),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          leading: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _softBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _actionTeal),
          ),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(subtitle,
              style: const TextStyle(color: _mutedInk, fontSize: 12)),
          trailing: const Icon(Icons.chevron_right, size: 20, color: _mutedInk),
          onTap: onTap,
        ),
      );
}

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({
    required this.api,
    required this.token,
    required this.user,
    this.initialSetup = false,
    this.onSaved,
    super.key,
  });

  final SafeByteApi api;
  final String token;
  final AppUser user;
  final bool initialSetup;
  final ValueChanged<AppUser>? onSaved;

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late final TextEditingController _name;
  late final Set<String> _profiles;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.displayName);
    _profiles = widget.user.profiles.toSet();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_profiles.isEmpty) {
      showSnack(context, t('검사 기준을 하나 이상 선택해주세요.'));
      return;
    }
    setState(() => _saving = true);
    try {
      final user = await widget.api.updatePreferences(
        token: widget.token,
        displayName: _name.text,
        profiles: _profiles.toList(),
        allergyNotes: '',
      );
      if (!mounted) return;
      if (widget.onSaved != null) {
        widget.onSaved!(user);
      } else {
        Navigator.of(context).pop(user);
      }
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleProfile(String value) {
    setState(() {
      if (value == 'allergy') {
        if (hasAllergySelection(_profiles)) {
          _profiles.remove('allergy');
          _profiles.removeWhere(isAllergyToken);
        } else {
          _profiles.add('allergy');
        }
        return;
      }
      if (isAllergyToken(value)) {
        if (_profiles.contains(value)) {
          _profiles.remove(value);
        } else {
          _profiles.remove('allergy');
          _profiles.add(value);
        }
        return;
      }
      if (_profiles.contains(value)) {
        if (_profiles.length > 1) _profiles.remove(value);
      } else {
        _profiles.add(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.initialSetup,
        title: Text(widget.initialSetup ? t('기준 설정') : t('내 기준')),
      ),
      body: _BrandBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  // No panel here: a white slab behind white criteria cards
                  // erased their edges and read as one blank block.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        Text(
                          widget.initialSetup ? t('먼저 기준을 정해주세요') : t('먹기 전에 확인할 기준'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t('피하고 싶은 성분과 식이 기준을 선택해 주세요.'),
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: _mutedInk),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _name,
                          decoration: InputDecoration(
                            labelText: t('이름 또는 닉네임'),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ProfileSelector(
                          selected: _profiles,
                          onChanged: _toggleProfile,
                        ),
                        if (hasAllergySelection(_profiles)) ...[
                          const SizedBox(height: 12),
                          AllergySelector(
                            selected: _profiles,
                            onChanged: _toggleProfile,
                          ),
                        ],
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(t('기준 저장')),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  const ResultScreen({required this.result, this.api, this.token, super.key});

  final AnalysisResult result;
  final SafeByteApi? api;
  final String? token;

  @override
  Widget build(BuildContext context) {
    final scheme = resultScheme(result.finalLevel);
    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                wide ? 32 : 20,
                12,
                wide ? 32 : 20,
                24,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: t('닫기'),
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _VerdictHero(result: result, scheme: scheme),
                        const SizedBox(height: 18),
                        _ResultCounts(result: result, scheme: scheme),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => showResultDetails(context, result),
                          icon: const Icon(Icons.list_alt),
                          label: Text(t('세부 설명 보기')),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: Text(t('다른 라벨 확인')),
                        ),
                        if (result.extra.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          ResultExtras(result: result, api: api, token: token),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

void showResultDetails(BuildContext context, AnalysisResult result) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.84,
        minChildSize: 0.46,
        maxChildSize: 0.95,
        builder: (context, controller) {
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            children: [
              Text(t('세부 설명'), style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                t('직접 원재료와 제조시설 공유 문구를 분리해서 보여줍니다.'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: _mutedInk),
              ),
              const SizedBox(height: 16),
              if (result.directDetections.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.warning_amber_outlined,
                  title: t('직접 함유/함유 문구'),
                  description: t('원재료명 또는 함유 표시 주변에서 확인된 항목입니다.'),
                ),
                ...result.directDetections.map(DetectionTile.new),
              ] else ...[
                _QuietNotice(
                  icon: Icons.verified_outlined,
                  title: t('직접 함유 위험 성분은 보이지 않습니다.'),
                  body: t('OCR 결과 기준이며, 포장 훼손이나 흐린 사진이면 다시 촬영하는 것이 안전합니다.'),
                ),
              ],
              if (result.facilityDetections.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SectionHeader(
                  icon: Icons.factory_outlined,
                  title: t('제조시설 공유 표기'),
                  description: t('직접 원재료가 아니라 같은 제조시설 문구에서 확인된 항목입니다.'),
                ),
                ...result.facilityDetections.map(DetectionTile.new),
              ],
              if (result.unknownDetections.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SectionHeader(
                    icon: Icons.help_outline,
                    title: t('문맥 확인 필요'),
                    description: t('직접 함유 여부를 확정하지 못한 항목입니다.')),
                ...result.unknownDetections.map(DetectionTile.new),
              ],
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(t('OCR 텍스트')),
                children: [
                  SelectableText(
                    result.ocrText.isEmpty ? t('OCR 텍스트가 없습니다.') : result.ocrText,
                    style: const TextStyle(height: 1.45),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}

class _CapturePanel extends StatelessWidget {
  const _CapturePanel({
    required this.image,
    required this.loading,
    required this.onCamera,
    required this.onGallery,
    required this.onAnalyze,
  });

  final XFile? image;
  final bool loading;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      padding: const EdgeInsets.all(16),
      borderColor: _line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _softBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.document_scanner_outlined, color: _blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('라벨 스캔'),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      t('원재료명과 함유 표시가 보이게 맞춰주세요.'),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: _mutedInk),
                    ),
                  ],
                ),
              ),
              _SmallPill(
                text: image == null ? t('대기') : t('준비'),
                color: image == null ? _mutedInk : _teal,
              ),
            ],
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: _scanSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _line),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image == null)
                    const _EmptyCaptureGuide()
                  else
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: FutureBuilder<Uint8List>(
                            future: image!.readAsBytes(),
                            builder: (context, snapshot) => snapshot.hasData
                                ? Image.memory(snapshot.data!,
                                    fit: BoxFit.contain)
                                : const Center(
                                    child: CircularProgressIndicator())),
                      ),
                    ),
                  const _ScanFrameOverlay(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackButtons = constraints.maxWidth < 380;
              final buttons = [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : onCamera,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(t('촬영')),
                  ),
                ),
                const SizedBox(width: 8, height: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : onGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(t('앨범')),
                  ),
                ),
              ];
              if (stackButtons) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: loading ? null : onCamera,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(t('촬영')),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: loading ? null : onGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(t('앨범')),
                    ),
                  ],
                );
              }
              return Row(children: buttons);
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: loading || image == null ? null : onAnalyze,
            icon: const Icon(Icons.search),
            label: Text(image == null ? t('사진 선택 후 분석 가능') : t('라벨 분석하기')),
          ),
        ],
      ),
    );
  }
}

class _ScanFrameOverlay extends StatelessWidget {
  const _ScanFrameOverlay();

  @override
  Widget build(BuildContext context) {
    const size = 30.0;
    const width = 3.0;
    return IgnorePointer(
      child: Stack(
        children: [
          const Positioned(
            left: 14,
            top: 14,
            child: _ScanCorner(size: size, width: width),
          ),
          const Positioned(
            right: 14,
            top: 14,
            child: RotatedBox(
              quarterTurns: 1,
              child: _ScanCorner(size: size, width: width),
            ),
          ),
          const Positioned(
            right: 14,
            bottom: 14,
            child: RotatedBox(
              quarterTurns: 2,
              child: _ScanCorner(size: size, width: width),
            ),
          ),
          const Positioned(
            left: 14,
            bottom: 14,
            child: RotatedBox(
              quarterTurns: 3,
              child: _ScanCorner(size: size, width: width),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanCorner extends StatelessWidget {
  const _ScanCorner({required this.size, required this.width});

  final double size;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: _teal, width: width),
            top: BorderSide(color: _teal, width: width),
          ),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.health,
    required this.costs,
    required this.loading,
    required this.onRefresh,
  });

  final OcrHealth? health;
  final CostSummary? costs;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final usage =
        health == null ? '-' : '${health!.usageToday}/${health!.dailyLimit}';
    final ncloud =
        costs?.ncloudCostKrw == null ? '-' : formatKrw(costs!.ncloudCostKrw!);
    final ocr = costs?.ocrCostKrw == null ? '-' : formatKrw(costs!.ocrCostKrw!);
    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _softBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.monitor_heart_outlined, color: _blue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t('테스트 상태'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: t('새로고침'),
                onPressed: loading ? null : onRefresh,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(label: t('오늘 OCR'), value: usage),
              _MetricChip(label: t('OCR 비용'), value: ocr),
              _MetricChip(label: 'Ncloud', value: ncloud),
              _MetricChip(
                label: t('캐시'),
                value: costs?.cacheConnected == true ? 'Redis' : '-',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProfileSelector extends StatelessWidget {
  const ProfileSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final Set<String> selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final tiles = ['halal', 'vegan', 'allergy'].map((profile) {
          final selectedProfile = profile == 'allergy'
              ? hasAllergySelection(selected)
              : selected.contains(profile);
          return ProfileGoalTile(
            profile: profile,
            selected: selectedProfile,
            onTap: () => onChanged(profile),
          );
        }).toList();
        if (compact) {
          return Column(
            children: [
              for (final tile in tiles) ...[tile, const SizedBox(height: 8)],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              Expanded(child: tiles[i]),
              if (i != tiles.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }
}

class AllergySelector extends StatefulWidget {
  const AllergySelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final Set<String> selected;
  final ValueChanged<String> onChanged;

  @override
  State<AllergySelector> createState() => _AllergySelectorState();
}

class _AllergySelectorState extends State<AllergySelector> {
  final _search = TextEditingController();
  String _category = '전체';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AllergyChoice> get _visibleChoices {
    final query = _search.text.trim().toLowerCase();
    return allergyChoices.where((choice) {
      final matchesCategory = _category == '전체' || choice.category == _category;
      final haystack = '${choice.label} ${choice.searchTerms}'.toLowerCase();
      return matchesCategory && (query.isEmpty || haystack.contains(query));
    }).toList();
  }

  void _toggleBundle(AllergyBundle bundle) {
    final allSelected = bundle.tokens.every(widget.selected.contains);
    for (final token in bundle.tokens) {
      final checked = widget.selected.contains(token);
      if ((allSelected && checked) || (!allSelected && !checked)) {
        widget.onChanged(token);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final broad = widget.selected.contains('allergy');
    final selectedChoices = allergyChoices
        .where((choice) => widget.selected.contains(choice.token))
        .toList();
    final visibleChoices = _visibleChoices;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t('내 알레르기 기준'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  broad ? t('전체') : tf('{0}개', [selectedChoices.length]),
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: _amber),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              broad
                  ? t('세부 항목을 고르지 않으면 국내 표시 대상 알레르기를 전체 검사합니다.')
                  : t('피해야 하는 성분을 선택해 주세요.'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _mutedInk),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: t('성분 검색 (예: 우유, 땅콩)'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: t('검색 지우기'),
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                      ),
                filled: true,
                fillColor: _canvas,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _line),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  selected: broad,
                  label: Text(t('국내 표시 대상 전체')),
                  onSelected: (_) => widget.onChanged('allergy'),
                ),
                for (final bundle in allergyBundles)
                  FilterChip(
                    selected: bundle.tokens.every(widget.selected.contains),
                    label: Text(t(bundle.label)),
                    onSelected: (_) => _toggleBundle(bundle),
                  ),
              ],
            ),
            if (selectedChoices.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedChoices.map((choice) {
                  return InputChip(
                    label: Text(t(choice.label)),
                    onDeleted: () => widget.onChanged(choice.token),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final category in allergyCategories) ...[
                    ChoiceChip(
                      selected: _category == category,
                      label: Text(t(category)),
                      onSelected: (_) => setState(() => _category = category),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: visibleChoices.map((choice) {
                final checked = widget.selected.contains(choice.token);
                return FilterChip(
                  selected: checked,
                  label: Text(t(choice.label)),
                  onSelected: (_) => widget.onChanged(choice.token),
                );
              }).toList(),
            ),
            if (visibleChoices.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                t('검색 결과가 없습니다. 원재료명에 보이는 표현을 메모에 남겨두면 세부 설명에서 함께 확인할 수 있습니다.'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: _mutedInk),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProfileGoalTile extends StatelessWidget {
  const ProfileGoalTile({
    required this.profile,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? _softTeal : _paper,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? _teal : _line, width: 1.4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    profileLabel(profile),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profileDescription(profile),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: _mutedInk),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? _teal : _line,
            ),
          ],
        ),
      ),
    );
  }
}

class DetectionTile extends StatelessWidget {
  const DetectionTile(this.detection, {super.key});

  final Detection detection;

  @override
  Widget build(BuildContext context) {
    final color = detection.isFacilityShared
        ? _blue
        : detection.severity == 'danger'
            ? _danger
            : _amber;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SurfacePanel(
        padding: const EdgeInsets.all(12),
        color:
            detection.isFacilityShared ? _facilitySurface : _ingredientSurface,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              detection.isFacilityShared
                  ? Icons.factory_outlined
                  : Icons.warning_amber_outlined,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          detection.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _SmallPill(
                        text: detection.isFacilityShared
                            ? t('공유시설')
                            : detection.occurrenceType == 'unknown'
                                ? t('확인 필요')
                                : t('직접'),
                        color: color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${profileLabel(detection.category)} · ${detection.label} · ${detection.keyword}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: _mutedInk),
                  ),
                  const SizedBox(height: 7),
                  Text(detection.reason),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = _paper,
    this.borderColor = _line,
    // Flat by design: stacked cards on the grey canvas had their drop shadows
    // overlap in the gaps, which read as smudged grey rather than depth.
    this.shadowColor = _clear,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _scrim,
      child: Center(
        child: SurfacePanel(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              Text(
                t('라벨을 확인하고 있어요'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                t('원재료명과 알레르기 표시를 읽고 있어요.'),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: _mutedInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerdictHero extends StatelessWidget {
  const _VerdictHero({required this.result, required this.scheme});

  final AnalysisResult result;
  final VerdictScheme scheme;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      color: scheme.panel,
      borderColor: scheme.foreground.withValues(alpha: 0.18),
      shadowColor: _clear,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(resultIcon(result.finalLevel),
                size: 24, color: scheme.foreground),
            const SizedBox(width: 8),
            Text(t('검사 결과'),
                style: TextStyle(
                    color: scheme.foreground, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 20),
          Text(
            verdictTitle(result.finalLevel),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: scheme.foreground),
          ),
          const SizedBox(height: 8),
          Text(
            verdictSubtitle(result),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: scheme.foreground),
          ),
          if (result.summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              result.summary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.foreground.withValues(alpha: 0.86),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultCounts extends StatelessWidget {
  const _ResultCounts({required this.result, required this.scheme});

  final AnalysisResult result;
  final VerdictScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetricChip(label: t('직접 함유'), value: '${result.directDetections.length}'),
        _MetricChip(
          label: t('제조시설'),
          value: '${result.facilityDetections.length}',
        ),
        if (result.unknownDetections.isNotEmpty)
          _MetricChip(
              label: t('문맥 확인'), value: '${result.unknownDetections.length}'),
      ],
    );
  }
}

class _EmptyCaptureGuide extends StatelessWidget {
  const _EmptyCaptureGuide();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 280;
        return Padding(
          padding: EdgeInsets.all(compact ? 12 : 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: compact ? 48 : 64,
                height: compact ? 48 : 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _line),
                ),
                child: Icon(
                  Icons.center_focus_strong_outlined,
                  size: compact ? 28 : 34,
                  color: _teal,
                ),
              ),
              SizedBox(height: compact ? 8 : 14),
              Text(
                t('원재료명과 알레르기 표시가 보이게 찍어주세요'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: compact ? 4 : 8),
              Text(
                compact
                    ? t('라벨을 정면으로 맞추면 OCR이 더 안정적입니다.')
                    : t('흐린 사진이나 너무 기울어진 사진은 OCR이 제조시설 문구를 과하게 잡을 수 있습니다.'),
                textAlign: TextAlign.center,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: _mutedInk),
              ),
              SizedBox(height: compact ? 8 : 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SmallPill(text: t('흔들림 없이'), color: _teal),
                  _SmallPill(text: t('라벨 정면'), color: _leaf),
                  if (!compact) _SmallPill(text: t('그림자 적게'), color: _blue),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _teal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: _mutedInk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuietNotice extends StatelessWidget {
  const _QuietNotice({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      color: _softLeaf,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _leaf),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: _mutedInk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _canvas,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: _mutedInk),
              ),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class SafeByteApi {
  SafeByteApi(String baseUrl)
      : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');

  final String baseUrl;

  Future<Map<String, dynamic>> request(String method, String path, String token,
      {Map<String, dynamic>? body}) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers.addAll(
        {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'});
    if (body != null) request.body = jsonEncode(body);
    try {
      final response = await http.Response.fromStream(
          await request.send().timeout(const Duration(seconds: 30)));
      return _checkedJson(response);
    } on TimeoutException {
      throw ApiException(t('요청 시간이 초과되었습니다. 다시 시도해주세요.'));
    } on SocketException {
      throw ApiException(t('서버 연결을 확인해주세요.'));
    }
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required List<String> profiles,
    required String allergyNotes,
  }) async {
    final response = await _postJson('/api/v1/auth/register', {
      'email': email.trim(),
      'password': password,
      'display_name': displayName.trim().isEmpty ? t('사용자') : displayName.trim(),
      'profiles': profiles,
      'allergy_notes': allergyNotes.trim(),
    });
    return AuthSession.fromJson(response);
  }

  Future<AuthSession> login(String email, String password) async {
    final response = await _postJson('/api/v1/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    return AuthSession.fromJson(response);
  }

  Future<AppUser> me(String token) async {
    final response = await _getJson('/api/v1/me', token: token);
    return AppUser.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<AppUser> updatePreferences({
    required String token,
    required String displayName,
    required List<String> profiles,
    required String allergyNotes,
  }) async {
    final response = await _putJson(
      '/api/v1/me/preferences',
      token: token,
      body: {
        'display_name': displayName.trim().isEmpty ? t('사용자') : displayName.trim(),
        'profiles': profiles,
        'allergy_notes': allergyNotes.trim(),
      },
    );
    return AppUser.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<OcrHealth> ocrHealth() async {
    final response = await _getJson('/health/ocr');
    return OcrHealth.fromJson(response);
  }

  Future<CostSummary> costs() async {
    final response = await _getJson('/api/v1/costs');
    return CostSummary.fromJson(response);
  }

  Future<AnalysisResult> analyzeImage({
    required String token,
    required XFile image,
    required List<String> profiles,
    String language = 'ko',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/analyze/image'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['profiles'] = profiles.join(',');
    request.fields['language'] = language;
    request.fields['ocr_mode'] = 'live';
    request.fields['force_ocr'] = 'false';
    request.files.add(http.MultipartFile.fromBytes(
        'file', await image.readAsBytes(),
        filename: image.name));

    final http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw ApiException(t('분석 시간이 초과되었습니다. 촬영 상태와 연결을 확인해주세요.'));
    } on SocketException {
      throw ApiException(t('서버에 연결하지 못했습니다. 네트워크 또는 배포 서버 상태를 확인해주세요.'));
    } on http.ClientException catch (error) {
      throw ApiException(tf('서버 요청에 실패했습니다. {0}', [error.message]));
    }

    final body = await streamed.stream.bytesToString();
    final decoded = _decodeBody(body, statusCode: streamed.statusCode);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw ApiException(
          _errorMessage(decoded, statusCode: streamed.statusCode));
    }
    return AnalysisResult.fromJson(decoded);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _sendJson(
      () => http.post(
        Uri.parse('$baseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
    return _checkedJson(response);
  }

  Future<Map<String, dynamic>> _putJson(
    String path, {
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final response = await _sendJson(
      () => http.put(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ),
    );
    return _checkedJson(response);
  }

  Future<Map<String, dynamic>> _getJson(String path, {String? token}) async {
    final headers = <String, String>{};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final response = await _sendJson(
      () => http.get(
        Uri.parse('$baseUrl$path'),
        headers: headers,
      ),
    );
    return _checkedJson(response);
  }

  Future<http.Response> _sendJson(Future<http.Response> Function() send) async {
    try {
      return await send().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw ApiException(t('요청 시간이 초과되었습니다. 다시 시도해주세요.'));
    } on SocketException {
      throw ApiException(t('서버에 연결하지 못했습니다. 네트워크 또는 배포 서버 상태를 확인해주세요.'));
    } on http.ClientException catch (error) {
      throw ApiException(tf('서버 요청에 실패했습니다. {0}', [error.message]));
    }
  }

  Map<String, dynamic> _checkedJson(http.Response response) {
    final decoded = _decodeBody(response.body, statusCode: response.statusCode);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
          _errorMessage(decoded, statusCode: response.statusCode));
    }
    return decoded;
  }

  Map<String, dynamic> _decodeBody(String body, {int? statusCode}) {
    final codeSuffix = statusCode == null ? '' : ' (HTTP $statusCode)';
    final trimmed = body.trimLeft();
    if (trimmed.isEmpty) {
      throw ApiException(tf('서버 응답이 비어 있습니다{0}.', [codeSuffix]));
    }
    if (trimmed.startsWith('<')) {
      throw ApiException(
        tf('서버가 앱용 JSON 대신 HTML 오류 페이지를 반환했습니다{0}. 잠시 후 다시 시도해주세요.', [codeSuffix]),
      );
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      throw ApiException(tf('서버 응답 형식이 올바르지 않습니다{0}.', [codeSuffix]));
    }
    throw ApiException(tf('서버 응답을 읽지 못했습니다{0}.', [codeSuffix]));
  }

  String _errorMessage(Map<String, dynamic> payload, {int? statusCode}) {
    final detail = payload['detail'];
    final suffix = statusCode == null ? '' : ' (HTTP $statusCode)';
    if (detail is Map<String, dynamic>) {
      return '${detail['message'] ?? detail}$suffix';
    }
    return '${detail ?? t('요청에 실패했습니다.')}$suffix';
  }
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AppUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class AppUser {
  const AppUser({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.profiles,
    required this.allergyNotes,
  });

  final String userId;
  final String email;
  final String displayName;
  final List<String> profiles;
  final String allergyNotes;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      userId: json['user_id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String? ?? t('사용자'),
      profiles:
          (json['profiles'] as List<dynamic>).map((item) => '$item').toList(),
      allergyNotes: json['allergy_notes'] as String? ?? '',
    );
  }
}

class OcrHealth {
  const OcrHealth({required this.dailyLimit, required this.usageToday});

  final int dailyLimit;
  final int usageToday;

  factory OcrHealth.fromJson(Map<String, dynamic> json) {
    return OcrHealth(
      dailyLimit: (json['daily_limit'] as num?)?.toInt() ?? 0,
      usageToday: (json['usage_today'] as num?)?.toInt() ?? 0,
    );
  }
}

class CostSummary {
  const CostSummary({
    required this.ncloudCostKrw,
    required this.ocrCostKrw,
    required this.cacheConnected,
  });

  final int? ncloudCostKrw;
  final int? ocrCostKrw;
  final bool cacheConnected;

  factory CostSummary.fromJson(Map<String, dynamic> json) {
    final ncloud = json['ncloud'] as Map<String, dynamic>? ?? {};
    final ocr = json['ocr'] as Map<String, dynamic>? ?? {};
    final cache = json['cache'] as Map<String, dynamic>? ?? {};
    return CostSummary(
      ncloudCostKrw:
          (ncloud['current_month_amount_including_vat_krw'] as num?)?.toInt(),
      ocrCostKrw: (ocr['estimated_month_cost_krw'] as num?)?.toInt(),
      cacheConnected: cache['connected'] as bool? ?? false,
    );
  }
}

class AnalysisResult {
  const AnalysisResult({
    required this.requestId,
    required this.finalLevel,
    required this.summary,
    required this.ocrProvider,
    required this.cacheLabel,
    required this.paid,
    required this.ocrText,
    required this.directDetections,
    required this.facilityDetections,
    this.unknownDetections = const [],
    this.extra = const {},
  });

  final String requestId;
  final String finalLevel;
  final String summary;
  final String ocrProvider;
  final String cacheLabel;
  final bool paid;
  final String ocrText;
  final List<Detection> directDetections;
  final List<Detection> facilityDetections;
  final List<Detection> unknownDetections;
  final Map<String, dynamic> extra;

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final risk = json['risk'] as Map<String, dynamic>? ?? {};
    final ocr = json['ocr'] as Map<String, dynamic>? ?? {};
    final detections = ((risk['detections'] as List<dynamic>? ?? []).map(
      (item) => Detection.fromJson(item as Map<String, dynamic>),
    )).toList();
    return AnalysisResult(
      requestId: json['request_id'] as String? ?? '',
      finalLevel: risk['final_level'] as String? ?? 'SAFE',
      summary: risk['summary'] as String? ?? '',
      ocrProvider: ocr['provider'] as String? ?? '-',
      cacheLabel: (ocr['cached'] as bool? ?? false)
          ? 'hit/${ocr['cache_backend'] ?? 'cache'}'
          : 'miss',
      paid: ocr['called_paid_api'] as bool? ?? false,
      ocrText: (ocr['corrected_text'] ?? ocr['text'] ?? '') as String,
      directDetections: detections
          .where((item) =>
              !item.isFacilityShared && item.occurrenceType != 'unknown')
          .toList(growable: false),
      facilityDetections: detections
          .where((item) => item.isFacilityShared)
          .toList(growable: false),
      unknownDetections: detections
          .where((item) => item.occurrenceType == 'unknown')
          .toList(growable: false),
      extra: json,
    );
  }
}

class Detection {
  const Detection({
    required this.category,
    required this.severity,
    required this.name,
    required this.keyword,
    required this.reason,
    required this.occurrenceType,
    required this.label,
  });

  final String category;
  final String severity;
  final String name;
  final String keyword;
  final String reason;
  final String occurrenceType;
  final String label;

  bool get isFacilityShared => occurrenceType == 'cross_contact';

  factory Detection.fromJson(Map<String, dynamic> json) {
    return Detection(
      category: json['category'] as String? ?? '',
      severity: json['severity'] as String? ?? '',
      name: json['canonical_name'] as String? ?? '',
      keyword: json['matched_keyword'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      occurrenceType: json['occurrence_type'] as String? ?? 'unknown',
      label: json['occurrence_label'] as String? ?? t('문맥 확인'),
    );
  }
}

class VerdictScheme {
  const VerdictScheme({
    required this.background,
    required this.panel,
    required this.foreground,
  });

  final Color background;
  final Color panel;
  final Color foreground;
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

VerdictScheme resultScheme(String level) {
  switch (level) {
    case 'DANGER':
      return const VerdictScheme(
        background: _dangerBackground,
        panel: _softDanger,
        foreground: _danger,
      );
    case 'CAUTION':
      return const VerdictScheme(
        background: _amberBackground,
        panel: _softAmber,
        foreground: _amber,
      );
    default:
      return const VerdictScheme(
        background: _passBackground,
        panel: _softLeaf,
        foreground: _leaf,
      );
  }
}

IconData resultIcon(String level) {
  switch (level) {
    case 'DANGER':
      return Icons.report_gmailerrorred;
    case 'CAUTION':
      return Icons.warning_amber;
    default:
      return Icons.verified_outlined;
  }
}

String verdictTitle(String level) {
  switch (level) {
    case 'DANGER':
      return t('주의 성분이 있어요');
    case 'CAUTION':
      return t('한 번 더 확인하세요');
    default:
      return t('현재 기준 통과');
  }
}

String verdictSubtitle(AnalysisResult result) {
  switch (result.finalLevel) {
    case 'DANGER':
      return tf('피해야 할 성분 {0}개가 포함되어 있어요.', [result.directDetections.length]);
    case 'CAUTION':
      return t('제조시설 공유 또는 확인 필요한 성분이 있습니다.');
    default:
      return t('선택한 기준에서 주요 위험 성분이 감지되지 않았습니다.');
  }
}

class AllergyChoice {
  const AllergyChoice(
    this.token,
    this.label,
    this.icon,
    this.category,
    this.searchTerms,
  );

  final String token;
  final String label;
  final IconData icon;
  final String category;
  final String searchTerms;
}

class AllergyBundle {
  const AllergyBundle(this.label, this.icon, this.tokens);

  final String label;
  final IconData icon;
  final List<String> tokens;
}

// Raw Korean is the stored value that AllergyChoice.category is matched against.
// The chips translate it for display with t(category).
const allergyCategories = ['전체', '기본', '견과/곡물', '해산물', '육류', '과채/첨가물'];

const allergyBundles = [
  AllergyBundle('가장 흔한 항목', Icons.star_outline, [
    'allergy:milk',
    'allergy:egg',
    'allergy:peanut',
    'allergy:wheat',
    'allergy:soy',
  ]),
  AllergyBundle('해산물', Icons.set_meal_outlined, [
    'allergy:shrimp',
    'allergy:crab',
    'allergy:shellfish',
    'allergy:fish',
  ]),
  AllergyBundle('견과/씨앗', Icons.grain_outlined, [
    'allergy:peanut',
    'allergy:walnut',
    'allergy:pine_nut',
    'allergy:tree_nut',
    'allergy:sesame',
  ]),
];

const allergyChoices = [
  AllergyChoice(
    'allergy:milk',
    '우유',
    Icons.local_drink_outlined,
    '기본',
    'milk dairy lactose whey casein 유제품 유청 분유 버터 치즈',
  ),
  AllergyChoice(
    'allergy:egg',
    '계란',
    Icons.egg_alt_outlined,
    '기본',
    'egg 난류 알류 난백 난황',
  ),
  AllergyChoice(
    'allergy:peanut',
    '땅콩',
    Icons.grain_outlined,
    '견과/곡물',
    'peanut 피넛',
  ),
  AllergyChoice(
    'allergy:wheat',
    '밀',
    Icons.bakery_dining_outlined,
    '견과/곡물',
    'wheat gluten 소맥 밀가루 글루텐',
  ),
  AllergyChoice(
    'allergy:soy',
    '대두',
    Icons.spa_outlined,
    '기본',
    'soy soybean 콩 두류 두유 레시틴',
  ),
  AllergyChoice(
    'allergy:buckwheat',
    '메밀',
    Icons.ramen_dining_outlined,
    '견과/곡물',
    'buckwheat',
  ),
  AllergyChoice(
    'allergy:shrimp',
    '새우',
    Icons.set_meal_outlined,
    '해산물',
    'shrimp prawn 갑각류',
  ),
  AllergyChoice(
    'allergy:crab',
    '게',
    Icons.set_meal_outlined,
    '해산물',
    'crab 꽃게 갑각류',
  ),
  AllergyChoice(
    'allergy:shellfish',
    '조개류',
    Icons.set_meal_outlined,
    '해산물',
    'shellfish oyster abalone mussel 굴 전복 홍합 바지락',
  ),
  AllergyChoice(
    'allergy:pork',
    '돼지고기',
    Icons.restaurant_outlined,
    '육류',
    'pork lard 돈육 돈지 돈피 포크',
  ),
  AllergyChoice(
    'allergy:beef',
    '쇠고기',
    Icons.restaurant_outlined,
    '육류',
    'beef 소고기 우육 비프',
  ),
  AllergyChoice(
    'allergy:chicken',
    '닭고기',
    Icons.restaurant_outlined,
    '육류',
    'chicken 계육 치킨',
  ),
  AllergyChoice('allergy:peach', '복숭아', Icons.eco_outlined, '과채/첨가물', 'peach'),
  AllergyChoice(
    'allergy:tomato',
    '토마토',
    Icons.eco_outlined,
    '과채/첨가물',
    'tomato',
  ),
  AllergyChoice(
    'allergy:sulfite',
    '아황산류',
    Icons.science_outlined,
    '과채/첨가물',
    'sulfite sulphite sulfur dioxide 이산화황 메타중아황산',
  ),
  AllergyChoice(
    'allergy:walnut',
    '호두',
    Icons.grain_outlined,
    '견과/곡물',
    'walnut',
  ),
  AllergyChoice(
    'allergy:pine_nut',
    '잣',
    Icons.grain_outlined,
    '견과/곡물',
    'pine nut',
  ),
  AllergyChoice(
    'allergy:fish',
    '생선류',
    Icons.set_meal_outlined,
    '해산물',
    'fish 어류 고등어 멸치 참치 명태',
  ),
  AllergyChoice(
    'allergy:tree_nut',
    '견과류',
    Icons.grain_outlined,
    '견과/곡물',
    'tree nut almond cashew pistachio 아몬드 캐슈 피스타치오',
  ),
  AllergyChoice(
    'allergy:sesame',
    '참깨',
    Icons.grain_outlined,
    '견과/곡물',
    'sesame seed',
  ),
];

bool isAllergyToken(String profile) => profile.startsWith('allergy:');

bool hasAllergySelection(Set<String> selected) {
  return selected.contains('allergy') || selected.any(isAllergyToken);
}

String profileLabel(String profile) {
  if (isAllergyToken(profile)) {
    final match = allergyChoices.where((choice) => choice.token == profile);
    if (match.isNotEmpty) return t(match.first.label);
    return profile.split(':').last;
  }
  switch (profile) {
    case 'halal':
      return t('할랄');
    case 'vegan':
      return t('비건');
    case 'allergy':
      return t('알레르기');
    default:
      return profile;
  }
}

String profileDescription(String profile) {
  switch (profile) {
    case 'halal':
      return t('돼지고기·알코올·육류');
    case 'vegan':
      return t('우유·계란·동물성 원료');
    case 'allergy':
      return t('내 알레르기만 선택 검사');
    default:
      return t('사용자 기준');
  }
}

IconData profileIcon(String profile) {
  if (isAllergyToken(profile)) {
    final match = allergyChoices.where((choice) => choice.token == profile);
    if (match.isNotEmpty) return match.first.icon;
    return Icons.health_and_safety_outlined;
  }
  switch (profile) {
    case 'halal':
      return Icons.restaurant_menu_outlined;
    case 'vegan':
      return Icons.eco_outlined;
    case 'allergy':
      return Icons.health_and_safety_outlined;
    default:
      return Icons.check_circle_outline;
  }
}

String formatKrw(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return '₩$buffer';
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
