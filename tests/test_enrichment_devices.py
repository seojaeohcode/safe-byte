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
