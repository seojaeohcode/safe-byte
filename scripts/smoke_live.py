"""Opt-in deployed CLOVA integration check; one synthetic label + cached repeat."""
import argparse
import io
import json
import secrets
import time
import uuid
import httpx
from PIL import Image, ImageDraw, ImageFont


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--api',default='http://127.0.0.1:8080')
    p.add_argument('--live',action='store_true',help='Allow the one live OCR call within the configured server quota')
    args=p.parse_args()
    if not args.live:
        raise SystemExit('Pass --live to run the explicit paid OCR check')
    image=Image.new('RGB',(1200,600),'white')
    draw=ImageDraw.Draw(image)
    font=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',42)
    draw.multiline_text((50,60),'원재료명: 우유, 밀가루, 설탕\n알레르기 유발물질: 우유, 밀 함유\n영양정보 총 내용량 100g\n열량 350kcal 나트륨 120mg',font=font,fill='black',spacing=30)
    buffer=io.BytesIO(); image.save(buffer,format='JPEG',quality=92)
    with httpx.Client(base_url=args.api,timeout=120) as client:
        health=client.get('/health'); health.raise_for_status()
        auth=client.post('/api/v1/auth/register',json={'email':f'smoke-{uuid.uuid4().hex}@example.invalid','password':secrets.token_urlsafe(24),'display_name':'Integration check','profiles':['allergy:milk']})
        auth.raise_for_status(); token=auth.json()['token']; client.headers['Authorization']='Bearer '+token
        report={'synthetic_label':True,'health':health.status_code,'ocr':[]}
        try:
            for _ in range(2):
                start=time.monotonic()
                r=client.post('/api/v1/analyze/image',files={'file':('integration-label.jpg',buffer.getvalue(),'image/jpeg')},data={'profiles':'allergy:milk','language':'en'})
                if r.status_code!=200:
                    raise RuntimeError(f'Analysis HTTP {r.status_code}: {r.text[:300]}')
                result=r.json()
                assert result['ocr']['provider']=='clova'
                assert result['risk']['final_level']=='DANGER'
                assert result['ocr']['regions']
                report['ocr'].append({'cached':result['ocr']['cached'],'called_paid_api':result['ocr']['called_paid_api'],'regions':len(result['ocr']['regions']),'risk':result['risk']['final_level'],'seconds':round(time.monotonic()-start,2)})
            assert report['ocr'][1]['cached'] and not report['ocr'][1]['called_paid_api']
            cart=client.post('/api/v1/carts',json={'name':'Integration cart','profiles':['allergy:milk']}).json()['id']
            r=client.post(f'/api/v1/carts/{cart}/items',json={'name':'Synthetic label','request_id':result['request_id'],'quantity':2}); r.raise_for_status()
            assert r.json()['counts']['DANGER']==2
            code=client.post(f'/api/v1/carts/{cart}/pair').json()['code']
            device=client.post('/api/v1/devices/redeem',json={'code':code}).json()['token']
            client.post(f'/api/v1/carts/{cart}/close').raise_for_status()
            assert client.get('/api/v1/devices/session',headers={'Authorization':'Bearer '+device}).status_code==400
            report['cart_close_revokes_device']=True
        finally:
            client.post('/api/v1/auth/logout').raise_for_status()
        assert client.get('/api/v1/history').status_code==401
        report['logout_revokes_session']=True
        print(json.dumps(report,ensure_ascii=True,indent=2))


if __name__=='__main__':
    main()
