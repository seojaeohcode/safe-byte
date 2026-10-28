// Offline fixtures only; never delegates an operation to the production API.
import 'main.dart';
import 'package:image_picker/image_picker.dart';

const previewUser = AppUser(
  userId: 'preview-user',
  email: 'preview@safebyte.test',
  displayName: '지민',
  profiles: [
    'halal',
    'vegan',
    'allergy:milk',
    'allergy:wheat',
    'allergy:peanut',
  ],
  allergyNotes: '',
);

const previewResult = AnalysisResult(
  requestId: 'preview-001',
  finalLevel: 'DANGER',
  summary: '직접 함유 위험 성분: 우유/유제품, 밀/글루텐. 제조시설 공유 표기: 땅콩.',
  ocrProvider: 'clova',
  cacheLabel: 'miss',
  paid: true,
  ocrText: '원재료명: 밀가루, 전지분유, 대두레시틴\n우유, 밀, 대두 함유\n땅콩을 사용한 제품과 같은 제조시설',
  directDetections: [
    Detection(
      category: 'allergy',
      severity: 'danger',
      name: '우유/유제품',
      keyword: '전지분유',
      reason: '원재료명에서 우유 성분을 확인했어요.',
      occurrenceType: 'ingredient',
      label: '직접 함유',
    ),
    Detection(
      category: 'allergy',
      severity: 'danger',
      name: '밀/글루텐',
      keyword: '밀가루',
      reason: '원재료명에서 밀 성분을 확인했어요.',
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
      reason: '같은 제조시설 표기에서 확인했어요.',
      occurrenceType: 'cross_contact',
      label: '제조시설 공유',
    ),
  ],
);

/// A camera file name as image_picker actually produces it, plus a text analysis,
/// so the history capture shows what the list does with both.
const historyRows = [
  {
    'request_id': 'preview-001',
    'source_name':
        'scaled_026bc63a-de71-4a34-bce5-fc39a0ffa9141191473233696622227.jpg',
    'status': 'completed',
    'final_level': 'SAFE',
    'created_at': '2026-10-28T10:20:00+00:00',
  },
  {
    'request_id': 'preview-002',
    'source_name': 'direct_text',
    'status': 'completed',
    'final_level': 'DANGER',
    'created_at': '2026-10-28T09:05:00+00:00',
  },
  {
    'request_id': 'preview-003',
    'source_name': '오설록 롤케이크 라벨.jpg',
    'status': 'completed',
    'final_level': 'CAUTION',
    'created_at': '2026-10-27T18:40:00+00:00',
  },
];

class PreviewApi extends SafeByteApi {
  PreviewApi() : super('http://preview.local');
  final paths = <String>[];

  @override
  Future<Map<String, dynamic>> request(String method, String path, String token,
      {Map<String, dynamic>? body}) async {
    paths.add(path);
    if (path.endsWith('/pair')) return {'code': '482619'};
    if (path == '/api/v1/family') {
      return {
        'profiles': [
          {
            'id': 'family',
            'name': '우리 가족',
            'profiles': ['allergy:milk', 'allergy:peanut'],
            'updated_at': '2026-10-28T09:00:00+09:00'
          }
        ]
      };
    }
    if (path.startsWith('/api/v1/analysis/')) {
      return {
        'request_id': 'preview-001',
        'risk': {
          'final_level': 'DANGER',
          'summary': previewResult.summary,
          'detections': [
            for (final d in [
              ...previewResult.directDetections,
              ...previewResult.facilityDetections
            ])
              {
                'category': d.category,
                'severity': d.severity,
                'canonical_name': d.name,
                'matched_keyword': d.keyword,
                'reason': d.reason,
                'occurrence_type': d.occurrenceType,
                'occurrence_label': d.label
              }
          ]
        },
        'ocr': {'provider': 'clova', 'text': previewResult.ocrText}
      };
    }
    if (path == '/api/v1/history') {
      return {
        'analyses': historyRows,
      };
    }
    if (path == '/api/v1/references/search') {
      return {
        'source': 'MFDS',
        'kind': 'nutrition',
        'query': '오설록',
        'status': 'found',
        'note':
            '식약처 식품영양성분 DB의 참고값입니다. 같은 이름이라도 제조사와 기준량이 다르면 값이 다릅니다. 실제 라벨 표시를 우선하세요.',
        'items': [
          {
            'name': '오설록그린티롤케이크(화이트)',
            'manufacturer': '플레이버랩주식회사',
            'category': '빵류',
            'serving_size': '100g',
            'updated_at': '2026-05-07',
            'nutrients': [
              {
                'key': 'energy_kcal',
                'label': '열량',
                'unit': 'kcal',
                'value': 308.0
              },
              {'key': 'protein_g', 'label': '단백질', 'unit': 'g', 'value': 8.5},
              {'key': 'fat_g', 'label': '지방', 'unit': 'g', 'value': 18.25},
              {
                'key': 'carbohydrate_g',
                'label': '탄수화물',
                'unit': 'g',
                'value': 27.25
              },
              {'key': 'sugars_g', 'label': '당류', 'unit': 'g', 'value': 21.75},
              {'key': 'sodium_mg', 'label': '나트륨', 'unit': 'mg', 'value': 98.0},
              {
                'key': 'cholesterol_mg',
                'label': '콜레스테롤',
                'unit': 'mg',
                'value': 206.25
              },
              {
                'key': 'saturated_fat_g',
                'label': '포화지방',
                'unit': 'g',
                'value': 9.25
              },
              {
                'key': 'trans_fat_g',
                'label': '트랜스지방',
                'unit': 'g',
                'value': 0.35
              },
            ],
          },
          {
            'name': '오설록 가루녹차',
            'manufacturer': '(주)오설록농장',
            'category': '다류',
            'serving_size': '100g',
            'updated_at': '2026-05-07',
            'nutrients': [
              {
                'key': 'energy_kcal',
                'label': '열량',
                'unit': 'kcal',
                'value': 331.0
              },
              {'key': 'protein_g', 'label': '단백질', 'unit': 'g', 'value': 29.6},
              {'key': 'sodium_mg', 'label': '나트륨', 'unit': 'mg', 'value': 6.0},
            ],
          },
        ],
      };
    }
    if (path == '/api/v1/products') {
      return {
        'products': [
          {
            'id': 'product',
            'name': '쌀과자',
            'category': '과자',
            'source_request_id': 'preview'
          }
        ]
      };
    }
    if (path == '/api/v1/carts') {
      return {
        'carts': [
          {
            'id': 'preview',
            'name': '주말 장보기',
            'status': 'active',
            'profiles': ['vegan'],
            'language': 'ko'
          }
        ]
      };
    }
    if (path.startsWith('/api/v1/carts/')) {
      return {
        'cart': {'status': 'active'},
        'items': [
          {
            'id': 'rice',
            'request_id': 'preview-001',
            'name': '쌀과자',
            'quantity': 2,
            'risk': {'final_level': 'SAFE', 'summary': '미검출'}
          },
          {
            'id': 'cake',
            'request_id': 'preview-003',
            'name': '녹차 롤케이크',
            'quantity': 1,
            'risk': {'final_level': 'CAUTION', 'summary': '같은 제조시설: 땅콩'}
          },
        ],
        'counts': {'SAFE': 2, 'CAUTION': 1, 'DANGER': 0},
        'final_level': 'CAUTION',
        'total_quantity': 3,
        'nutrition': {
          'totals': {
            'energy_kcal': 420,
            'sodium_mg': 180,
            'sugars_g': 12,
            'protein_g': 6
          },
          'covered_quantity': {
            'energy_kcal': 2,
            'sodium_mg': 2,
            'sugars_g': 2,
            'protein_g': 2
          },
          'note': '확인한 2개분만 합산했어요.'
        },
      };
    }
    throw StateError('Unmocked request: $method $path');
  }

  @override
  Future<AuthSession> login(String email, String password) async =>
      const AuthSession(token: 'preview', user: previewUser);
  @override
  Future<AuthSession> register(
          {required String email,
          required String password,
          required String displayName,
          required List<String> profiles,
          required String allergyNotes}) async =>
      const AuthSession(token: 'preview', user: previewUser);
  @override
  Future<AppUser> me(String token) async => previewUser;
  @override
  Future<AppUser> updatePreferences(
          {required String token,
          required String displayName,
          required List<String> profiles,
          required String allergyNotes}) async =>
      AppUser(
          userId: 'preview-user',
          email: previewUser.email,
          displayName: displayName,
          profiles: profiles,
          allergyNotes: allergyNotes);
  @override
  Future<AnalysisResult> analyzeImage(
          {required String token,
          required XFile image,
          required List<String> profiles,
          String language = 'ko'}) async =>
      previewResult;

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

AnalysisResult previewVerdict(String level) => AnalysisResult(
      requestId: 'preview-$level',
      finalLevel: level,
      summary: '',
      ocrProvider: 'clova',
      cacheLabel: 'miss',
      paid: false,
      ocrText: level == 'SAFE' ? '원재료명: 쌀, 정제소금' : previewResult.ocrText,
      directDetections: level == 'DANGER' ? previewResult.directDetections : [],
      facilityDetections:
          level == 'SAFE' ? [] : previewResult.facilityDetections,
    );
