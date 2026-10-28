part of 'main.dart';

/// Shared presentation primitives. All data and callbacks come from the
/// original application; this file contains no network or device operations.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 64, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _softTeal,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.verified_user_outlined,
          color: _actionTeal,
          size: size * .52,
        ),
      );
}

class BottomAction extends StatelessWidget {
  const BottomAction({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: _paper,
          border: Border(top: BorderSide(color: _line)),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: child,
        ),
      );
}

class LabelGuide extends StatelessWidget {
  const LabelGuide({super.key});
  @override
  Widget build(BuildContext context) => Container(
        height: 112,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _paperWarm,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: 216,
          height: 104,
          child: CustomPaint(
            painter: _LabelPainter(),
            child: const Center(
              child: Icon(
                Icons.document_scanner_outlined,
                size: 40,
                color: _actionTeal,
              ),
            ),
          ),
        ),
      );
}

class _LabelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _actionTeal
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final point in [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      final dx = point.dx == 0 ? 1.0 : -1.0;
      final dy = point.dy == 0 ? 1.0 : -1.0;
      canvas.drawPath(
        Path()
          ..moveTo(point.dx, point.dy + 18 * dy)
          ..lineTo(point.dx, point.dy)
          ..lineTo(point.dx + 18 * dx, point.dy),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AnalyzingScreen extends StatelessWidget {
  const AnalyzingScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(automaticallyImplyLeading: false, title: Text(t('라벨 분석'))),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const LabelGuide(),
                const SizedBox(height: 40),
                Text(
                  t('라벨을 확인하고 있어요'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  t('원재료명과 알레르기 표시를 읽고 있어요.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _mutedInk),
                ),
                const SizedBox(height: 32),
                const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
                const Spacer(flex: 2),
                Text(
                  'NAVER CLOVA OCR',
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

class VerdictView extends StatelessWidget {
  const VerdictView({required this.result, this.api, this.token, super.key});
  final AnalysisResult result;
  final SafeByteApi? api;
  final String? token;
  @override
  Widget build(BuildContext context) {
    final scheme = resultScheme(result.finalLevel);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(t('검사 결과')),
        actions: [
          IconButton(
            tooltip: t('닫기'),
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.close),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: BottomAction(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => showResultDetails(context, result),
              child: Text(t('세부 설명 보기')),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(t('다른 라벨 확인')),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.panel,
                shape: BoxShape.circle,
              ),
              child: Icon(
                resultIcon(result.finalLevel),
                size: 44,
                color: scheme.foreground,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            verdictTitle(result.finalLevel),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 40,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: scheme.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            verdictSubtitle(result),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 32),
          SurfacePanel(
            color: _paperWarm,
            borderColor: _paperWarm,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                _EvidenceLine(
                  icon: Icons.restaurant_outlined,
                  title: t('직접 함유'),
                  value: result.directDetections.isEmpty
                      ? t('미검출')
                      : result.directDetections
                          .map((d) => t(d.name.split('/').first))
                          .join(', '),
                ),
                const Divider(),
                _EvidenceLine(
                  icon: Icons.factory_outlined,
                  title: t('같은 제조시설'),
                  value: result.facilityDetections.isEmpty
                      ? t('미검출')
                      : result.facilityDetections
                          .map((d) => t(d.name.split('/').first))
                          .join(', '),
                ),
                if (result.unknownDetections.isNotEmpty) ...[
                  const Divider(),
                  _EvidenceLine(
                    icon: Icons.help_outline,
                    title: t('문맥 확인'),
                    value: '${result.unknownDetections.length}',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t('분석 결과와 함께 제품의 실제 표시사항을 확인해 주세요.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _mutedInk, height: 1.6),
          ),
          if (result.extra.isNotEmpty) ...[
            const SizedBox(height: 24),
            ResultExtras(result: result, api: api, token: token),
          ],
        ],
      ),
    );
  }
}

class _EvidenceLine extends StatelessWidget {
  const _EvidenceLine({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title, value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: _mutedInk, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ],
        ),
      );
}

class ResultDetailScreen extends StatelessWidget {
  const ResultDetailScreen({required this.result, super.key});
  final AnalysisResult result;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('세부 설명'))),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(t('판단 근거'), style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              t('원재료와 제조시설을 나누어 확인해요.'),
              style: const TextStyle(color: _mutedInk),
            ),
            const SizedBox(height: 32),
            _detailHeading(
              context,
              Icons.restaurant_outlined,
              t('직접 함유'),
              result.directDetections.length,
            ),
            const SizedBox(height: 8),
            if (result.directDetections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(t('미검출')),
              ),
            ...result.directDetections.map((d) => _detailRow(context, d)),
            const SizedBox(height: 24),
            _detailHeading(
              context,
              Icons.factory_outlined,
              t('같은 제조시설'),
              result.facilityDetections.length,
            ),
            const SizedBox(height: 8),
            if (result.facilityDetections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(t('미검출')),
              ),
            ...result.facilityDetections.map((d) => _detailRow(context, d)),
            if (result.unknownDetections.isNotEmpty) ...[
              const SizedBox(height: 24),
              _detailHeading(
                context,
                Icons.help_outline,
                t('문맥 확인'),
                result.unknownDetections.length,
              ),
              ...result.unknownDetections.map((d) => _detailRow(context, d)),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Text(t('OCR 원문'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SurfacePanel(
              color: _paperWarm,
              borderColor: _paperWarm,
              child: SelectableText(
                result.ocrText.isEmpty ? t('OCR 텍스트가 없습니다.') : result.ocrText,
                style: const TextStyle(fontSize: 13, height: 1.8),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'NAVER CLOVA OCR',
              style: TextStyle(fontSize: 12, color: _mutedInk),
            ),
          ],
        ),
      );
  Widget _detailHeading(
    BuildContext context,
    IconData icon,
    String label,
    int count,
  ) =>
      Row(
        children: [
          Icon(icon, color: _ink),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 8),
          Text('$count', style: const TextStyle(color: _mutedInk)),
        ],
      );
  Widget _detailRow(BuildContext context, Detection d) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              d.name,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: d.isFacilityShared ? _amber : _danger,
              ),
            ),
            const SizedBox(height: 4),
            Text('“${d.keyword}”', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              d.reason,
              style:
                  const TextStyle(color: _mutedInk, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      );
}

class PairingCodeScreen extends StatelessWidget {
  const PairingCodeScreen({required this.code, super.key});
  final String code;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('카트 연결'))),
        // The cart has no Bluetooth: the user types this code on the cart's touch screen,
        // and the cart exchanges it with the server over Wi-Fi.
        bottomNavigationBar: BottomAction(
          child: FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check),
            label: Text(t('입력 완료')),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 8),
            const Center(child: BrandMark(size: 72)),
            const SizedBox(height: 24),
            Text(
              t('카트에 코드를 입력하세요'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              t('5분 안에 연결해 주세요. 한 번만 사용할 수 있어요.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _mutedInk),
            ),
            const SizedBox(height: 28),
            SurfacePanel(
              color: _paperWarm,
              borderColor: _paperWarm,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) showSnack(context, t('코드를 복사했어요.'));
              },
              icon: const Icon(Icons.copy_outlined),
              label: Text(t('코드 복사')),
            ),
            const SizedBox(height: 16),
            for (final (i, step) in [
              '카트 화면에 이 6자리 코드를 입력하세요',
              '카트의 ‘연결’을 누르세요',
              '카트에 내 기준이 보이면 연결된 거예요',
            ].indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: _paperWarm,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(t(step))),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              t('카트는 Wi-Fi로 서버에 연결돼요. 비밀번호는 카트에 남지 않아요.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _mutedInk, fontSize: 13),
            ),
          ],
        ),
      );
}
