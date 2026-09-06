from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest

from app.core.config import Settings
from app.core.database import Database
from app.services.image_utils import PreparedImage
from app.services.ocr import CostGuardError, OcrService
from app.services.risk_rules import RiskRuleEngine


def test_auth_ownership_and_revocation(clients):
    a, b = clients
    result = a.post('/api/v1/analyze/text', json={'text':'원재료명: 우유'}).json()
    assert a.get('/api/v1/analysis/'+result['request_id']).status_code == 200
    assert b.get('/api/v1/analysis/'+result['request_id']).status_code == 404
    assert len(a.get('/api/v1/history').json()['analyses']) == 1
    a.post('/api/v1/auth/logout')
    assert a.post('/api/v1/analyze/text', json={'text':'우유'}).status_code == 401


def test_family_cart_pairing_and_close(clients):
    a,b = clients
    profile = {'name':'가족', 'profiles':['allergy:milk'], 'language':'en'}
    assert a.post('/api/v1/family', json=profile).status_code == 200
    assert b.get('/api/v1/family').json()['profiles'] == []
    cart = a.post('/api/v1/carts', json=profile).json()['id']
    r = a.post('/api/v1/analyze/text', json={'text':'원재료명: 우유', 'profiles':['allergy:milk']}).json()
    report = a.post(f'/api/v1/carts/{cart}/items', json={'request_id':r['request_id'], 'name':'우유', 'quantity':2}).json()
    assert report['final_level'] == 'DANGER'
    assert report['counts']['DANGER'] == 2
    assert b.get(f'/api/v1/carts/{cart}').status_code == 400
    code = a.post(f'/api/v1/carts/{cart}/pair').json()['code']
    device = a.post('/api/v1/devices/redeem', json={'code':code}).json()['token']
    assert a.post('/api/v1/devices/redeem', json={'code':code}).status_code == 400
    assert a.get('/api/v1/devices/session', headers={'Authorization':'Bearer '+device}).status_code == 200
    a.post(f'/api/v1/carts/{cart}/close')
    assert a.get('/api/v1/devices/session', headers={'Authorization':'Bearer '+device}).status_code == 400


def test_cart_rejects_different_criteria(clients):
    a,_ = clients
    cart=a.post('/api/v1/carts',json={'name':'test','profiles':['vegan']}).json()['id']
    result=a.post('/api/v1/analyze/text',json={'text':'원재료명: 우유','profiles':['allergy:milk']}).json()
    assert a.post(f'/api/v1/carts/{cart}/items',json={'name':'x','request_id':result['request_id']}).status_code == 400


def test_unknown_and_blank_do_not_claim_safe(clients):
    a,_=clients
    r=a.post('/api/v1/analyze/text',json={'text':'우유','profiles':['allergy:milk']}).json()
    assert r['risk']['final_level']=='CAUTION'
    assert r['risk']['detections'][0]['occurrence_type']=='unknown'
    r=a.post('/api/v1/analyze/text',json={'text':'사진이 흐립니다','language':'ar'}).json()
    assert r['risk']['final_level']=='CAUTION'
    assert r['translation']['language']=='ar'


def test_negation_does_not_hide_later_positive():
    engine=RiskRuleEngine(Path('data/risk_rules.json'))
    r=engine.detect('우유 무첨가 제품 안내. 원재료명: 우유 함유', ['allergy:milk'])
    assert r['final_level']=='DANGER'


def test_atomic_paid_quota(tmp_path):
    db=Database(tmp_path/'quota.db')
    with ThreadPoolExecutor(max_workers=8) as pool:
        results=list(pool.map(lambda _:db.reserve_usage('test',3),range(30)))
    assert sum(results)==3


def test_paid_ocr_stops_at_the_configured_daily_limit(tmp_path):
    assert Settings(_env_file=None).ocr_daily_limit == 50
    settings=Settings(_env_file=None, ocr_provider='clova', allow_paid_ocr=True, ocr_cache_enabled=False,
                      clova_ocr_invoke_url='https://example.apigw.ntruss.com/custom/v1/1/x/general',
                      clova_ocr_secret_key='secret', ocr_daily_limit=50)
    db=Database(tmp_path/'daily-limit.db')
    assert sum(db.reserve_usage('clova_ocr', settings.ocr_daily_limit) for _ in range(60))==50
    image=PreparedImage(original_hash='hash', bytes=b'jpeg', image_format='jpg', width=64, height=64,
                        original_size_bytes=4, processed_size_bytes=4, compressed=False)
    # The 51st call must be refused before any request reaches CLOVA.
    with pytest.raises(CostGuardError):
        OcrService(settings, db).extract_text(image)
    assert db.get_usage_count('clova_ocr')==50


def test_clova_preserves_line_breaks():
    raw={'images':[{'fields':[{'inferText':'원재료명:'},{'inferText':'우유','lineBreak':True},{'inferText':'제조시설'}]}]}
    assert OcrService._parse_clova_text(raw)=='원재료명: 우유\n제조시설'


def test_alternatives_use_current_user_criteria(clients):
    a,b=clients
    result=a.post('/api/v1/analyze/text',json={'text':'원재료명: 쌀, 소금','profiles':['allergy:milk']}).json()
    a.post('/api/v1/products',json={'request_id':result['request_id'],'name':'쌀과자','category':'과자'})
    payload={'name':'과자','profiles':['allergy:milk']}
    assert len(a.post('/api/v1/alternatives',json=payload).json()['products'])==1
    assert b.post('/api/v1/alternatives',json=payload).json()['products']==[]


def test_saved_products_are_owned_and_removable(clients):
    a,b=clients
    result=a.post('/api/v1/analyze/text',json={'text':'원재료명: 쌀, 소금','profiles':['allergy:milk']}).json()
    saved=a.post('/api/v1/products',json={'request_id':result['request_id'],'name':'쌀과자','category':'과자'}).json()
    assert a.get('/api/v1/products').json()['products'][0]['id']==saved['id']
    assert b.get('/api/v1/products').json()['products']==[]
    assert b.delete('/api/v1/products/'+saved['id']).status_code==400
    assert a.delete('/api/v1/products/'+saved['id']).status_code==200
    assert a.get('/api/v1/products').json()['products']==[]
