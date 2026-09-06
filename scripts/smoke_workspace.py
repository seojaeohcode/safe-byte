"""Exercise deployed authenticated workflows using explicitly synthetic text labels."""
import argparse
import json
import secrets
import uuid
import httpx


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--api', default='http://127.0.0.1:8080')
    args = parser.parse_args()
    report = {'synthetic_text_only': True, 'paid_ocr_calls': 0}
    with httpx.Client(base_url=args.api, timeout=60) as client:
        def call(method, path, payload=None):
            response = client.request(method, '/api/v1'+path, json=payload)
            if response.status_code >= 400:
                raise RuntimeError(f'{method} {path.split("/")[1]} HTTP {response.status_code}')
            return response.json()
        auth = call('POST', '/auth/register', {
            'email': f'workflow-{uuid.uuid4().hex}@example.invalid', 'password': secrets.token_urlsafe(24),
            'display_name': '합성 라벨 기능 점검', 'profiles': ['allergy:milk'],
        })
        client.headers['Authorization'] = 'Bearer '+auth['token']
        try:
            family = call('POST', '/family', {'name': '검증용 가족', 'profiles': ['allergy:milk'], 'language': 'en'})
            call('PUT', '/family/'+family['id'], {'name': '검증용 가족 수정', 'profiles': ['allergy:milk'], 'language': 'ko'})
            assert call('GET', '/family')['profiles'][0]['name'] == '검증용 가족 수정'
            report['family_create_edit_list'] = True
            result = call('POST', '/analyze/text', {'text': '원재료명: 쌀, 소금', 'profiles': ['allergy:milk']})
            assert result['risk']['final_level'] == 'SAFE'
            call('GET', '/analysis/'+result['request_id'])
            assert call('GET', '/history')['analyses']
            report['analysis_history_detail'] = True
            cart = call('POST', '/carts', {'name': '합성 라벨 검증 카트', 'profiles': ['allergy:milk']})
            path = '/carts/'+cart['id']
            call('POST', path+'/items', {'request_id': result['request_id'], 'name': '검증용 쌀과자', 'quantity': 1})
            updated = call('POST', path+'/items', {'request_id': result['request_id'], 'name': '이름 수정 검증', 'quantity': 2})
            assert updated['total_quantity'] == 2 and len(updated['items']) == 1
            item = updated['items'][0]['id']
            call('PUT', path+'/items/'+item+'/nutrition', {'energy_kcal': 100, 'sodium_mg': 20})
            assert call('GET', path)['nutrition']['totals']['energy_kcal'] == 200
            report['cart_name_quantity_nutrition'] = True
            product = call('POST', '/products', {'request_id': result['request_id'], 'name': '검증용 쌀과자', 'category': '검증용'})
            assert call('GET', '/products')['products'][0]['id'] == product['id']
            assert call('POST', '/alternatives', {'name': '검증용', 'profiles': ['allergy:milk']})['products']
            call('DELETE', '/products/'+product['id'])
            assert not call('GET', '/products')['products']
            report['product_save_list_alternatives_delete'] = True
            code = call('POST', path+'/pair')['code']
            device = call('POST', '/devices/redeem', {'code': code})['token']
            call('DELETE', path+'/items/'+item)
            assert call('GET', path)['total_quantity'] == 0
            call('POST', path+'/close')
            response = client.get('/api/v1/devices/session', headers={'Authorization': 'Bearer '+device})
            assert response.status_code == 400
            report['pairing_cart_close_revokes_device'] = True
            call('DELETE', '/family/'+family['id'])
            assert not call('GET', '/family')['profiles']
        finally:
            call('POST', '/auth/logout')
        assert client.get('/api/v1/history').status_code == 401
        report['logout_revokes_session'] = True
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
