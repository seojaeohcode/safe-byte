import json
import httpx
import pytest

from app.core.config import Settings
from app.core.database import Database
from app.services.enrichment import EnrichmentService
from app.services.nutrition import extract_nutrition
from hardware.pi.client import CartClient


def test_only_confirmed_nutrition_is_summed(clients):
    a, b = clients
    cart = a.post('/api/v1/carts', json={'name':'nutrition', 'profiles':['vegan']}).json()['id']
    r = a.post('/api/v1/analyze/text', json={'profiles':['vegan'], 'text':'원재료명: 쌀 영양정보 100g당 열량 200kcal 나트륨 50mg 당류 2g'}).json()
    report = a.post(f'/api/v1/carts/{cart}/items', json={'request_id':r['request_id'], 'name':'쌀', 'quantity':3}).json()
    assert report['nutrition']['totals'] == {}
    item = report['items'][0]['id']
    url = f'/api/v1/carts/{cart}/items/{item}/nutrition'
    assert b.put(url, json={'energy_kcal':100}).status_code == 400
    assert a.put(url, json={'sodium_mg':-1}).status_code == 422
    totals = a.put(url, json={'energy_kcal':400,'sodium_mg':100}).json()['nutrition']
    assert totals['totals'] == {'energy_kcal':1200,'sodium_mg':300}
    assert totals['covered_quantity'] == {'energy_kcal':3,'sodium_mg':3}
    assert 'sugars_g' not in totals['totals']
    a.post(f'/api/v1/carts/{cart}/close')
    assert a.put(url,json={'energy_kcal':0}).status_code == 400


def test_nutrition_fat_not_confused_with_saturated_fat():
    result = extract_nutrition('영양정보 100g당 포화지방 3g 지방 8g 단백질 4g')
    assert result['values']['fat_g'] == 8
    assert result['values']['saturated_fat_g'] == 3
    assert result['status'] == 'unverified'


@pytest.mark.parametrize('provider', ['ollama', 'openai'])
def test_model_hallucination_rejected_and_cached(tmp_path, monkeypatch, provider):
    payload = json.dumps({'ingredients':[{'name':'쌀','evidence':'원재료명: 쌀'}, {'name':'우유','evidence':'우유 함유'}]},ensure_ascii=False)
    calls = []
    def post(url, **kwargs):
        calls.append(url)
        body = {'message':{'content':payload}} if provider == 'ollama' else {'status':'completed','output':[{'content':[{'type':'output_text','text':payload}]}]}
        return httpx.Response(200, json=body, request=httpx.Request('POST',url))
    monkeypatch.setattr(httpx,'post',post)
    settings=Settings(_env_file=None,llm_enabled=True,llm_provider=provider,openai_api_key='test')
    service=EnrichmentService(settings,Database(tmp_path/'llm.db'))
    output=service.ingredients('원재료명: 쌀')
    assert output['ingredients']==[{'name':'쌀','evidence':'원재료명: 쌀'}]
    assert output['rejected_count']==1
    assert service.ingredients('원재료명: 쌀')['cached'] is True
    assert len(calls)==1


def test_evidence_is_cut_from_the_label_not_from_the_model(tmp_path, monkeypatch):
    label = '원재료명: 쌀, 정제소금'
    payload = json.dumps({'ingredients': [
        {'name': '정제소금', 'evidence': '원재료명: 정제소금'},   # evidence never appears in the label
        {'name': '설탕', 'evidence': '원재료명: 설탕'},          # ingredient never appears either
    ]}, ensure_ascii=False)
    monkeypatch.setattr(httpx, 'post', lambda url, **kwargs: httpx.Response(
        200, json={'status':'completed','output':[{'content':[{'type':'output_text','text':payload}]}]},
        request=httpx.Request('POST', url)))
    settings = Settings(_env_file=None, llm_enabled=True, llm_provider='openai', openai_api_key='test')
    output = EnrichmentService(settings, Database(tmp_path/'evidence.db')).ingredients(label)
    assert [x['name'] for x in output['ingredients']] == ['정제소금']
    assert output['ingredients'][0]['evidence'] in label
    assert output['rejected_count'] == 1


def _risk():
    return {'final_level': 'DANGER', 'summary': '직접 함유 주의 성분: 우유',
            'detections': [{'canonical_name': '우유', 'reason': '우유는 표시 대상입니다.',
                            'rule_id': 'allergy_milk', 'category': 'allergy', 'severity': 'danger',
                            'matched_keyword': '우유', 'occurrence_type': 'direct'}]}


def test_gpt_translation_is_cached_and_leaves_korean_alone(tmp_path, monkeypatch):
    payload = json.dumps({'translations': ['Directly contained: Milk', 'Milk: Milk must be declared.']})
    calls = []
    def post(url, **kwargs):
        calls.append(url)
        return httpx.Response(200, json={'status':'completed','output':[{'content':[{'type':'output_text','text':payload}]}]},
                              request=httpx.Request('POST', url))
    monkeypatch.setattr(httpx, 'post', post)
    settings = Settings(_env_file=None, translation_enabled=True, openai_api_key='test')
    service = EnrichmentService(settings, Database(tmp_path/'translate.db'))
    result = service.translation(_risk(), 'en')
    assert result['status'] == 'translated' and result['provider'] == 'openai'
    assert result['summary'] == 'Directly contained: Milk'
    assert result['detections'] == ['Milk: Milk must be declared.']
    assert service.translation(_risk(), 'en')['cached'] is True
    assert len(calls) == 1
    korean = service.translation(_risk(), 'ko')
    assert korean['status'] == 'original' and korean['summary'] == _risk()['summary']
    assert len(calls) == 1


def test_bad_translation_falls_back_to_reviewed_vocabulary(tmp_path, monkeypatch):
    # A short response would silently drop a warning, so the reviewed wording must win.
    payload = json.dumps({'translations': ['Directly contained: Milk']})
    monkeypatch.setattr(httpx, 'post', lambda url, **kwargs: httpx.Response(
        200, json={'status':'completed','output':[{'content':[{'type':'output_text','text':payload}]}]},
        request=httpx.Request('POST', url)))
    settings = Settings(_env_file=None, translation_enabled=True, openai_api_key='test')
    result = EnrichmentService(settings, Database(tmp_path/'fallback.db')).translation(_risk(), 'en')
    assert result['status'] == 'fallback'
    assert result['summary'] == 'An ingredient conflicts with your dietary criteria.'
    assert result['detections'] and 'Milk' in result['detections'][0]


def test_translation_stops_at_the_daily_openai_quota(tmp_path, monkeypatch):
    monkeypatch.setattr(httpx, 'post', lambda url, **kwargs: pytest.fail('quota must be checked before calling OpenAI'))
    settings = Settings(_env_file=None, translation_enabled=True, openai_api_key='test', llm_daily_limit=0)
    result = EnrichmentService(settings, Database(tmp_path/'quota.db')).translation(_risk(), 'ja')
    assert result['status'] == 'quota_exceeded'
    assert result['summary'] == '食事基準に合わない成分が検出されました。'


def test_cart_device_erases_revoked_session():
    def handle(request):
        if request.url.path.endswith('redeem'):
            return httpx.Response(200,json={'token':'device-token'})
        return httpx.Response(400,json={'detail':'revoked'})
    device=CartClient('https://cart.example',transport=httpx.MockTransport(handle))
    with pytest.raises(httpx.HTTPStatusError):
        device.pair('one-time-code')
    assert device.token is None and device.session is None
    device.close()
