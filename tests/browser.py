"""Real browser checks; start scripts/serve.mjs first. No remote services required."""
import json, pathlib, sys
from playwright.sync_api import sync_playwright
root=pathlib.Path(__file__).resolve().parent.parent
with sync_playwright() as p:
    browser=p.chromium.launch(headless=True)
    page=browser.new_page(viewport={'width':1440,'height':1100});errors=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.goto(sys.argv[1] if len(sys.argv)>1 else 'http://127.0.0.1:4186',wait_until='networkidle')
    assert page.locator('#earliest').inner_text()=='08:30:00'
    assert page.locator('.journey').count()==2
    page.locator('#delay').fill('60');page.locator('#delay').dispatch_event('change')
    assert page.locator('.journey').count()==2
    page.locator('#delay').fill('61');page.locator('#delay').dispatch_event('change')
    assert page.locator('#earliest').inner_text()=='08:40:00'
    assert page.locator('.journey').count()==1
    page.locator('[data-example="accessible.json"]').click()
    page.wait_for_function("document.querySelector('#earliest').textContent==='08:30:00'")
    assert page.locator('#access').is_checked()
    page.locator('#access').uncheck()
    assert page.locator('#earliest').inner_text()=='08:20:00'
    page.locator('[data-example="overnight.json"]').click()
    page.wait_for_function("document.querySelector('#earliest').textContent==='24:10:00'")
    page.locator('details').evaluate('e=>e.open=true')
    with page.expect_download() as download:page.locator('#export').click()
    exported=json.loads(pathlib.Path(download.value.path()).read_text(encoding='utf-8'))
    assert exported['report']['journeys'][0]['arrival']==87000
    data=json.loads((root/'examples/commute.json').read_text(encoding='utf-8'))
    data['timetable']['trips'][0]['id']='<img src=x onerror=alert(1)>'
    page.locator('#source').fill(json.dumps(data));page.locator('#apply-source').click()
    assert '<img src=x onerror=alert(1)>' in page.locator('#journeys').inner_text()
    assert page.locator('#journeys img').count()==0
    page.locator('#source').fill('{"schema_version":1,"schema_version":1}');page.locator('#apply-source').click()
    assert page.locator('#error').is_visible() and page.locator('#export').is_disabled()
    assert page.locator('.journey').count()==0
    page.reload(wait_until='networkidle')
    out=root/'artifacts';out.mkdir(exist_ok=True)
    page.screenshot(path=str(out/'desktop.png'),full_page=True)
    page.set_viewport_size({'width':390,'height':844});page.reload(wait_until='networkidle')
    assert page.evaluate('document.documentElement.scrollWidth')==390
    page.screenshot(path=str(out/'mobile.png'),full_page=True)
    assert not errors,errors
    browser.close()
    print('Browser passed: delay boundary, accessibility, midnight, exports, raw validation, markup safety, mobile.')
