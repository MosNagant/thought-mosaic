export const ENTRY_PLANS = {
  a1: { code: 'A1', title: '截图后记录', intro: '浏览内容 → 截图 → 记录灵感', hint: '点击“模拟截图”，再点缩略图下的“记录灵感”。截图会自动带入记录页。', system: '这里演示 Figma 中的截图快捷区。iPhone 实际使用“截图 → 分享 → Thought Mosaic”，系统截图浮窗不会被修改。' },
  a2: { code: 'A2', title: '拍照快捷组件', intro: '桌面组件 → 拍照 → 记录灵感', hint: '点击桌面上的“拍照记录”组件，再拍下示例画面；也可以切换到真实摄像头。', system: '这里的桌面是原型场景。iOS 版另有真实 WidgetKit 桌面组件；浏览器不能替系统安装小组件。' },
  b: { code: 'B', title: '三指上滑', intro: '正在使用手机 → 三指上滑 → 空白记录', hint: '在灰色画面上三指向上滑动。电脑可用鼠标向上拖动，或点击“模拟三指上滑”。', system: '手势只在此演示区域生效，不会监听其他 App。iPhone 可将“记录灵感”快捷指令绑定到“轻点背面”或操作按钮。' },
  c: { code: 'C', title: '直接打开 App', intro: '手机桌面 → App 图标 → 空白记录', hint: '点击 Thought Mosaic 图标，直接进入新的记录页。', system: '这里演示点击桌面图标。iOS 版冷启动会直接进入记录页，有草稿时恢复草稿。' },
};
export const ENTRY_ORDER = Object.keys(ENTRY_PLANS);
export function isUpwardSwipe(starts, ends, duration, requiredCount = 3) {
  return starts.length === requiredCount && ends.length === requiredCount && duration >= 0 && duration <= 1400 && starts.every((start, i) => start.y - ends[i].y >= 55 && Math.abs(start.x - ends[i].x) < 90);
}
export function bindEntryGesture(element, activate) {
  if (!element) return;
  let touches = null, mouse = null, finished = false;
  const trigger = () => { if (!finished) { finished = true; activate(); } };
  element.addEventListener('touchstart', e => {
    if (e.touches.length === 3) { e.preventDefault(); touches = { time: performance.now(), points: Array.from(e.touches, t => ({ id: t.identifier, x: t.clientX, y: t.clientY })) }; }
    else if (e.touches.length > 3) touches = null;
  }, { passive: false });
  element.addEventListener('touchmove', e => {
    if (!touches || e.touches.length !== 3) return;
    e.preventDefault();
    const ends = touches.points.map(p => Array.from(e.touches).find(t => t.identifier === p.id)).filter(Boolean).map(t => ({ x: t.clientX, y: t.clientY }));
    if (isUpwardSwipe(touches.points, ends, performance.now() - touches.time)) trigger();
  }, { passive: false });
  element.addEventListener('touchend', () => { touches = null; });
  element.addEventListener('touchcancel', () => { touches = null; });
  element.addEventListener('pointerdown', e => { if (e.pointerType === 'mouse' && e.button === 0) { mouse = { x: e.clientX, y: e.clientY, time: performance.now() }; element.setPointerCapture(e.pointerId); } });
  element.addEventListener('pointerup', e => { if (mouse && isUpwardSwipe([mouse], [{ x: e.clientX, y: e.clientY }], performance.now() - mouse.time, 1)) trigger(); mouse = null; });
  element.addEventListener('pointercancel', () => { mouse = null; });
}
const sceneIcons = `<div class="scene-app-row"><button class="scene-app" data-entry="direct" aria-label="打开 Thought Mosaic App"><span class="scene-app-icon">TM</span><span>Thought Mosaic</span></button><div class="scene-app other"><span class="scene-app-icon"></span><span>其他 App</span></div><div class="scene-app other"><span class="scene-app-icon"></span><span>其他 App</span></div></div>`;
const browsing = `<div class="scene-search">⌕ <span>正在浏览内容</span></div><div class="scene-gray hero"></div><div class="scene-columns"><div></div><div></div></div><p class="scene-caption">用户在这里看到想保存的灵感内容。</p>`;
export function entriesMarkup(planKey, step, screenshotURL = '') {
  const plan = ENTRY_PLANS[planKey];
  let scene = '';
  if (planKey === 'a1') scene = `${browsing}${step === 'captured' ? `<div class="scene-shot"><img src="${screenshotURL}" alt="刚刚截取的原型画面"><button class="btn primary" data-entry="capture-screenshot">记录灵感</button></div>` : '<button class="btn primary scene-trigger" data-entry="take-screenshot">模拟截图</button>'}`;
  if (planKey === 'a2') scene = step === 'camera' ? `<div class="scene-camera"><div class="scene-camera-heading">拍照 <span>演示素材</span></div><div class="scene-viewfinder"><div class="sample-art"><i></i><i></i><i></i></div></div><p>画面已就绪，把这一刻留下。</p><button class="btn primary" data-entry="sample-photo">拍下示例画面</button><button class="btn" data-entry="real-camera">使用真实摄像头</button><button class="btn ghost" data-entry="restart">返回桌面</button></div>` : `<p class="scene-caption">手机桌面</p><button class="scene-widget" data-entry="widget" aria-label="Thought Mosaic 拍照记录组件"><span class="widget-camera">▣</span><span>Thought Mosaic<strong>拍照记录</strong></span></button>${sceneIcons}`;
  if (planKey === 'b') scene = `<h2 class="scene-heading">正在使用手机</h2><div id="gesture-surface" class="gesture-surface" aria-label="三指上滑演示区域"><div class="scene-gray gesture-main"></div><div class="scene-columns gesture-columns"><div></div><div></div></div></div><p class="scene-caption muted">三指上滑可直接唤起 Thought Mosaic。</p><button class="btn primary scene-trigger" data-entry="swipe">模拟三指上滑 ↑</button><p class="gesture-help">触屏：三指上滑 · 电脑：在灰块上向上拖动</p>`;
  if (planKey === 'c') scene = `<p class="scene-caption">手机桌面</p>${sceneIcons}`;
  return `<section class="page-heading entry-heading"><div><div class="eyebrow">FOUR WAYS TO START</div><h1>灵感出现，怎么留下？</h1><p>把四种入口都走一遍，找到最顺手的那一个。</p></div><button class="btn compact" data-action="all">回到灵感库</button></section><div class="entry-tabs" role="group" aria-label="选择快捷唤醒方案">${Object.entries(ENTRY_PLANS).map(([key,p]) => `<button class="entry-tab ${key === planKey ? 'selected' : ''}" data-entry-plan="${key}" aria-pressed="${key === planKey}"><span>${p.code}</span>${p.title}</button>`).join('')}</div><div class="entry-layout"><section class="entry-phone" aria-label="${plan.code} ${plan.title}原型场景"><div class="scene-status" aria-hidden="true"><strong>9:41</strong><span>▮▮▮　◉　▰</span></div><div class="entry-scene">${scene}</div></section><aside class="entry-guide"><span class="entry-simulation">原型场景 · 可交互演示</span><div class="eyebrow">方案 ${plan.code}</div><h2>${plan.title}</h2><p class="entry-journey">${plan.intro}</p><p>${plan.hint}</p><div class="entry-system"><strong>在真实设备上</strong><p>${plan.system}</p></div><p class="entry-note">进入后可以写字、加标签并保存。不同方案的记录会出现在同一个灵感库里。</p><button class="btn compact" data-entry="restart">重新体验本方案</button></aside></div>`;
}
export async function makeDemoScreenshot() {
  // Capture this prototype's owned geometric scene, never another app or screen.
  const canvas = document.createElement('canvas'); canvas.width = 700; canvas.height = 820;
  const ctx = canvas.getContext('2d'); ctx.scale(2, 2); ctx.fillStyle = 'white'; ctx.fillRect(0, 0, 350, 410);
  function block(x,y,w,h,r,color) { ctx.fillStyle=color; ctx.beginPath(); ctx.roundRect(x,y,w,h,r); ctx.fill(); }
  block(0,0,350,46,14,'#e8e8e8'); ctx.fillStyle='#666'; ctx.font='14px sans-serif'; ctx.fillText('⌕  正在浏览内容',12,28);
  block(0,58,350,180,14,'#e8e8e8'); block(0,250,170,140,12,'#d8d8d8'); block(180,250,170,140,12,'#e3e3e3');
  const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/png'));
  if (!blob) throw new Error('示例截图生成失败，请重试。'); return blob;
}
