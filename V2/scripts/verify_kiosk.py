"""Offline Edge checks; no web server, network calls or hardware access."""
from pathlib import Path
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[1]
url = (root / 'kiosk/index.html').as_uri()
states = ['connect', 'ready', 'preview', 'safe', 'caution', 'danger']
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path=r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe', headless=True)
    page = browser.new_page(viewport={'width': 1024, 'height': 600}, device_scale_factor=1)
    errors, requests = [], []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.on('request', lambda request: requests.append(request.url) if request.url.startswith(('http:', 'https:')) else None)
    for language in ['ko', 'en', 'ar', 'zh', 'ja']:
        for state in states:
            page.goto(f'{url}?screen={state}&lang={language}')
            page.evaluate('document.fonts.ready')
            assert page.locator('h1').inner_text().strip()
            assert 'undefined' not in page.locator('body').inner_text()
            assert page.locator('html').get_attribute('dir') == ('rtl' if language == 'ar' else 'ltr')
            issues = page.evaluate('''() => {
              const issues=[];
              for (const el of document.querySelectorAll('h1, p, button, input, select, .criteria, .label-sample')) {
                const r=el.getBoundingClientRect();
                if(r.left < -1 || r.right > innerWidth+1 || r.top < -1 || r.bottom > innerHeight+1) issues.push(el.tagName+': outside viewport');
                if(el.matches('button, input, select') && (r.height<48 || r.width<48)) issues.push(el.tagName+': touch target under 48px');
              }
              if(document.documentElement.scrollWidth > innerWidth) issues.push('horizontal overflow');
              return issues;
            }''')
            assert not issues, (language, state, issues)
            if language == 'ar' and state == 'caution':
                page.screenshot(path=str(root / 'screenshots/kiosk_rtl.png'))
    page.goto(url)
    assert page.locator('[data-go="ready"]').is_disabled()
    page.locator('#code').fill('12ab3456')
    assert page.locator('#code').input_value().isdigit()
    page.locator('#code').fill('482619')
    page.locator('[data-go="ready"]').click()
    page.locator('[data-go="preview"]').click()
    page.locator('[data-go="danger"]').click()
    assert page.locator('h1').inner_text() == '위험'
    page.locator('[data-go="preview"]').click()
    assert page.locator('.label-sample').is_visible()
    page.locator('select').select_option('ar')
    assert page.locator('html').get_attribute('dir') == 'rtl'
    assert not errors, errors
    assert not requests, requests
    browser.close()
print('PASS: 30 state/language layouts; 48px targets; pairing/preview/result navigation; RTL; no HTTP requests.')
