const state = {
  mode: "live",
  samples: [],
  selectedSample: null,
  selectedFile: null,
  category: "all",
  isAnalyzing: false,
  guideIndex: 0,
  guideTarget: null,
};

const params = new URLSearchParams(window.location.search);
const queryApiBase = params.get("api");
if (queryApiBase) {
  localStorage.setItem("safeByteApiBaseUrl", queryApiBase);
}

const API_BASE_URL = normalizeApiBase(
  window.SAFE_BYTE_API_BASE_URL || queryApiBase || localStorage.getItem("safeByteApiBaseUrl") || ""
);

let authToken = sessionStorage.getItem(`safeByteToken:${API_BASE_URL}`) || '';
const authPanel = document.createElement('form');
authPanel.className = 'panel';
authPanel.style.padding = '16px';
authPanel.innerHTML = `<strong>계정 / Account</strong>
  <label>이메일 <input name="email" type="email" autocomplete="username" required></label>
  <label>비밀번호 <input name="password" type="password" autocomplete="current-password" minlength="8" required></label>
  <button type="submit" name="action" value="login">로그인</button>
  <button type="submit" name="action" value="register">회원가입</button>
  <button type="button" id="accountLogout">로그아웃</button>
  <p role="status" id="accountStatus"></p>`;
document.querySelector('.mast').after(authPanel);
const authStatus = authPanel.querySelector('#accountStatus');
authStatus.textContent = authToken ? '로그인 세션이 있습니다.' : '분석 전에 로그인하세요.';
authPanel.addEventListener('submit', async event => {
  event.preventDefault();
  const action = event.submitter?.value || 'login';
  const input = new FormData(authPanel);
  try {
    const response = await fetch(apiUrl(`/api/v1/auth/${action}`), {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({email: input.get('email'), password: input.get('password'), display_name: '웹 사용자', profiles: ['halal', 'vegan', 'allergy']}),
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '로그인 실패');
    authToken = data.token;
    sessionStorage.setItem(`safeByteToken:${API_BASE_URL}`, authToken);
    authPanel.elements.password.value = '';
    authStatus.textContent = '로그인했습니다.';
  } catch (error) { authStatus.textContent = error.message; }
});
authPanel.querySelector('#accountLogout').addEventListener('click', async () => {
  try {
    const response = await fetch(apiUrl('/api/v1/auth/logout'), {method:'POST', headers:{Authorization:`Bearer ${authToken}`}});
    if (!response.ok && response.status !== 401) throw new Error('로그아웃 실패');
    authToken = ''; sessionStorage.removeItem(`safeByteToken:${API_BASE_URL}`);
    authStatus.textContent = '로그아웃했습니다.';
  } catch (error) { authStatus.textContent = error.message; }
});

const el = {
  systemStrip: document.querySelector("#systemStrip"),
  systemText: document.querySelector("#systemText"),
  fileInput: document.querySelector("#fileInput"),
  fileName: document.querySelector("#fileName"),
  dropzone: document.querySelector("#dropzone"),
  preview: document.querySelector("#preview"),
  previewFrame: document.querySelector(".preview-frame"),
  previewEmpty: document.querySelector("#previewEmpty"),
  sampleCount: document.querySelector("#sampleCount"),
  guideButton: document.querySelector("#guideButton"),
  mockMode: document.querySelector("#mockMode"),
  liveMode: document.querySelector("#liveMode"),
  modeStatus: document.querySelector("#modeStatus"),
  mockBlock: document.querySelector("#mockBlock"),
  mockText: document.querySelector("#mockText"),
  forceOcr: document.querySelector("#forceOcr"),
  analyzeButton: document.querySelector("#analyzeButton"),
  verdict: document.querySelector("#verdict"),
  verdictLevel: document.querySelector("#verdictLevel"),
  verdictSummary: document.querySelector("#verdictSummary"),
  requestId: document.querySelector("#requestId"),
  ocrProvider: document.querySelector("#ocrProvider"),
  cacheState: document.querySelector("#cacheState"),
  paidState: document.querySelector("#paidState"),
  imageSize: document.querySelector("#imageSize"),
  ncloudCost: document.querySelector("#ncloudCost"),
  ncloudCostMeta: document.querySelector("#ncloudCostMeta"),
  serverCost: document.querySelector("#serverCost"),
  serverCostMeta: document.querySelector("#serverCostMeta"),
  ocrCost: document.querySelector("#ocrCost"),
  ocrCostMeta: document.querySelector("#ocrCostMeta"),
  cacheBackend: document.querySelector("#cacheBackend"),
  cacheMeta: document.querySelector("#cacheMeta"),
  detections: document.querySelector("#detections"),
  ocrText: document.querySelector("#ocrText"),
  sampleGrid: document.querySelector("#sampleGrid"),
  busyOverlay: document.querySelector("#busyOverlay"),
  busyTitle: document.querySelector("#busyTitle"),
  busyMessage: document.querySelector("#busyMessage"),
  guideBackdrop: document.querySelector("#guideBackdrop"),
  guidePopover: document.querySelector("#guidePopover"),
  guideStep: document.querySelector("#guideStep"),
  guideTitle: document.querySelector("#guideTitle"),
  guideBody: document.querySelector("#guideBody"),
  guideSkip: document.querySelector("#guideSkip"),
  guidePrev: document.querySelector("#guidePrev"),
  guideNext: document.querySelector("#guideNext"),
};

const guideSteps = [
  {
    target: '[data-guide="input"]',
    title: "라벨 이미지 입력",
    body: "한국어 식품 라벨 이미지를 업로드하거나 끌어다 놓습니다. 샘플을 고르면 자동으로 미리보기에 반영됩니다.",
  },
  {
    target: '[data-guide="samples"]',
    title: "선별 샘플",
    body: "테스트용 과자와 면류 이미지를 바로 선택할 수 있습니다. 실제 사진이 급하지 않을 때 반복 검증용으로 씁니다.",
  },
  {
    target: '[data-guide="profiles"]',
    title: "판정 프로필",
    body: "할랄, 비건, 알레르기 기준을 켜고 끌 수 있습니다. 선택된 기준만 위험 성분 판정에 반영됩니다.",
  },
  {
    target: '[data-guide="mode"]',
    title: "OCR 모드",
    body: "CLOVA는 실제 사진을 네이버 OCR로 읽고, Mock은 비용 없이 문구만 테스트합니다. 외부 테스트는 기본적으로 CLOVA 모드입니다.",
  },
  {
    target: '[data-guide="analyze"]',
    title: "분석 실행",
    body: "이 버튼을 누르면 이미지 OCR, OCR 보정, 위험 성분 매칭이 순서대로 실행됩니다. 진행 중에는 화면이 잠겨 중복 호출을 막습니다.",
  },
  {
    target: '[data-guide="result"]',
    title: "최종 판정",
    body: "SAFE, CAUTION, DANGER로 결과가 요약됩니다. 위험 성분이 있으면 아래 목록에 감지 사유와 매칭 키워드가 표시됩니다.",
  },
  {
    target: '[data-guide="cost"]',
    title: "비용과 캐시",
    body: "Ncloud 청구 스냅샷, 서버 사양, OCR 추정 비용, Redis 캐시 상태를 한 번에 확인합니다. 캐시는 같은 OCR 반복 호출을 줄이는 용도입니다.",
  },
];

function normalizeApiBase(value) {
  return String(value || "").trim().replace(/\/+$/, "");
}

function apiUrl(path) {
  if (/^https?:\/\//i.test(path)) return path;
  return `${API_BASE_URL}${path.startsWith("/") ? path : `/${path}`}`;
}

function assetUrl(path) {
  if (!path || /^(https?:|blob:|data:)/i.test(path)) return path;
  return apiUrl(path);
}

function formatKrw(value) {
  return `₩${new Intl.NumberFormat("ko-KR").format(Number(value || 0))}`;
}

function setSystem(text, status = "ok") {
  const dot = el.systemStrip.querySelector(".dot");
  dot.className = `dot ${status}`;
  el.systemText.textContent = text;
}

function toast(message) {
  const node = document.createElement("div");
  node.className = "toast";
  node.textContent = message;
  document.body.appendChild(node);
  setTimeout(() => node.remove(), 3200);
}

function setInteractiveDisabled(isDisabled) {
  const controls = [
    el.fileInput,
    el.mockMode,
    el.liveMode,
    el.mockText,
    el.forceOcr,
    el.analyzeButton,
    ...document.querySelectorAll("input[name='profile'], .tab, .sample"),
  ];
  controls.forEach((control) => {
    if (control) control.disabled = isDisabled;
  });
}

function clearGuideHighlight() {
  if (state.guideTarget) {
    state.guideTarget.classList.remove("guide-highlight");
    state.guideTarget = null;
  }
}

function placeGuidePopover(target) {
  const targetRect = target.getBoundingClientRect();
  const popoverRect = el.guidePopover.getBoundingClientRect();
  const gap = 14;
  const margin = 14;
  const viewportWidth = window.innerWidth;
  const viewportHeight = window.innerHeight;

  let left = Math.min(
    Math.max(targetRect.left, margin),
    viewportWidth - popoverRect.width - margin
  );
  let top = targetRect.bottom + gap;

  if (top + popoverRect.height > viewportHeight - margin) {
    top = targetRect.top - popoverRect.height - gap;
  }
  if (top < margin) {
    top = Math.max(margin, viewportHeight - popoverRect.height - margin);
  }

  el.guidePopover.style.left = `${left}px`;
  el.guidePopover.style.top = `${top}px`;
}

function renderGuideStep() {
  clearGuideHighlight();
  const step = guideSteps[state.guideIndex];
  const target = document.querySelector(step.target);
  if (!target) {
    closeGuide();
    return;
  }

  state.guideTarget = target;
  target.classList.add("guide-highlight");
  target.scrollIntoView({ block: "center", inline: "nearest" });

  el.guideStep.textContent = `${state.guideIndex + 1} / ${guideSteps.length}`;
  el.guideTitle.textContent = step.title;
  el.guideBody.textContent = step.body;
  el.guidePrev.disabled = state.guideIndex === 0;
  el.guideNext.textContent = state.guideIndex === guideSteps.length - 1 ? "완료" : "다음";

  window.requestAnimationFrame(() => placeGuidePopover(target));
}

function openGuide(startIndex = 0) {
  if (state.isAnalyzing) return;
  state.guideIndex = startIndex;
  document.body.classList.add("guide-open");
  el.guideBackdrop.hidden = false;
  el.guidePopover.hidden = false;
  renderGuideStep();
}

function closeGuide() {
  clearGuideHighlight();
  document.body.classList.remove("guide-open");
  el.guideBackdrop.hidden = true;
  el.guidePopover.hidden = true;
}

function moveGuide(delta) {
  const nextIndex = state.guideIndex + delta;
  if (nextIndex < 0) return;
  if (nextIndex >= guideSteps.length) {
    localStorage.setItem("safeByteGuideSeen", "true");
    closeGuide();
    return;
  }
  state.guideIndex = nextIndex;
  renderGuideStep();
}

function maybeOpenGuideOnce() {
  if (localStorage.getItem("safeByteGuideSeen") === "true") return;
  localStorage.setItem("safeByteGuideSeen", "true");
  window.setTimeout(() => openGuide(), 450);
}

function setMode(mode) {
  state.mode = mode;
  el.mockMode.classList.toggle("active", mode === "mock");
  el.liveMode.classList.toggle("active", mode === "live");
  el.mockText.disabled = mode === "live";
  el.mockBlock.hidden = mode !== "mock";
  el.modeStatus.className = `mode-status ${mode === "mock" ? "mock" : "live"}`;
  el.modeStatus.textContent = mode === "mock"
    ? "Mock 테스트 모드입니다. 아래 문구만 분석하며 CLOVA OCR 비용은 발생하지 않습니다."
    : "CLOVA 실제 OCR 모드입니다. 업로드한 사진만 분석하며 Mock 문구는 전송하지 않습니다.";
}

function selectedProfiles() {
  return Array.from(document.querySelectorAll("input[name='profile']:checked"))
    .map((item) => item.value)
    .join(",");
}

function setPreview(src, label) {
  el.preview.src = src;
  el.previewFrame.classList.add("has-image");
  el.fileName.textContent = label;
}

async function loadHealth() {
  const health = await fetch(apiUrl("/health/ocr")).then((res) => res.json());
  const live = health.paid_ocr_enabled ? "CLOVA live" : "CLOVA locked";
  const usage = `${health.usage_today}/${health.daily_limit}`;
  const target = API_BASE_URL ? ` · ${API_BASE_URL}` : "";
  setSystem(`${live} · ${usage}${target}`, health.paid_ocr_enabled ? "warn" : "ok");
  if (!health.paid_ocr_enabled && state.mode === "live") {
    setMode("mock");
  }
  return health;
}

async function loadCosts() {
  const costs = await fetch(apiUrl("/api/v1/costs")).then((res) => res.json());
  renderCosts(costs);
}

function renderCosts(costs) {
  const ncloud = costs.ncloud || {};
  const server = costs.server || {};
  const ocr = costs.ocr || {};
  const cache = costs.cache || {};
  const month = ncloud.month || "-";
  const snapshot = ncloud.source === "ncloud_billing_api" ? "Billing API" : "estimate";

  el.ncloudCost.textContent = formatKrw(ncloud.current_month_amount_including_vat_krw);
  el.ncloudCostMeta.textContent = `${month} · ${snapshot} · VAT 포함`;
  el.serverCost.textContent = server.spec_code || "-";
  el.serverCostMeta.textContent = `${server.fee_system_type_code || "-"} · 추가 Redis 비용 ${formatKrw(server.extra_managed_cache_cost_krw)}`;
  el.ocrCost.textContent = formatKrw(ocr.estimated_month_cost_krw);
  el.ocrCostMeta.textContent = `${ocr.usage_month || 0}/${ocr.free_quota_monthly || 0} free · live ${ocr.paid_ocr_enabled ? "on" : "locked"}`;
  el.cacheBackend.textContent = cache.connected ? "Redis" : "SQLite";
  el.cacheMeta.textContent = `${cache.backend || "-"} · OCR cache ${cache.sqlite_ocr_results || 0}`;
}

async function loadSamples() {
  const payload = await fetch(apiUrl("/api/v1/samples")).then((res) => res.json());
  state.samples = payload.samples || [];
  el.sampleCount.textContent = `${state.samples.length} samples`;
  renderSamples();
}

function renderSamples() {
  const samples = state.samples.filter((sample) => {
    return state.category === "all" || sample.category === state.category;
  });
  el.sampleGrid.innerHTML = "";
  samples.forEach((sample) => {
    const button = document.createElement("button");
    button.className = "sample";
    button.type = "button";
    if (state.selectedSample && state.selectedSample.url === sample.url) {
      button.classList.add("active");
    }
    button.innerHTML = `
      <img src="${assetUrl(sample.url)}" alt="${sample.product}">
      <strong title="${sample.product}">${sample.product}</strong>
      <span>${sample.category}</span>
    `;
    button.addEventListener("click", () => selectSample(sample));
    el.sampleGrid.appendChild(button);
  });
}

async function selectSample(sample) {
  state.selectedSample = sample;
  state.selectedFile = null;
  setPreview(assetUrl(sample.url), sample.filename);
  renderSamples();
}

el.fileInput.addEventListener("change", () => {
  const file = el.fileInput.files?.[0];
  if (!file) return;
  state.selectedFile = file;
  state.selectedSample = null;
  setPreview(URL.createObjectURL(file), file.name);
  renderSamples();
});

["dragenter", "dragover"].forEach((eventName) => {
  el.dropzone.addEventListener(eventName, (event) => {
    event.preventDefault();
    el.dropzone.classList.add("active");
  });
});

["dragleave", "drop"].forEach((eventName) => {
  el.dropzone.addEventListener(eventName, (event) => {
    event.preventDefault();
    el.dropzone.classList.remove("active");
  });
});

el.dropzone.addEventListener("drop", (event) => {
  const file = event.dataTransfer.files?.[0];
  if (!file) return;
  state.selectedFile = file;
  state.selectedSample = null;
  setPreview(URL.createObjectURL(file), file.name);
  renderSamples();
});

el.mockMode.addEventListener("click", () => setMode("mock"));
el.liveMode.addEventListener("click", () => setMode("live"));

document.querySelectorAll(".tab").forEach((tab) => {
  tab.addEventListener("click", () => {
    state.category = tab.dataset.category;
    document.querySelectorAll(".tab").forEach((item) => item.classList.remove("active"));
    tab.classList.add("active");
    renderSamples();
  });
});

el.guideButton.addEventListener("click", () => openGuide());
el.guideSkip.addEventListener("click", closeGuide);
el.guideBackdrop.addEventListener("click", closeGuide);
el.guidePrev.addEventListener("click", () => moveGuide(-1));
el.guideNext.addEventListener("click", () => moveGuide(1));

window.addEventListener("keydown", (event) => {
  if (el.guidePopover.hidden) return;
  if (event.key === "Escape") {
    closeGuide();
  } else if (event.key === "ArrowRight") {
    moveGuide(1);
  } else if (event.key === "ArrowLeft") {
    moveGuide(-1);
  }
});

window.addEventListener("resize", () => {
  if (!el.guidePopover.hidden && state.guideTarget) {
    placeGuidePopover(state.guideTarget);
  }
});

async function fileFromCurrentSelection() {
  if (state.selectedFile) return state.selectedFile;
  if (!state.selectedSample) return null;
  const response = await fetch(assetUrl(state.selectedSample.url));
  const blob = await response.blob();
  return new File([blob], state.selectedSample.filename, { type: blob.type || "image/jpeg" });
}

function setLoading(isLoading) {
  state.isAnalyzing = isLoading;
  setInteractiveDisabled(isLoading);
  el.busyOverlay.classList.toggle("active", isLoading);
  el.busyOverlay.setAttribute("aria-hidden", isLoading ? "false" : "true");
  el.analyzeButton.disabled = isLoading;
  el.analyzeButton.classList.toggle("is-loading", isLoading);
  el.analyzeButton.innerHTML = isLoading
    ? '<span class="button-spinner" aria-hidden="true"></span>분석 중'
    : '<span class="button-mark">OCR</span>분석 실행';
  if (!isLoading) {
    setMode(state.mode);
  }
}

function renderResult(payload) {
  const level = payload.risk?.final_level || "SAFE";
  el.verdict.className = `verdict ${level.toLowerCase()}`;
  el.verdictLevel.textContent = level;
  el.verdictSummary.textContent = payload.risk?.summary || "-";
  el.requestId.textContent = payload.request_id ? payload.request_id.slice(0, 8) : "-";
  el.ocrProvider.textContent = payload.ocr?.provider || "-";
  el.cacheState.textContent = payload.ocr?.cached
    ? `hit${payload.ocr?.cache_backend ? `/${payload.ocr.cache_backend}` : ""}`
    : "miss";
  el.paidState.textContent = payload.ocr?.called_paid_api ? "yes" : "no";
  el.imageSize.textContent = payload.image ? `${payload.image.width}x${payload.image.height}` : "-";
  const rawText = payload.ocr?.text || "";
  const correctedText = payload.ocr?.corrected_text || rawText;
  el.ocrText.textContent = correctedText !== rawText
    ? `${correctedText}\n\n--- OCR original ---\n${rawText}`
    : rawText;

  const detections = payload.risk?.detections || [];
  el.detections.innerHTML = "";
  if (!detections.length) {
    el.detections.innerHTML = '<div class="detection"><strong>감지 없음</strong><span>선택한 프로필 기준</span></div>';
    return;
  }

  const directDetections = detections.filter((item) => item.occurrence_type !== "cross_contact");
  const crossContactDetections = detections.filter((item) => item.occurrence_type === "cross_contact");

  if (directDetections.length) {
    appendDetectionSection(
      "직접 함유/함유 문구",
      "원재료명, 함유 표시, 성분명 주변에서 직접 확인된 항목입니다."
    );
    directDetections.forEach(appendDetectionCard);
  }

  if (crossContactDetections.length) {
    appendDetectionSection(
      "제조시설 공유 표기",
      "라벨의 '같은 제조시설에서 제조' 문구입니다. 직접 원재료 함유로 보지 않고 참고 주의로만 분리합니다."
    );
    crossContactDetections.forEach(appendDetectionCard);
  }
}

function appendDetectionSection(title, description) {
  const section = document.createElement("div");
  section.className = "detection-section-title";
  section.innerHTML = `<strong>${title}</strong><span>${description}</span>`;
  el.detections.appendChild(section);
}

function appendDetectionCard(item) {
    const node = document.createElement("article");
    node.className = `detection ${item.severity} ${item.occurrence_type || "unknown"}`;
    const occurrenceLabel = item.occurrence_label || "문맥 확인";
    const occurrenceNote = item.occurrence_type === "cross_contact" ? "직접 함유 아님" : occurrenceLabel;
    node.innerHTML = `
      <strong>${item.canonical_name}</strong>
      <span>${item.category} · ${item.severity} · ${occurrenceNote} · ${item.matched_keyword}</span>
      <p>${item.reason}</p>
    `;
    el.detections.appendChild(node);
}

async function analyze() {
  if (state.isAnalyzing) return;
  if (!state.selectedFile && !state.selectedSample) {
    toast("이미지를 선택하세요.");
    return;
  }
  if (state.mode === "live" && !window.confirm("실제 CLOVA OCR을 호출합니다. 계속할까요?")) {
    return;
  }

  setLoading(true);

  try {
    const file = await fileFromCurrentSelection();
    if (!file) {
      throw new Error("이미지를 선택하세요.");
    }

    const form = new FormData();
    form.append("file", file);
    form.append("profiles", selectedProfiles());
    form.append("ocr_mode", state.mode);
    form.append("force_ocr", el.forceOcr.checked ? "true" : "false");
    if (state.mode === "mock") {
      form.append("mock_text", el.mockText.value);
    }

    if (!authToken) throw new Error('먼저 로그인하세요.');
    const response = await fetch(apiUrl("/api/v1/analyze/image"), { method: "POST", body: form, headers: {Authorization: `Bearer ${authToken}`} });
    const payload = await response.json();
    if (!response.ok) {
      throw new Error(payload.detail?.message || payload.detail || "분석 실패");
    }
    renderResult(payload);
    await Promise.all([loadHealth(), loadCosts()]);
  } catch (error) {
    toast(String(error.message || error));
  } finally {
    setLoading(false);
  }
}

el.analyzeButton.addEventListener("click", analyze);

async function boot() {
  try {
    await Promise.all([loadHealth(), loadCosts(), loadSamples()]);
    maybeOpenGuideOnce();
  } catch (error) {
    setSystem("서버 연결 실패", "warn");
    toast(String(error.message || error));
  }
}

setMode(state.mode);
boot();
