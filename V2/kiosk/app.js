/* Offline presentation only. No network, camera, Bluetooth or storage access. */
const params = new URLSearchParams(location.search);
let screen = params.get('screen') || 'connect';
let lang = params.get('lang') || 'ko';
let code = '';
const paths = {
 shield:'M12 3 4 6v6c0 5 8 9 8 9s8-4 8-9V6Z M8 12l3 3 5-6',
 scan:'M8 3H3v5 M16 3h5v5 M3 16v5h5 M21 16v5h-5 M7 8h10v8H7Z M9 11h6 M9 13h4',
 link:'M10 14a4 4 0 0 0 6 0l4-4a4 4 0 0 0-6-6l-2 2 M14 10a4 4 0 0 0-6 0l-4 4a4 4 0 0 0 6 6l2-2',
 safe:'M20 12a8 8 0 1 1-4-7 M8 11l4 4 9-10',
 caution:'M12 3 2 21h20Z M12 9v5 M12 17v.1',
 danger:'M8 3h8l5 5v8l-5 5H8l-5-5V8Z M12 7v6 M12 17v.1',
 ingredient:'M5 3v6a3 3 0 0 0 6 0V3 M8 3v18 M18 3v18 M18 3c-5 4-5 9 0 9',
 factory:'M3 21V10l6 3V8l6 4V3h4l2 18Z M7 17h1 M12 17h1 M17 17h1',
};
const icon = name => `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="${paths[name] || paths.scan}"/></svg>`;
const copy = {
 ko:['연결 전','연결됨','카트와 내 기준을 연결하세요','앱의 장보기에서 연결 코드를 확인해 주세요.','장보기에서 ‘카트 기기 연결’ 선택','아래 6자리 코드를 입력','연결 코드','지우기','연결','내 기준으로 확인해요','원재료명과 알레르기 표시가 잘 보이게 라벨을 놓아주세요.','적용 중인 기준','우유','밀','땅콩','할랄','비건','라벨 확인 시작','라벨을 테두리 안에 맞춰주세요','글자가 선명하게 보이면 확인을 눌러주세요.','라벨 확인','안전','주의','위험','내 기준에 해당하는 성분이 없어요','같은 제조시설 표기를 확인하세요','우유와 밀을 피해 주세요','직접 함유','같은 제조시설','미검출','우유, 밀','다음 라벨 확인','분석 결과와 함께 제품의 실제 표시사항을 확인해 주세요.','원재료명','밀가루, 전지분유, 설탕, 정제소금','우유, 밀 함유','땅콩을 사용한 제품과 같은 제조시설','앱에서 확인한 코드는 5분 동안 사용할 수 있어요.'],
 en:['Not connected','Connected','Connect your criteria','Find the connection code in Shopping in the app.','Select “Connect cart device” in Shopping','Enter the six-digit code below','Connection code','Delete','Connect','Check with your criteria','Place the ingredients and allergy label where it is easy to read.','Applied criteria','Milk','Wheat','Peanut','Halal','Vegan','Start label check','Align the label inside the frame','When the text is clear, tap Check label.','Check label','Safe','Caution','Danger','No matching ingredients detected','Check the shared-facility notice','Avoid milk and wheat','Direct ingredients','Shared facility','Not detected','Milk, wheat','Check next label','Check the actual package label alongside these results.','Ingredients','Wheat flour, whole milk powder, sugar, salt','Contains milk and wheat','Made in a facility that also uses peanuts','The code from the app is valid for five minutes.'],
 ar:['غير متصل','متصل','اربط معاييرك بالعربة','ستجد رمز الربط في قسم التسوق في التطبيق.','اختر ربط العربة من التسوق','أدخل الرمز المكون من ستة أرقام','رمز الربط','حذف','ربط','تحقق وفق معاييرك','ضع ملصق المكونات والحساسية بشكل واضح.','المعايير المطبقة','حليب','قمح','فول سوداني','حلال','نباتي','ابدأ فحص الملصق','ضع الملصق داخل الإطار','عندما يظهر النص بوضوح اضغط على الفحص.','فحص الملصق','آمن','تنبيه','خطر','لم تُكتشف مكونات توافق معاييرك','تحقق من تنبيه المنشأة المشتركة','تجنب الحليب والقمح','مكونات مباشرة','منشأة مشتركة','لم يُكتشف','حليب، قمح','فحص الملصق التالي','تحقق من ملصق العبوة الفعلي مع هذه النتائج.','المكونات','دقيق قمح، مسحوق حليب، سكر، ملح','يحتوي على حليب وقمح','مصنع يستخدم الفول السوداني أيضاً','الرمز صالح لمدة خمس دقائق.'],
 zh:['未连接','已连接','连接您的饮食标准','请在应用的购物页面查看连接码。','在购物页面选择连接购物车','输入下方六位连接码','连接码','删除','连接','按您的标准检查','请将配料和过敏原标签清晰地放在镜头前。','已应用的标准','牛奶','小麦','花生','清真','纯素','开始检查标签','将标签对准框内','文字清晰后，请点击检查。','检查标签','安全','注意','危险','未检出符合您标准的成分','请检查共用生产设施说明','请避开牛奶和小麦','直接含有','共用生产设施','未检出','牛奶、小麦','检查下一个标签','请同时查看产品包装上的实际标识。','配料','小麦粉、全脂奶粉、糖、盐','含牛奶、小麦','与使用花生的产品共用生产设施','连接码五分钟内有效。'],
 ja:['未接続','接続済み','カートに基準を接続','アプリの買い物画面で接続コードを確認してください。','買い物画面でカート接続を選択','下の6桁のコードを入力','接続コード','削除','接続','自分の基準で確認','原材料とアレルギー表示を読みやすく置いてください。','適用中の基準','乳','小麦','落花生','ハラール','ヴィーガン','ラベルの確認を開始','ラベルを枠内に合わせてください','文字が鮮明になったら確認を押してください。','ラベルを確認','安全','注意','危険','基準に該当する成分は未検出','同じ製造施設の表示を確認','乳と小麦を避けてください','直接含有','同じ製造施設','未検出','乳、小麦','次のラベルを確認','結果と併せて製品の実際の表示を確認してください。','原材料名','小麦粉、全粉乳、砂糖、塩','乳・小麦を含む','落花生を使用する製品と同じ製造施設','コードは5分間有効です。'],
};
if (!copy[lang]) lang = 'ko';
if (!['connect','ready','preview','safe','caution','danger'].includes(screen)) screen = 'connect';
const t = n => copy[lang][n];
function go(next) { screen = next; render(); }
function render() {
 document.documentElement.lang = lang; document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
 let body, footer;
 if (screen === 'connect') {
  body = `<section class="content"><div class="intro"><div class="symbol">${icon('link')}</div><h1>${t(2)}</h1><p>${t(3)}</p><div class="steps"><div class="step"><span>1</span>${t(4)}</div><div class="step"><span>2</span>${t(5)}</div></div></div><div class="code-panel"><label for="code">${t(6)}</label><input id="code" type="text" inputmode="numeric" autocomplete="off" maxlength="6" aria-label="${t(6)}" value="${code}" placeholder="------"><div class="keypad">${[1,2,3,4,5,6,7,8,9].map(n=>`<button data-digit="${n}">${n}</button>`).join('')}<button class="erase" data-delete>${t(7)}</button><button data-digit="0">0</button><button class="primary" data-go="ready" ${code.length===6?'':'disabled'}>${t(8)}</button></div></div></section>`;
  footer = `<p>${t(37)}</p>`;
 } else if (screen === 'ready') {
  body = `<section class="content"><div class="intro"><p class="section-label">${t(11)}</p><div class="criteria">${[12,13,14,15,16].map(n=>`<span class="chip">${t(n)}</span>`).join('')}</div><h1>${t(9)}</h1><p>${t(10)}</p></div><div class="capture-art"><div class="frame">${icon('scan')}</div></div></section>`;
  footer = `<p>${t(32)}</p><button class="primary" data-go="preview">${t(17)}</button>`;
 } else if (screen === 'preview') {
  body = `<section class="content"><div class="preview-area"><div class="frame"><div class="label-sample"><strong>${t(33)}</strong>${t(34)}<br><b>${t(35)}</b><br>${t(36)}</div></div></div><div class="preview-copy"><h1>${t(18)}</h1><p>${t(19)}</p></div></section>`;
  footer = `<button class="secondary" data-go="ready">${lang==='ko'?'이전':lang==='ar'?'رجوع':lang==='zh'?'返回':lang==='ja'?'戻る':'Back'}</button><button class="primary" data-go="danger">${t(20)}</button>`;
 } else {
  const n = {safe:0,caution:1,danger:2}[screen];
  body = `<section class="content status-content ${screen}"><div class="verdict"><div class="status-symbol">${icon(screen)}</div><h1>${t(21+n)}</h1><p>${t(24+n)}</p></div><div class="evidence"><div class="evidence-row">${icon('ingredient')}<div><p>${t(27)}</p><strong>${t(screen==='danger'?30:29)}</strong></div></div><div class="evidence-row">${icon('factory')}<div><p>${t(28)}</p><strong>${t(screen==='safe'?29:14)}</strong></div></div></div></section>`;
  footer = `<p>${t(32)}</p><button class="primary" data-go="preview">${t(31)}</button>`;
 }
 document.getElementById('app').innerHTML = `<header><div class="brand">${icon('shield')}Safe-Byte</div><div class="header-end"><span class="connection">${icon('link')}${t(screen==='connect'?0:1)}</span><select aria-label="Language">${Object.entries({ko:'한국어',en:'English',ar:'العربية',zh:'中文',ja:'日本語'}).map(([key,value])=>`<option value="${key}" ${key===lang?'selected':''}>${value}</option>`).join('')}</select></div></header>${body}<footer>${footer}</footer>`;
 document.querySelector('select').onchange = e => {lang=e.target.value;render();};
 document.querySelectorAll('[data-go]').forEach(b => b.onclick = () => go(b.dataset.go));
 document.querySelectorAll('[data-digit]').forEach(b => b.onclick = () => {code=(code+b.dataset.digit).slice(0,6);render();});
 const del=document.querySelector('[data-delete]'); if(del) del.onclick=()=>{code=code.slice(0,-1);render();};
 const field=document.getElementById('code'); if(field) field.oninput=e=>{code=e.target.value.replace(/\D/g,'').slice(0,6);field.value=code;document.querySelector('[data-go="ready"]').disabled=code.length!==6;};
}
render();
