import 'dart:convert';
import 'package:flutter/material.dart';

import 'l10n.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'cart_ble.dart';

const languages = {
  'ko': '한국어',
  'en': 'English',
  'ar': 'العربية',
  'zh': '中文',
  'ja': '日本語'
};
const _paper = Color(0xffffffff);
const _mutedInk = Color(0xff66727f);
const _line = Color(0xffdce2ea);
const _softDanger = Color(0xffffefec);
const _teal = Color(0xff00b28d);
const _danger = Color(0xffce4c49);
const _amber = Color(0xff9a6f00);
const _leaf = Color(0xff1c8a63);

// Match the existing preferences screen's width, spacing and SurfacePanel.
class _WorkspaceList extends StatelessWidget {
  const _WorkspaceList({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SafeArea(
          child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final child in children)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: child),
                    ]))),
      ));
}

class _WorkspaceSectionTitle extends StatelessWidget {
  const _WorkspaceSectionTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.action,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 20)),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _mutedInk,
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 10),
          action!,
        ],
      ],
    );
  }
}

class _WorkspaceEmptyState extends StatelessWidget {
  const _WorkspaceEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      color: _paper,
      borderColor: _line,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _line.withValues(alpha: 0.26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: _mutedInk),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: _mutedInk),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

class _WorkspaceListItem extends StatelessWidget {
  const _WorkspaceListItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.trailing,
    this.iconColor = _teal,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      padding: const EdgeInsets.all(0),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _mutedInk),
        ),
        trailing: trailing ??
            const Icon(Icons.chevron_right, color: _mutedInk, size: 20),
        onTap: onTap,
      ),
    );
  }
}

String _cartVerdict(String level) =>
    {
      'EMPTY': t('아직 담은 상품이 없어요'),
      'SAFE': t('선택 기준 통과'),
      'CAUTION': t('확인이 필요한 상품'),
      'DANGER': t('주의할 성분이 있어요'),
    }[level] ??
    t('결과 확인');

class _ReferenceItem extends StatelessWidget {
  const _ReferenceItem({required this.item});

  final Map item;

  @override
  Widget build(BuildContext context) {
    final nutrients = (item['nutrients'] as List?) ?? const [];
    final meta = [item['manufacturer'], item['category'], item['updated_at']]
        .where((v) => v != null && v != '')
        .join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${item['name']}',
            style: Theme.of(context).textTheme.titleMedium),
        if (meta.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(meta,
                  style: const TextStyle(color: _mutedInk, fontSize: 12))),
        if (nutrients.isEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(t('이 항목에는 영양성분 값이 없습니다.'),
                  style: const TextStyle(color: _mutedInk, fontSize: 12)))
        else ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Text(
                tf('{0} 기준', [item['serving_size'] ?? t('표시된 기준량')]),
                style: const TextStyle(
                    color: _mutedInk, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final n in nutrients)
                DecoratedBox(
                  decoration: BoxDecoration(
                      color: _paper,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _line)),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text("${n['label']} ${n['value']}${n['unit']}",
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
            ],
          ),
        ],
        const Padding(
            padding: EdgeInsets.only(top: 10), child: Divider(height: 1)),
      ]),
    );
  }
}

String _historyDate(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

String _historyVerdict(Map raw) =>
    {
      'SAFE': t('기준 통과'),
      'CAUTION': t('확인 필요'),
      'DANGER': t('주의 성분'),
    }[raw['final_level']] ??
    (raw['status'] == 'completed' ? t('결과 보기') : t('분석 대기'));

IconData _resultIcon(Map raw) {
  switch ((raw['final_level'] ?? '').toString()) {
    case 'DANGER':
      return Icons.error_outline;
    case 'CAUTION':
      return Icons.warning_amber_rounded;
    case 'SAFE':
      return Icons.check_circle_outline;
    default:
      return Icons.schedule_rounded;
  }
}

Color _finalLevelColor(Map raw) {
  switch ((raw['final_level'] ?? '').toString()) {
    case 'DANGER':
      return _danger;
    case 'CAUTION':
      return _amber;
    default:
      return _leaf;
  }
}

class _NutritionSummary extends StatelessWidget {
  const _NutritionSummary({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final labels = {
      'energy_kcal': t('열량'),
      'sodium_mg': t('나트륨'),
      'carbohydrate_g': t('탄수화물'),
      'sugars_g': t('당류'),
      'fat_g': t('지방'),
      'saturated_fat_g': t('포화지방'),
      'protein_g': t('단백질')
    };
    final totals = data['totals'] as Map;
    return SurfacePanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(t('장바구니 영양성분 합계'),
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (totals.isEmpty)
        Text(t('상품을 눌러 라벨에 적힌 영양성분을 입력하면, 담은 수량만큼 더해서 보여드려요.'))
      else ...[
        for (final entry in totals.entries)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Expanded(
                    child: Text(tf('{0} · {1}개분', [
                      labels[entry.key] ?? entry.key,
                      data['covered_quantity'][entry.key]
                    ]))),
                Text(
                    '${entry.value} ${entry.key == 'energy_kcal' ? 'kcal' : entry.key == 'sodium_mg' ? 'mg' : 'g'}'),
              ])),
        const SizedBox(height: 8),
        Text(data['note'] as String,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ]));
  }
}

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen(
      {required this.api,
      required this.token,
      required this.user,
      this.initialTab = 0,
      this.embedded = false,
      this.onSelected,
      this.initialProfiles,
      this.initialLanguage = 'ko',
      super.key});
  final SafeByteApi api;
  final String token;
  final AppUser user;
  final int initialTab;
  final bool embedded;
  final ValueChanged<Map<String, dynamic>>? onSelected;
  final List<String>? initialProfiles;
  final String initialLanguage;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final List<dynamic> _families = [];
  final List<dynamic> _carts = [];
  final List<dynamic> _history = [];
  String? _error;
  bool _loading = true;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab.clamp(0, 2);
    _refresh();
  }

  void _select(Map<String, dynamic> selected) {
    if (widget.onSelected != null) {
      widget.onSelected!(selected);
    } else {
      Navigator.pop(context, selected);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Future.wait([
        widget.api.request('GET', '/api/v1/family', widget.token),
        widget.api.request('GET', '/api/v1/carts', widget.token),
        widget.api.request('GET', '/api/v1/history', widget.token),
      ]);
      if (!mounted) return;
      setState(() {
        _families
          ..clear()
          ..addAll(data[0]['profiles'] as List? ?? []);
        _carts
          ..clear()
          ..addAll(data[1]['carts'] as List? ?? []);
        _history
          ..clear()
          ..addAll(data[2]['analyses'] as List? ?? []);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _create(bool cart) async {
    final defaults = widget.initialProfiles?.isNotEmpty == true
        ? widget.initialProfiles!
        : widget.user.profiles;
    final newProfile = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileEditor(
          initialProfiles: defaults,
          cart: cart,
          initialName: cart ? t('나의 장보기') : '',
          initialLanguage: widget.initialLanguage,
        ),
      ),
    );
    if (newProfile == null) return;
    try {
      final path = cart ? '/api/v1/carts' : '/api/v1/family';
      await widget.api.request('POST', path, widget.token, body: {
        'name': newProfile['name'],
        'profiles': newProfile['profiles'],
        'language': newProfile['language'],
      });
      await _refresh();
      if (!cart && !widget.embedded && context.mounted) {
        showSnack(context, t('기준을 저장했어요.'));
      }
    } catch (e) {
      if (context.mounted) showSnack(context, '$e');
    }
  }

  Future<void> _editFamily(Map<String, dynamic> raw) async {
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileEditor(
          initialProfiles: List<String>.from(raw['profiles'] as List),
          cart: false,
          initialName: raw['name'] as String,
          initialLanguage: raw['language'] as String,
        ),
      ),
    );
    if (updated == null) return;
    try {
      await widget.api.request(
        'PUT',
        '/api/v1/family/${raw['id']}',
        widget.token,
        body: {
          'name': updated['name'],
          'profiles': updated['profiles'],
          'language': updated['language'],
        },
      );
      await _refresh();
    } catch (e) {
      if (context.mounted) showSnack(context, '$e');
    }
  }

  Future<void> _openCart(Map<String, dynamic> raw) async {
    try {
      final selected = await Navigator.push<Map<String, dynamic>?>(
        context,
        MaterialPageRoute(
          builder: (_) => CartScreen(
            api: widget.api,
            token: widget.token,
            cart: raw,
          ),
        ),
      );
      if (selected != null && context.mounted) _select(selected);
    } catch (e) {
      if (context.mounted) showSnack(context, '$e');
    }
  }

  Future<void> _openAnalysis(String requestId) async {
    try {
      final data = await widget.api
          .request('GET', '/api/v1/analysis/$requestId', widget.token);
      if (!mounted) return;
      final selected = await Navigator.push<Map<String, dynamic>?>(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: AnalysisResult.fromJson(data),
            api: widget.api,
            token: widget.token,
          ),
        ),
      );
      if (selected != null && mounted) _select(selected);
    } catch (e) {
      if (mounted) showSnack(context, '$e');
    }
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SurfacePanel(
            borderColor: _danger.withValues(alpha: 0.28),
            color: _softDanger,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0x33f76f6f),
                  child: Icon(Icons.warning_amber_rounded, color: _danger),
                ),
                const SizedBox(height: 12),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _loading ? null : _refresh,
                  child: Text(t('다시 시도')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return TabBarView(
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      children: [
        _WorkspaceList(children: [
          _WorkspaceSectionTitle(
            title: t('가족 기준'),
            subtitle: t('가족별로 선호 기준을 등록해 두면 분석 결과 적용이 빨라져요.'),
            icon: Icons.people_alt_rounded,
            iconColor: const Color(0xff3f6fa3),
            action: FilledButton.icon(
              onPressed: () => _create(false),
              icon: const Icon(Icons.person_add),
              label: Text(t('새 기준')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffe8f1f8),
                foregroundColor: const Color(0xff3f6fa3),
                // The shared theme asks for full width, which this row cannot give.
                minimumSize: const Size(0, 44),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_families.isEmpty)
            _WorkspaceEmptyState(
              icon: Icons.people_alt_outlined,
              title: t('등록된 가족 기준이 없습니다.'),
              message: t('새 기준을 먼저 만들면 라벨 분석에서 빠르게 적용할 수 있어요.'),
              // action omitted intentionally on empty baseline
            )
          else ...[
            const SizedBox(height: 4),
            for (final raw in _families)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _WorkspaceListItem(
                  icon: Icons.groups_rounded,
                  iconColor: const Color(0xff3f6fa3),
                  title: '${raw['name']} · ${languages[raw['language']]}',
                  subtitle:
                      '${List<String>.from(raw['profiles']).map(profileLabel).join(', ')} · ${tf('최근 사용 {0}', [raw['updated_at'] == null ? t('최근') : _historyDate(raw['updated_at'] as String)])}',
                  onTap: () => _select(Map<String, dynamic>.from(raw)),
                  trailing: PopupMenuButton<String>(
                    tooltip: t('기준 작업'),
                    icon: const Icon(Icons.more_horiz_rounded),
                    iconSize: 18,
                    color: _paper,
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _editFamily(Map<String, dynamic>.from(raw));
                        return;
                      }
                      if (value == 'delete') {
                        try {
                          await widget.api.request(
                            'DELETE',
                            '/api/v1/family/${raw['id']}',
                            widget.token,
                          );
                          await _refresh();
                        } catch (e) {
                          if (context.mounted) showSnack(context, '$e');
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'edit', child: Text(t('기준 수정'))),
                      PopupMenuItem(value: 'delete', child: Text(t('가족 삭제'))),
                    ],
                  ),
                ),
              ),
          ],
        ]),
        _WorkspaceList(children: [
          _WorkspaceSectionTitle(
            title: t('장바구니'),
            subtitle: t('분석한 라벨을 장바구니별로 분류하면 쇼핑 결정을 빠르게 할 수 있어요.'),
            icon: Icons.shopping_cart,
            iconColor: const Color(0xff1c8a63),
            action: FilledButton.icon(
              onPressed: () => _create(true),
              icon: const Icon(Icons.add_box),
              label: Text(t('새 장보기')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffe9f7f1),
                foregroundColor: const Color(0xff1c8a63),
                minimumSize: const Size(0, 44),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_carts.isEmpty)
            _WorkspaceEmptyState(
              icon: Icons.shopping_cart_outlined,
              title: t('진행 중인 장바구니가 없습니다.'),
              message: t('라벨 분석 후 장바구니에 담아 결과를 확인해 보세요.'),
              action: FilledButton(
                onPressed: () => _create(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff1c8a63),
                ),
                child: Text(t('지금 장보기 시작')),
              ),
            )
          else
            for (final raw in _carts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _WorkspaceListItem(
                  icon: Icons.shopping_cart,
                  iconColor: const Color(0xff1c8a63),
                  title: raw['name'] as String,
                  subtitle: raw['status'] == 'active' ? t('장보기 진행 중') : t('완료됨'),
                  onTap: () {
                    if (widget.embedded) {
                      _select(Map<String, dynamic>.from(raw));
                      return;
                    }
                    _openCart(Map<String, dynamic>.from(raw));
                  },
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: _mutedInk,
                  ),
                ),
              ),
        ]),
        _WorkspaceList(children: [
          _WorkspaceSectionTitle(
            title: t('분석 기록'),
            subtitle: t('최근 분석한 라벨 기록에서 상세 판단을 확인하세요.'),
            icon: Icons.history,
            iconColor: const Color(0xff66727f),
          ),
          const SizedBox(height: 16),
          if (_history.isEmpty)
            _WorkspaceEmptyState(
              icon: Icons.receipt_long_outlined,
              title: t('아직 분석 기록이 없습니다.'),
              message: t('라벨 분석 후 기록이 자동으로 쌓입니다.'),
            )
          else
            for (final raw in _history)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _WorkspaceListItem(
                  icon: _resultIcon(raw),
                  iconColor: _finalLevelColor(raw),
                  title: analysisLabel(raw['source_name'] as String?),
                  subtitle: _historyDate(raw['created_at'] as String),
                  onTap: () async {
                    if (raw['status'] == 'completed') {
                      await _openAnalysis(raw['request_id'] as String);
                    }
                  },
                  trailing: Text(
                    _historyVerdict(raw),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _finalLevelColor(raw),
                    ),
                  ),
                ),
              ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabIndicator = theme.colorScheme.primary;
    return DefaultTabController(
      length: 3,
      initialIndex: _currentTab,
      child: Scaffold(
        appBar: widget.embedded
            ? null
            : AppBar(
                title: Text(t('내 분석 자료')),
                actions: [
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: t('새로고침'),
                      onPressed: _refresh,
                    )
                ],
                bottom: TabBar(
                  indicatorColor: tabIndicator,
                  labelColor: theme.colorScheme.onSurface,
                  unselectedLabelColor: _mutedInk,
                  labelStyle: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  tabs: [
                    Tab(text: t('가족 기준'), icon: const Icon(Icons.people_outline)),
                    Tab(text: t('장바구니'), icon: const Icon(Icons.shopping_cart)),
                    Tab(text: t('기록'), icon: const Icon(Icons.history)),
                  ],
                ),
              ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.embedded)
              Material(
                color: _paper,
                child: SafeArea(
                  minimum: const EdgeInsets.only(top: 4),
                  child: TabBar(
                    onTap: (value) => _currentTab = value,
                    labelStyle: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: [
                      Tab(text: t('가족 기준'), icon: const Icon(Icons.people_outline)),
                      Tab(text: t('장바구니'), icon: const Icon(Icons.shopping_cart)),
                      Tab(text: t('기록'), icon: const Icon(Icons.history)),
                    ],
                    labelColor: theme.colorScheme.onSurface,
                    unselectedLabelColor: _mutedInk,
                    indicatorColor: tabIndicator,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: _line,
                  ),
                ),
              ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}

class ProfileEditor extends StatefulWidget {
  const ProfileEditor(
      {required this.initialProfiles,
      required this.cart,
      this.initialName = '',
      this.initialLanguage = 'ko',
      super.key});
  final List<String> initialProfiles;
  final bool cart;
  final String initialName;
  final String initialLanguage;
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final _name = TextEditingController();
  late Set<String> _profiles;
  String _language = 'ko';
  @override
  void initState() {
    super.initState();
    _profiles = widget.initialProfiles.toSet();
    _name.text = widget.initialName;
    _language = widget.initialLanguage;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toggle(String value) => setState(() {
        if (_profiles.contains(value)) {
          _profiles.remove(value);
        } else {
          if (value.startsWith('allergy:')) _profiles.remove('allergy');
          _profiles.add(value);
        }
      });
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.cart ? t('장보기 기준') : t('가족 기준'))),
        body: _WorkspaceList(children: [
          SurfacePanel(
              color: Colors.white,
              borderColor: Colors.transparent,
              padding: EdgeInsets.zero,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.cart ? t('함께 확인할 장보기 기준') : t('가족에게 맞는 검사 기준'),
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(t('이름과 식이 기준을 정하고 결과를 읽을 언어를 선택하세요.')),
                    const SizedBox(height: 18),
                    TextField(
                        controller: _name,
                        maxLength: 80,
                        decoration: InputDecoration(labelText: t('이름'))),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                        initialValue: _language,
                        decoration: InputDecoration(labelText: t('결과 언어')),
                        items: languages.entries
                            .map((e) => DropdownMenuItem(
                                value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (v) => setState(() => _language = v!)),
                    const SizedBox(height: 16),
                    ProfileSelector(selected: _profiles, onChanged: _toggle),
                    if (hasAllergySelection(_profiles))
                      AllergySelector(selected: _profiles, onChanged: _toggle),
                    const SizedBox(height: 20),
                    FilledButton(
                        onPressed: () {
                          if (_name.text.trim().isEmpty || _profiles.isEmpty) {
                            showSnack(context, t('이름과 검사 기준을 입력해주세요.'));
                            return;
                          }
                          Navigator.pop(context, {
                            'name': _name.text.trim(),
                            'profiles': _profiles.toList(),
                            'language': _language
                          });
                        },
                        child: Text(t('저장'))),
                  ]))
        ]),
      );
}

class CartScreen extends StatefulWidget {
  const CartScreen(
      {required this.api, required this.token, required this.cart, super.key});
  final SafeByteApi api;
  final String token;
  final Map<String, dynamic> cart;
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, dynamic>? _report;
  String? _error;
  bool _busy = false;
  String get _path => '/api/v1/carts/${widget.cart['id']}';
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final data = await widget.api.request('GET', _path, widget.token);
      if (mounted)
        setState(() {
          _report = data;
          _error = null;
        });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _pair() async {
    setState(() => _busy = true);
    try {
      final data =
          await widget.api.request('POST', '$_path/pair', widget.token);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(t('카트 연결')),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(t('5분 안에 카트 화면에 코드를 입력하세요. 한 번만 사용할 수 있습니다.')),
                  SelectableText(data['code'] as String),
                  TextButton(
                      onPressed: () => Clipboard.setData(
                          ClipboardData(text: data['code'] as String)),
                      child: Text(t('코드 복사'))),
                  FilledButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  CartBleScreen(code: data['code'] as String))),
                      icon: const Icon(Icons.bluetooth),
                      label: Text(t('Bluetooth로 전송'))),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(t('닫기')))
                ],
              ));
    } catch (e) {
      if (mounted) showSnack(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    setState(() => _busy = true);
    try {
      await widget.api.request('POST', '$_path/close', widget.token);
      await _refresh();
    } catch (e) {
      if (mounted) showSnack(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _nutrition(Map<String, dynamic> item) async {
    final labels = {
      'energy_kcal': t('열량 kcal'),
      'sodium_mg': t('나트륨 mg'),
      'carbohydrate_g': t('탄수화물 g'),
      'sugars_g': t('당류 g'),
      'fat_g': t('지방 g'),
      'saturated_fat_g': t('포화지방 g'),
      'protein_g': t('단백질 g')
    };
    final current = item['nutrition'] as Map? ?? {};
    final fields = {
      for (final key in labels.keys)
        key: TextEditingController(text: current[key]?.toString() ?? '')
    };
    try {
      final values = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text(t('이 상품 1개의 영양성분')),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(t('라벨이 100g당이나 1회분으로 적혀 있으면, 상품 한 개 전체 양으로 바꿔서 넣어주세요. 모르는 항목은 비워두면 합계에서 빠집니다.')),
                  const SizedBox(height: 12),
                  Text(t('사진에서 읽은 값입니다. 라벨과 맞는지 확인하고 직접 입력해 주세요.')),
                  for (final entry
                      in ((item['nutrition_candidate']?['values'] as Map?) ??
                              {})
                          .entries)
                    if (labels.containsKey(entry.key))
                      Text('${labels[entry.key]}: ${entry.value}'),
                  for (final entry in labels.entries)
                    TextField(
                        controller: fields[entry.key],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(labelText: entry.value)),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(t('취소'))),
                  FilledButton(
                      onPressed: () {
                        final data = <String, dynamic>{};
                        for (final entry in fields.entries) {
                          if (entry.value.text.trim().isEmpty) continue;
                          final value =
                              double.tryParse(entry.value.text.trim());
                          if (value == null || !value.isFinite || value < 0) {
                            showSnack(ctx, t('0 이상의 숫자를 입력하세요.'));
                            return;
                          }
                          data[entry.key] = value;
                        }
                        Navigator.pop(ctx, data);
                      },
                      child: Text(t('라벨 확인 · 저장')))
                ],
              ));
      if (values != null) {
        await widget.api.request(
            'PUT', '$_path/items/${item['id']}/nutrition', widget.token,
            body: values);
        await _refresh();
      }
    } catch (e) {
      if (mounted) showSnack(context, '$e');
    } finally {
      for (final field in fields.values) {
        field.dispose();
      }
    }
  }

  Future<void> _quantity(Map<String, dynamic> item, int quantity) async {
    if (_busy || quantity < 1 || quantity > 100) return;
    setState(() => _busy = true);
    try {
      await widget.api.request('POST', '$_path/items', widget.token, body: {
        'request_id': item['request_id'],
        'name': item['name'],
        'quantity': quantity,
      });
      await _refresh();
    } catch (e) {
      if (mounted) showSnack(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _itemAction(Map<String, dynamic> item, String action) async {
    if (action == 'nutrition') {
      await _nutrition(item);
      return;
    }
    try {
      if (action == 'result') {
        final data = await widget.api.request(
            'GET', '/api/v1/analysis/${item['request_id']}', widget.token);
        if (mounted) {
          final selected = await Navigator.push<Map<String, dynamic>>(
              context,
              MaterialPageRoute(
                  builder: (_) => ResultScreen(
                      result: AnalysisResult.fromJson(data),
                      api: widget.api,
                      token: widget.token)));
          if (selected != null && mounted) Navigator.pop(context, selected);
        }
      } else if (action == 'name') {
        final field = TextEditingController(text: item['name'] as String);
        try {
          final name = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                      title: Text(t('상품 이름')),
                      content: TextField(
                          controller: field, maxLength: 150, autofocus: true),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(t('취소'))),
                        TextButton(
                            onPressed: () {
                              if (field.text.trim().isNotEmpty)
                                Navigator.pop(ctx, field.text.trim());
                            },
                            child: Text(t('저장')))
                      ]));
          if (name != null)
            await _quantity({...item, 'name': name}, item['quantity'] as int);
        } finally {
          field.dispose();
        }
      } else {
        await widget.api
            .request('DELETE', '$_path/items/${item['id']}', widget.token);
        await _refresh();
      }
    } catch (e) {
      if (mounted) showSnack(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.cart['name'] as String), actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))
        ]),
        body: _report == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Text(_error!))
            : _WorkspaceList(children: [
                SurfacePanel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Text(_cartVerdict(_report!['final_level'] as String),
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(tf('장바구니에 총 {0}개 담았어요', [_report!['total_quantity']])),
                      if ((_report!['total_quantity'] as num) > 0) ...[
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final entry
                              in (_report!['counts'] as Map).entries)
                            if ((entry.value as num) > 0)
                              Chip(
                                  label: Text(
                                      tf('{0} {1}개', [_cartVerdict(entry.key as String), entry.value])))
                        ]),
                      ],
                    ])),
                const SizedBox(height: 14),
                _NutritionSummary(
                    data: Map<String, dynamic>.from(_report!['nutrition'])),
                const SizedBox(height: 16),
                if (_report!['cart']['status'] == 'active') ...[
                  FilledButton.icon(
                      onPressed: () => Navigator.pop(context,
                          {...widget.cart, 'cart_id': widget.cart['id']}),
                      icon: const Icon(Icons.camera_alt),
                      label: Text(t('이 기준으로 스캔'))),
                  OutlinedButton.icon(
                      onPressed: _busy ? null : _pair,
                      icon: const Icon(Icons.link),
                      label: Text(t('카트 기기 연결'))),
                  OutlinedButton(
                      onPressed: _busy ? null : _close,
                      child: Text(t('장보기 종료'))),
                ],
                const SizedBox(height: 16),
                for (final item in _report!['items'] as List)
                  Card(
                      child: ListTile(
                    onTap: () =>
                        _itemAction(Map<String, dynamic>.from(item), 'result'),
                    title: Text('${item['name']} × ${item['quantity']}'),
                    subtitle: Text(
                        '${_cartVerdict(item['risk']['final_level'] as String)}\n${item['risk']['summary']}'),
                    trailing: _report!['cart']['status'] != 'active'
                        ? null
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                                tooltip: t('수량 줄이기'),
                                icon: const Icon(Icons.remove),
                                onPressed: _busy || item['quantity'] <= 1
                                    ? null
                                    : () => _quantity(
                                        Map<String, dynamic>.from(item),
                                        (item['quantity'] as int) - 1)),
                            IconButton(
                                tooltip: t('수량 늘리기'),
                                icon: const Icon(Icons.add),
                                onPressed: _busy || item['quantity'] >= 100
                                    ? null
                                    : () => _quantity(
                                        Map<String, dynamic>.from(item),
                                        (item['quantity'] as int) + 1)),
                            PopupMenuButton<String>(
                                enabled: !_busy,
                                tooltip: t('상품 관리'),
                                onSelected: (action) => _itemAction(
                                    Map<String, dynamic>.from(item), action),
                                itemBuilder: (_) => [
                                      PopupMenuItem(
                                          value: 'name', child: Text(t('상품명 수정'))),
                                      PopupMenuItem(
                                          value: 'nutrition',
                                          child: Text(t('영양성분 확인'))),
                                      PopupMenuItem(
                                          value: 'remove',
                                          child: Text(t('장바구니에서 빼기'))),
                                    ]),
                          ]),
                  )),
              ]),
      );
}

class ResultExtras extends StatelessWidget {
  const ResultExtras({required this.result, this.api, this.token, super.key});
  final AnalysisResult result;
  final SafeByteApi? api;
  final String? token;
  Future<void> _addToCart(BuildContext context) async {
    try {
      final data = await api!.request('GET', '/api/v1/carts', token!);
      if (!context.mounted) return;
      final carts = (data['carts'] as List)
          .where((c) => c['status'] == 'active')
          .toList();
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
                  child: ListView(shrinkWrap: true, children: [
                ListTile(
                    title: Text(t('담을 장바구니를 선택하세요')),
                    subtitle: Text(t('분석할 때와 같은 검사 기준의 장바구니에 담을 수 있어요.'))),
                for (final cart in carts)
                  ListTile(
                      leading: const Icon(Icons.shopping_bag_outlined),
                      title: Text(cart['name'] as String),
                      subtitle: Text(List<String>.from(cart['profiles'])
                          .map(profileLabel)
                          .join(' · ')),
                      onTap: () =>
                          Navigator.pop(ctx, Map<String, dynamic>.from(cart))),
                ListTile(
                    leading: const Icon(Icons.add),
                    title: Text(t('이 기준으로 새 장보기')),
                    onTap: () => Navigator.pop(ctx, <String, dynamic>{})),
              ])));
      if (selected == null) return;
      final cart = selected.isEmpty
          ? await api!.request('POST', '/api/v1/carts', token!, body: {
              'name': t('나의 장보기'),
              'profiles': result.extra['profiles'],
              'language': result.extra['translation']?['language'] ?? 'ko',
            })
          : selected;
      final current =
          await api!.request('GET', '/api/v1/carts/${cart['id']}', token!);
      if (!(current['items'] as List)
          .any((i) => i['request_id'] == result.requestId)) {
        await api!.request('POST', '/api/v1/carts/${cart['id']}/items', token!,
            body: {
              'request_id': result.requestId,
              'name': t('스캔한 상품'),
              'quantity': 1
            });
      }
      if (context.mounted) {
        final scan = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    CartScreen(api: api!, token: token!, cart: cart)));
        if (scan != null && context.mounted) Navigator.pop(context, scan);
      }
    } catch (e) {
      if (context.mounted) showSnack(context, '$e');
    }
  }

  Future<void> _reference(BuildContext context) async {
    final name = TextEditingController();
    String kind = 'nutrition';
    try {
      final accepted = await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
              builder: (ctx, update) => AlertDialog(
                    title: Text(t('식약처 정보 조회')),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButton<String>(
                          value: kind,
                          items: [
                            DropdownMenuItem(
                                value: 'nutrition', child: Text(t('식품'))),
                            DropdownMenuItem(
                                value: 'ingredient', child: Text(t('원료')))
                          ],
                          onChanged: (v) => update(() => kind = v!)),
                      TextField(
                          controller: name,
                          maxLength: 100,
                          decoration:
                              InputDecoration(labelText: t('라벨에 적힌 이름'))),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(t('취소'))),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(t('조회')))
                    ],
                  )));
      if (accepted != true || name.text.trim().length < 2) return;
      final data = await api!.request(
          'POST', '/api/v1/references/search', token!,
          body: {'name': name.text.trim(), 'kind': kind});
      if (!context.mounted) return;
      await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text(t('식약처 영양성분 참고값')),
                content: SizedBox(
                    width: 360,
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(data['note'] as String),
                      if ((data['items'] as List).isEmpty)
                        Text(tf('조회 상태: {0}', [data['status']])),
                      for (final item in data['items'] as List)
                        _ReferenceItem(item: item as Map),
                    ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(t('닫기')))
                ],
              ));
    } catch (e) {
      if (context.mounted) showSnack(context, '$e');
    } finally {
      name.dispose();
    }
  }

  Future<void> _products(BuildContext context, bool save) async {
    final name = TextEditingController();
    final category = TextEditingController();
    try {
      final accepted = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text(save ? t('상품 라벨 저장') : t('대체 상품')),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (save)
                    TextField(
                        controller: name,
                        decoration: InputDecoration(labelText: t('상품명'))),
                  TextField(
                      controller: category,
                      decoration: InputDecoration(labelText: t('상품 분류'))),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(t('취소'))),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(t('확인')))
                ],
              ));
      if (accepted != true ||
          category.text.trim().isEmpty ||
          (save && name.text.trim().isEmpty)) return;
      final data = await api!.request(
          'POST', save ? '/api/v1/products' : '/api/v1/alternatives', token!,
          body: save
              ? {
                  'request_id': result.requestId,
                  'name': name.text.trim(),
                  'category': category.text.trim()
                }
              : {
                  'name': category.text.trim(),
                  'profiles': result.extra['profiles']
                });
      if (!context.mounted) return;
      if (save) {
        showSnack(context, t('저장했습니다.'));
      } else {
        await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: Text(t('대체 상품')),
                    content: SingleChildScrollView(
                        child: Text((data['products'] as List).isEmpty
                            ? t('같은 분류로 저장한 상품이 없습니다.')
                            : (data['products'] as List)
                                .map((p) => p['name'])
                                .join('\n'))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(t('닫기')))
                    ]));
      }
    } catch (e) {
      if (context.mounted) showSnack(context, '$e');
    } finally {
      name.dispose();
      category.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final translation = result.extra['translation'] as Map<String, dynamic>?;
    final preview = result.extra['preview_data_url'] as String?;
    final regions = (result.extra['ocr']?['regions'] as List?) ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (api != null && token != null) ...[
        OutlinedButton.icon(
            onPressed: () => _addToCart(context),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text(t('장바구니에 담기'))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          TextButton.icon(
              onPressed: () => _products(context, true),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(t('상품 저장'))),
          TextButton.icon(
              onPressed: () => _products(context, false),
              icon: const Icon(Icons.swap_horiz),
              label: Text(t('대체 상품'))),
          TextButton.icon(
              onPressed: () => _reference(context),
              icon: const Icon(Icons.search),
              label: Text(t('식약처 정보'))),
        ]),
      ],
      if (translation != null && translation['language'] != 'ko')
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Directionality(
                textDirection: translation['language'] == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(translation['summary'] as String,
                          style: Theme.of(context).textTheme.titleLarge),
                      for (final text
                          in translation['detections'] as List? ?? [])
                        Text(text as String),
                      if (translation['status'] != 'translated')
                        Text(t('요약 번역입니다. 원문도 함께 확인하세요.')),
                    ]))),
      if (preview != null)
        AspectRatio(
            aspectRatio: (result.extra['image']['width'] as num) /
                (result.extra['image']['height'] as num),
            child: Stack(fit: StackFit.expand, children: [
              Image.memory(base64Decode(preview.split(',').last),
                  fit: BoxFit.fill),
              CustomPaint(painter: RiskOverlayPainter(regions))
            ])),
    ]);
  }
}

class RiskOverlayPainter extends CustomPainter {
  RiskOverlayPainter(this.regions);
  final List<dynamic> regions;
  @override
  void paint(Canvas canvas, Size size) {
    for (final region in regions) {
      if (region['severity'] == null) continue;
      final points = region['polygon'] as List;
      if (points.isEmpty) continue;
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final x = (points[i]['x'] as num).toDouble() * size.width;
        final y = (points[i]['y'] as num).toDouble() * size.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      final color = region['severity'] == 'danger' ? Colors.red : Colors.orange;
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.2));
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant RiskOverlayPainter oldDelegate) =>
      oldDelegate.regions != regions;
}

class SavedProductsScreen extends StatefulWidget {
  const SavedProductsScreen(
      {required this.api, required this.token, super.key});
  final SafeByteApi api;
  final String token;
  @override
  State<SavedProductsScreen> createState() => _SavedProductsScreenState();
}

class _SavedProductsScreenState extends State<SavedProductsScreen> {
  List<dynamic>? _products;
  String? _error;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final data =
          await widget.api.request('GET', '/api/v1/products', widget.token);
      if (mounted)
        setState(() {
          _products = data['products'] as List;
          _error = null;
        });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _open(String id) async {
    try {
      final data =
          await widget.api.request('GET', '/api/v1/analysis/$id', widget.token);
      if (mounted) {
        final selected = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(
                builder: (_) => ResultScreen(
                    result: AnalysisResult.fromJson(data),
                    api: widget.api,
                    token: widget.token)));
        if (selected != null && mounted) Navigator.pop(context, selected);
      }
    } catch (e) {
      if (mounted) showSnack(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(t('저장한 상품'))),
      body: _error != null
          ? Center(
              child: TextButton(
                  onPressed: _refresh, child: Text(tf('다시 불러오기: {0}', [_error]))))
          : _products == null
              ? const Center(child: CircularProgressIndicator())
              : _WorkspaceList(children: [
                  if (_products!.isEmpty)
                    SurfacePanel(
                        child: Column(children: [
                      const Icon(Icons.bookmark_border, size: 44),
                      const SizedBox(height: 16),
                      Text(t('다시 확인하고 싶은 상품을 모아보세요.')),
                      const SizedBox(height: 8),
                      Text(t('라벨 분석 결과에서 상품을 저장할 수 있어요.'))
                    ])),
                  for (final item in _products!)
                    Card(
                        child: ListTile(
                            title: Text(item['name'] as String),
                            subtitle: Text(item['category'] as String),
                            onTap: () =>
                                _open(item['source_request_id'] as String),
                            trailing: IconButton(
                                tooltip: t('저장 취소'),
                                icon:
                                    const Icon(Icons.bookmark_remove_outlined),
                                onPressed: () async {
                                  try {
                                    await widget.api.request(
                                        'DELETE',
                                        '/api/v1/products/${item['id']}',
                                        widget.token);
                                    await _refresh();
                                  } catch (e) {
                                    if (context.mounted)
                                      showSnack(context, '$e');
                                  }
                                }))),
                ]));
}
