import { ENTRY_PLANS, ENTRY_ORDER, entriesMarkup, bindEntryGesture, makeDemoScreenshot } from './entries.js';
import { DEFAULT_TAGS, normalizeTags, newNote, hasContent, title, signature, matches, readArchive, putDraft, removeDraft, saveNote, deleteNote, importNotes } from './model.js';

const $ = (selector, root = document) => root.querySelector(selector);
const app = $('#app'), dialog = $('#dialog');
const state = { notes: [], drafts: [], view: 'library', filter: 'all', tag: '', query: '', note: null, original: null, baseUpdatedAt: null, busy: false, storageError: '', recording: false, entryPlan: 'a1', entryStep: 'ready', entryScreenshot: null };
const paths = {
  plus: '<path d="M12 5v14M5 12h14"/>', back: '<path d="m15 5-7 7 7 7"/>', close: '<path d="m6 6 12 12M6 18 18 6"/>',
  grid: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  edit: '<path d="M12 4H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-7M15 3l6 6M8 16l1-5L18 2l4 4-9 9-5 1Z"/>',
  search: '<circle cx="10" cy="10" r="6"/><path d="m15 15 5 5"/>', camera: '<path d="M4 6h4l2-3h4l2 3h4a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1Z"/><circle cx="12" cy="13" r="4"/>',
  image: '<rect x="3" y="3" width="18" height="18" rx="3"/><circle cx="8" cy="8" r="1.5"/><path d="m3 17 6-6 4 4 3-3 5 5"/>', mic: '<rect x="9" y="2" width="6" height="13" rx="3"/><path d="M5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8"/>',
  check: '<path d="m5 12 4 4L19 6"/>', lock: '<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3M12 15v2"/>',
  arrow: '<path d="M4 12h16m-6-6 6 6-6 6"/>', clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  download: '<path d="M12 3v12m-5-5 5 5 5-5M4 16v4a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-4"/>', upload: '<path d="M12 16V4m-5 5 5-5 5 5M4 16v4a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-4"/>',
  help: '<circle cx="12" cy="12" r="9"/><path d="M9.5 8a2.5 2.5 0 1 1 4 2l-1.5 1.5V14M12 17h.01"/>', trash: '<path d="M3 6h18M9 6V3h6v3M6 6l1 15h10l1-15M10 10v7M14 10v7"/>',
};
const icon = name => `<svg viewBox="0 0 24 24" aria-hidden="true">${paths[name] || paths.edit}</svg>`;
const esc = value => String(value).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const sampleArt = '<div class="sample-art" role="img" aria-label="Figma 原型中的人物和场景灰色示意图"><i></i><i></i><i></i></div>';
const brand = `<button class="brand" data-action="home" aria-label="Thought Mosaic 首页"><span class="brand-mark" aria-hidden="true"><i></i><i></i><i></i><i></i></span><span class="brand-name">Thought Mosaic<span class="brand-sub">灵感，从此刻开始</span></span></button>`;
let draftTimer, draftQueue = Promise.resolve(), pendingDraft = false, toastTimer;
let objectURLs = [], recorder = null, audioStream = null, recordingInterval, recordingStart, recordingPromise, audioRequest = 0, cameraRequest = 0, cameraStream = null, dialogCleanup = null, dialogReturnFocus;
const channel = typeof BroadcastChannel !== 'undefined' ? new BroadcastChannel('thought-mosaic-updates') : null;
function url(blob) { const value = URL.createObjectURL(blob); objectURLs.push(value); return value; }
function releaseURLs() { objectURLs.forEach(value => URL.revokeObjectURL(value)); objectURLs = []; }
function date(value, full = false) { return new Intl.DateTimeFormat('zh-CN', full ? { month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit' } : { month: '2-digit', day: '2-digit' }).format(new Date(value)); }
function allTags() { return normalizeTags([...state.notes.flatMap(n => n.tags), ...state.drafts.flatMap(n => n.tags), ...DEFAULT_TAGS]); }
function notify(message) { clearTimeout(toastTimer); $('#toast').textContent = message; $('#toast').classList.add('visible'); toastTimer = setTimeout(() => $('#toast').classList.remove('visible'), 4500); }
function report(error) { console.error(error); notify(error?.message || '操作没有完成，请重试。'); }
function storageFailed(error) { state.storageError = '内容未能写入浏览器。请检查可用空间或浏览器存储设置，当前页面的文字仍然保留。'; updateDraftStatus('草稿保存失败'); report(error); }
async function refresh() { Object.assign(state, await readArchive()); }
function changed() { return state.note && signature(state.note) !== signature(state.original); }
function editableUnsaved() { return state.view === 'editor' && (changed() || (!state.baseUpdatedAt && hasContent(state.note))); }

function render() {
  releaseURLs();
  app.innerHTML = `<div class="shell"><aside class="sidebar">${brand}<button class="btn primary new-button" data-action="new">${icon('plus')}新建记录</button>
    <nav class="sidebar-nav" aria-label="记录导航"><button class="nav-item ${state.filter === 'all' && !state.tag ? 'active' : ''}" data-action="all">${icon('grid')}全部记录<span class="count">${state.notes.length}</span></button><button class="nav-item ${state.filter === 'drafts' ? 'active' : ''}" data-action="drafts">${icon('edit')}我的草稿<span class="count">${state.drafts.length}</span></button></nav>
    <button class="nav-item ${state.view === 'entries' ? 'active' : ''}" data-action="entries">${icon('arrow')}快捷唤醒体验</button><div class="side-label">灵感标签</div><div class="side-tags">${allTags().slice(0,10).map(t => `<button class="side-tag ${state.tag === t ? 'active' : ''}" data-action="filter-tag" data-tag="${esc(t)}"><span>#</span>${esc(t)}</button>`).join('')}</div>
    <div class="sidebar-bottom"><button class="nav-item" data-action="sample">${icon('grid')}体验原型示例</button><button class="nav-item" data-action="help">${icon('help')}使用说明与备份</button><div class="local-label">${icon('lock')}仅保存在此浏览器</div><p class="sidebar-footnote">THOUGHT MOSAIC · WEB DEMO</p></div></aside>
    <main class="main"><header class="mobile-header">${brand}<button class="icon-btn" data-action="help" aria-label="使用说明与备份">${icon('help')}</button></header><header class="topbar"><div class="path">我的空间<span>/</span><strong>${state.view === 'editor' ? '快速记录' : state.view === 'saved' ? '已保存' : state.view === 'entries' ? '快捷唤醒体验' : '灵感库'}</strong></div><div class="edition"><span class="dot"></span>浏览器体验版</div></header><div class="workspace ${state.view === 'editor' ? 'editor-workspace' : ''}">${state.storageError ? `<div class="error-banner" role="alert">${esc(state.storageError)}</div>` : ''}${state.view === 'editor' ? editorMarkup() : state.view === 'saved' ? savedMarkup() : state.view === 'entries' ? entriesMarkup(state.entryPlan, state.entryStep, state.entryScreenshot ? url(state.entryScreenshot) : '') : libraryMarkup()}</div></main></div>`;
  if (state.view === 'entries') bindEntryGesture($('#gesture-surface'), () => enterFromPlan('b').catch(report));
  if (state.view === 'library') {
    $('#search').value = state.query;
    $('#search').addEventListener('input', event => { state.query = event.target.value; renderCards(); });
  }
  if (state.view === 'editor') {
    $('#thought').value = state.note.text;
    $('#thought').addEventListener('input', event => { state.note.text = event.target.value; $('#character-count').textContent = `${Array.from(state.note.text).length} 字`; updateSave(); scheduleDraft(); });
    renderAttachments();
  }
}
function libraryMarkup() {
  return `<section class="page-heading"><div><div class="eyebrow">YOUR THOUGHTS, PIECED TOGETHER</div><h1>给灵感，留个位置。</h1><p>一句话、一张图，或一段声音。先记下来，慢慢拼起来。</p></div><div class="date-stamp">${new Intl.DateTimeFormat('zh-CN', { month: 'long', day: 'numeric', weekday: 'long' }).format(new Date())}</div></section>
    <section class="capture-banner"><div class="banner-copy"><h2>刚刚，想到了什么？</h2><p>不必完整，也不用整理。<br>每一个小小的念头，都值得被留下。</p><div class="banner-actions"><button class="btn" data-action="new">${icon('plus')}记下一点想法</button><button class="btn ghost" data-action="capture-new">${icon('camera')}拍照</button></div></div><div class="mosaic-art" aria-hidden="true"><span></span><span></span><span></span><span></span></div></section>
    <section class="entry-launcher"><div><strong>四种快捷唤醒，都试试看</strong><p>A1 截图 · A2 拍照组件 · B 三指上滑 · C 直接打开</p></div><button class="btn" data-action="entries">开始体验 →</button></section><div class="library-toolbar"><h2 class="section-title">${state.filter === 'drafts' ? '我的草稿' : '我的记录'}<span id="result-count"></span></h2><div class="mobile-filter"><button class="btn ${state.filter === 'all' ? 'selected' : ''}" data-action="all">全部</button><button class="btn ${state.filter === 'drafts' ? 'selected' : ''}" data-action="drafts">草稿 ${state.drafts.length}</button></div><label class="search-box">${icon('search')}<input id="search" type="search" placeholder="搜索想法或标签" aria-label="搜索想法或标签" autocomplete="off"></label></div>${state.tag ? `<div class="filter-status">标签：${esc(state.tag)}<button class="text-button" data-action="all">清除筛选</button></div>` : ''}<div class="note-grid" id="note-grid">${cardsMarkup()}</div>
    <footer class="library-bottom"><span>灵感不必按顺序出现。<br>记录存于当前浏览器，不会上传或与他人共享。</span><button class="text-button" data-action="sample">体验 Figma 原型示例 ↗</button></footer>`;
}
function cardsMarkup() {
  const items = (state.filter === 'drafts' ? state.drafts : state.notes).filter(n => matches(n, state.query, state.tag));
  if (!items.length) return `<div class="empty"><div class="empty-symbol">${icon(state.filter === 'drafts' ? 'edit' : 'grid')}</div><h3>${state.query || state.tag ? '还没有找到这条灵感' : state.filter === 'drafts' ? '暂时没有未完成的想法' : '你的第一块灵感，等你放进来'}</h3><p>${state.query || state.tag ? '试试其他文字，或清除标签筛选。' : state.filter === 'drafts' ? '编辑中的内容会自动保留在这里。' : '从一个念头开始。也可以先体验原型里的示例。'}</p>${!state.query && !state.tag && state.filter !== 'drafts' ? '<button class="btn compact" data-action="sample">打开原型示例 →</button>' : ''}</div>`;
  return items.map(n => {
    const first = n.attachments.find(a => a.kind !== 'audio') || n.attachments[0];
    const preview = first ? `<div class="card-preview">${first.kind === 'sample' ? sampleArt : first.kind === 'audio' ? icon('mic') : `<img src="${url(first.blob)}" alt="记录图片" loading="lazy">`}</div>` : '';
    return `<button class="note-card ${state.filter === 'drafts' ? 'draft-card' : ''}" data-action="open-note" data-id="${esc(n.id)}" aria-label="${esc((state.filter === 'drafts' ? '继续草稿：' : '打开记录：') + title(n))}">${preview}${state.filter === 'drafts' ? `<div class="draft-badge">${icon('edit')}草稿 · 继续编辑</div>` : ''}<h3>${esc(title(n))}</h3><div class="card-tags">${n.tags.slice(0,3).map(t => `<span class="tiny-tag"># ${esc(t)}</span>`).join('')}</div><div class="card-meta"><span>${date(n.updatedAt, true)}</span><span>${n.attachments.length ? `${n.attachments.length} 份素材` : '文字记录'}</span></div></button>`;
  }).join('');
}
function renderCards() { releaseURLs(); $('#note-grid').innerHTML = cardsMarkup(); $('#result-count').textContent = ` / ${(state.filter === 'drafts' ? state.drafts : state.notes).filter(n => matches(n, state.query, state.tag)).length}`; }
function editorMarkup() {
  return `<div class="page-heading"><div><div class="eyebrow">CAPTURE THE MOMENT</div><h1>让想法，落在这里。</h1></div></div><div class="editor-wrap"><section class="editor-paper" aria-label="快速记录编辑器"><header class="editor-nav"><button class="icon-btn" data-action="exit" aria-label="返回灵感库">${icon('back')}</button><h1>快速记录</h1><button id="save-note" class="btn primary" data-action="save" ${hasContent(state.note) ? '' : 'disabled'}>保存</button></header><div class="editor-body">${state.note.entryMethod && ENTRY_PLANS[state.note.entryMethod] ? `<div class="entry-origin">来自方案 ${ENTRY_PLANS[state.note.entryMethod].code} · ${ENTRY_PLANS[state.note.entryMethod].title}</div>` : ''}<div id="attachments" class="attachment-list"></div><h2><label for="thought">想记住什么？一句话也可以。</label></h2><div class="text-box"><textarea id="thought" placeholder="刚刚想到了什么？" aria-label="想法内容" spellcheck="false"></textarea><div class="input-footer"><span id="character-count">${Array.from(state.note.text).length} 字</span><button data-action="finish-typing">完成输入</button><button id="record-audio" data-action="record">${icon('mic')}语音</button></div><div id="recording-area"></div></div><div class="material-actions"><button class="btn" data-action="camera">${icon('camera')}拍照</button><button class="btn" data-action="add-image">${icon('image')}添加图片</button></div><div class="tag-section"><h3>标签 <span>（可选）</span></h3><div class="chips" id="selected-tags">${selectedTagsMarkup()}</div></div><div class="editor-foot"><span>${date(state.note.createdAt, true)}</span><span id="draft-status" role="status">${state.drafts.some(n => n.id === state.note.id) ? '已恢复草稿' : '随时记下，不用着急'}</span></div>${state.baseUpdatedAt ? `<button class="btn ghost compact danger" data-action="delete">${icon('trash')}删除这条记录</button>` : ''}</div></section><aside class="editor-aside"><div class="eyebrow">A LITTLE SPACE FOR YOU</div><h2>想法还很零散，<br>也没关系。</h2><p>留下当时的画面、声音和心情。<br>将来的某一天，它们也许会连成新的灵感。</p><div class="aside-line"></div><div class="shortcut"><kbd>${navigator.platform.includes('Mac') ? '⌘' : 'Ctrl'} + Enter</kbd>保存记录</div><p>图片可以拖进来，也可以直接粘贴。编辑会自动保留为草稿。</p></aside></div>`;
}
function selectedTagsMarkup() { return state.note.tags.map(t => `<button class="chip" data-action="tags">${esc(t)}</button>`).join('') + `<button class="chip" data-action="tags">${icon('plus')}添加标签</button>`; }
function renderAttachments() {
  const list = $('#attachments'); if (!list) return;
  releaseURLs();
  list.innerHTML = state.note.attachments.map((a, i) => `<div class="attachment"><div class="attachment-head"><span class="chip">${icon('check')}${a.kind === 'audio' ? '语音' : a.kind === 'screenshot' || a.kind === 'sample' && a.label !== '照片' ? '截图' : '图片'}</span><button class="icon-btn" data-action="remove-attachment" data-id="${esc(a.id)}" aria-label="移除第 ${i + 1} 份素材">${icon('close')}</button></div>${a.kind === 'sample' ? sampleArt : a.kind === 'audio' ? `<audio controls preload="metadata" src="${url(a.blob)}" aria-label="语音录音 ${i + 1}"></audio>` : `<img src="${url(a.blob)}" alt="添加的图片 ${i + 1}">`}</div>`).join('');
}
function savedMarkup() { const n = state.note; return `<section class="saved-view"><div class="check-circle">${icon('check')}</div><div class="eyebrow">ONE MORE PIECE OF INSPIRATION</div><h1>已保存</h1><p>这个小小的念头，已经被好好留下。</p><div class="saved-summary"><strong>本次保存内容</strong>${[n.text.trim() ? '想法文字' : '', n.attachments.length ? `${n.attachments.length} 份素材` : '', n.tags.length ? `${n.tags.length} 个标签` : ''].filter(Boolean).join('、')}<div class="saved-title">${esc(title(n))}</div></div><button class="btn primary" data-action="done">完成，回到灵感库 ${icon('arrow')}</button><button class="btn" data-action="new">继续记录</button><p class="storage-copy">已保存在此浏览器。其他设备上的记录互相独立。</p>${state.note.entryMethod && ENTRY_PLANS[state.note.entryMethod] ? `<div class="entry-saved-actions"><p>方案 ${ENTRY_PLANS[state.note.entryMethod].code} 已完成：唤醒 → 记录 → 保存</p><button class="btn" data-action="next-entry">体验下一种入口 →</button><button class="btn ghost" data-action="entries">返回方案选择</button></div>` : ''}</section>`; }
function updateSave() { const button = $('#save-note'); if (button) button.disabled = !hasContent(state.note) || state.busy || state.recording; }
function updateDraftStatus(text) { if ($('#draft-status')) $('#draft-status').textContent = text; }
function scheduleDraft() {
  clearTimeout(draftTimer); pendingDraft = true; updateDraftStatus('正在保留…');
  draftTimer = setTimeout(() => { persistDraft().catch(storageFailed); }, 350);
}
function persistDraft() {
  clearTimeout(draftTimer);
  if (state.view !== 'editor') return draftQueue;
  const snapshot = structuredClone(state.note), base = state.baseUpdatedAt;
  const shouldStore = hasContent(snapshot) && (changed() || !base);
  const queued = draftQueue.catch(() => {}).then(() => shouldStore ? putDraft(snapshot, base) : removeDraft(snapshot.id));
  draftQueue = queued;
  return queued.then(() => { if (draftQueue === queued) { pendingDraft = false; updateDraftStatus(shouldStore ? '草稿已保留' : '尚无未保存内容'); } });
}
async function openEditor(note = newNote(), base = null) {
  state.note = structuredClone(note); state.original = structuredClone(state.notes.find(n => n.id === note.id) || (base ? note : newNote())); state.baseUpdatedAt = base; state.view = 'editor'; state.busy = false;
  render(); window.scrollTo(0, 0);
}
async function goLibrary(filter = state.filter, tag = '') {
  await refresh(); state.view = 'library'; state.note = null; state.original = null; state.filter = filter; state.tag = tag; state.query = ''; state.busy = false; render(); renderCards(); window.scrollTo(0, 0);
}
function openDialog(content, { className = '', cleanup = null } = {}) {
  if (dialog.open) closeDialog();
  dialogReturnFocus = document.activeElement;
  dialog.className = className; dialog.innerHTML = content; dialogCleanup = cleanup; dialog.showModal();
}
function closeDialog() { if (dialogCleanup) { dialogCleanup(); dialogCleanup = null; } dialog.close(); dialog.innerHTML = ''; if (dialogReturnFocus?.isConnected) dialogReturnFocus.focus({ preventScroll: true }); }
function dialogHeader(text) { return `<div class="dialog-header"><h2 id="dialog-title">${esc(text)}</h2><button class="icon-btn" data-dialog="close" aria-label="关闭">${icon('close')}</button></div>`; }
dialog.addEventListener('cancel', event => { event.preventDefault(); closeDialog(); });
dialog.addEventListener('click', event => { if (event.target.closest('[data-dialog="close"]')) closeDialog(); });
async function requestExit(next = () => goLibrary('all')) {
  if (state.busy) { notify('正在处理素材，请稍等一下。'); return; }
  if (state.recording) await stopRecording();
  audioRequest++; resetRecordButton();
  if (!editableUnsaved()) { if (state.view === 'editor') { clearTimeout(draftTimer); await draftQueue; } await next(); return; }
  const active = document.activeElement; active?.blur();
  openDialog(`${dialogHeader('有未保存内容')}<div class="dialog-body"><p>你想怎么处理这次记录？<br>保留草稿，下次可以接着写。</p><div class="dialog-buttons"><button class="btn primary" id="keep-draft">保留草稿</button><button class="btn danger" id="discard-draft">${state.baseUpdatedAt ? '放弃修改' : '放弃记录'}</button><button class="btn" id="continue-edit">继续编辑</button></div></div>`);
  $('#continue-edit').onclick = () => { closeDialog(); if (active?.isConnected) active.focus({ preventScroll: true }); };
  $('#keep-draft').onclick = async () => {
    try { await persistDraft(); closeDialog(); await next(); } catch (e) { storageFailed(e); }
  };
  $('#discard-draft').onclick = async () => {
    try { clearTimeout(draftTimer); await draftQueue.catch(() => {}); await removeDraft(state.note.id); pendingDraft = false; closeDialog(); await next(); } catch (e) { report(e); }
  };
}
async function save() {
  if (state.view !== 'editor' || !hasContent(state.note) || state.busy || state.recording) return;
  state.busy = true; updateSave(); $('#save-note').textContent = '保存中…';
  try {
    clearTimeout(draftTimer); await draftQueue.catch(() => {});
    const saved = await saveNote(state.note, state.baseUpdatedAt);
    pendingDraft = false; state.storageError = ''; state.note = saved; state.original = structuredClone(saved); state.baseUpdatedAt = saved.updatedAt; state.view = 'saved';
    await refresh(); channel?.postMessage('changed'); render(); window.scrollTo(0, 0);
  } catch (e) { report(e); updateDraftStatus('保存未完成，内容仍在'); } finally { state.busy = false; updateSave(); if ($('#save-note')) $('#save-note').textContent = '保存'; }
}

function openTags() {
  let chosen = [...state.note.tags];
  openDialog(`${dialogHeader('添加标签')}<div class="dialog-body"><input class="tag-search" id="tag-search" placeholder="搜索或创建标签" aria-label="搜索或创建标签" autocomplete="off" maxlength="48"><div class="dialog-scroll"><p class="dialog-label">最近使用</p><div class="tag-options" id="tag-options"></div><div id="create-tag-area"></div></div><button class="btn primary tag-confirm" id="confirm-tags">完成</button></div>`, { className: 'tag-dialog' });
  const input = $('#tag-search');
  function draw() {
    const query = normalizeTags([input.value])[0] || '';
    const candidates = normalizeTags([...chosen, ...allTags()]).filter(t => t.toLocaleLowerCase().includes(query.toLocaleLowerCase()));
    $('#tag-options').innerHTML = candidates.map(t => `<button class="chip ${chosen.includes(t) ? 'selected' : ''}" data-tag-option="${esc(t)}" aria-pressed="${chosen.includes(t)}">${chosen.includes(t) ? icon('check') : ''}${esc(t)}</button>`).join('') || '<p class="dialog-label">没有匹配的标签，可以创建一个。</p>';
    $('#create-tag-area').innerHTML = query && !candidates.some(t => t.toLocaleLowerCase() === query.toLocaleLowerCase()) ? `<button class="btn create-tag" id="create-tag">${icon('plus')}创建“${esc(query)}”</button>` : '';
    $('#tag-options').onclick = event => { const button = event.target.closest('[data-tag-option]'); if (!button) return; const tag = button.dataset.tagOption; chosen = chosen.includes(tag) ? chosen.filter(t => t !== tag) : [...chosen, tag]; draw(); };
    if ($('#create-tag')) $('#create-tag').onclick = create;
  }
  function create() { const value = normalizeTags([input.value])[0]; if (!value) return; chosen = normalizeTags([...chosen, value]); input.value = ''; draw(); input.focus(); }
  input.addEventListener('input', draw);
  input.addEventListener('keydown', event => { if (event.key === 'Enter' && !event.isComposing) { event.preventDefault(); create(); } });
  $('#confirm-tags').onclick = () => { state.note.tags = normalizeTags(chosen); $('#selected-tags').innerHTML = selectedTagsMarkup(); closeDialog(); scheduleDraft(); };
  draw();
}
async function imageAttachment(file) {
  if (!/^image\/(jpeg|png|webp|gif|avif)$/.test(file.type)) throw new Error('请选择 JPG、PNG、WebP、GIF 或 AVIF 图片。HEIC 请先转换为 JPG。');
  if (file.size > 20 * 1024 * 1024) throw new Error('单张图片请小于 20 MB。');
  const source = URL.createObjectURL(file), img = new Image();
  try {
    img.src = source; await img.decode();
    const scale = Math.min(1, 2000 / Math.max(img.naturalWidth, img.naturalHeight));
    const canvas = document.createElement('canvas'); canvas.width = Math.max(1, Math.round(img.naturalWidth * scale)); canvas.height = Math.max(1, Math.round(img.naturalHeight * scale));
    const ctx = canvas.getContext('2d'); ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, canvas.width, canvas.height); ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
    const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/jpeg', .86));
    if (!blob) throw new Error('图片处理失败，请换一张重试。');
    return { id: crypto.randomUUID(), kind: 'image', name: file.name || 'photo.jpg', blob };
  } finally { URL.revokeObjectURL(source); }
}
async function addImages(files) {
  if (state.view !== 'editor' || state.busy) return;
  const values = Array.from(files); if (!values.length) return;
  if (state.note.attachments.length + values.length > 12) { notify('每条记录最多添加 12 份素材。'); return; }
  state.busy = true; updateSave(); updateDraftStatus('正在处理图片…');
  let added = 0;
  try {
    for (const file of values) { state.note.attachments.push(await imageAttachment(file)); added++; }
  } catch (e) { report(e); } finally {
    state.busy = false; updateSave(); renderAttachments(); if (added) { scheduleDraft(); notify(`已添加 ${added} 张图片`); } else updateDraftStatus('可以继续编辑');
  }
}
$('#image-picker').addEventListener('change', async event => { await addImages(event.target.files); event.target.value = ''; });
document.addEventListener('paste', event => { if (state.view === 'editor' && !dialog.open && event.clipboardData.files.length) { event.preventDefault(); addImages(event.clipboardData.files); } });
let dragDepth = 0;
app.addEventListener('dragenter', event => { if (state.view === 'editor' && event.dataTransfer.types.includes('Files')) { event.preventDefault(); dragDepth++; document.body.classList.add('file-drop-active'); } });
app.addEventListener('dragover', event => { if (state.view === 'editor') event.preventDefault(); });
app.addEventListener('dragleave', () => { if (--dragDepth <= 0) document.body.classList.remove('file-drop-active'); });
app.addEventListener('drop', event => { if (state.view === 'editor') { event.preventDefault(); dragDepth = 0; document.body.classList.remove('file-drop-active'); addImages(event.dataTransfer.files); } });

async function openCamera() {
  if (state.busy) return;
  if (state.recording) await stopRecording();
  audioRequest++; resetRecordButton();
  const token = ++cameraRequest;
  function cleanup() { cameraRequest++; cameraStream?.getTracks().forEach(track => track.stop()); cameraStream = null; }
  openDialog(`${dialogHeader('拍照记录')}<div class="dialog-body"><video class="camera-video" id="camera-video" autoplay muted playsinline></video><p class="camera-status" id="camera-status">正在打开相机，请允许浏览器使用摄像头。</p><button class="btn primary tag-confirm" id="take-photo" disabled>拍下这一刻</button><button class="btn tag-confirm" id="camera-upload">从设备添加图片</button></div>`, { cleanup });
  $('#camera-upload').onclick = () => { closeDialog(); $('#image-picker').click(); };
  try {
    if (!navigator.mediaDevices?.getUserMedia) throw new Error('当前浏览器不支持相机。可以从设备添加图片。');
    const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' }, audio: false });
    if (cameraRequest !== token || !dialog.open) { stream.getTracks().forEach(track => track.stop()); return; }
    cameraStream = stream; const video = $('#camera-video'); video.srcObject = stream;
    await video.play();
    if (cameraRequest !== token) return;
    $('#camera-status').textContent = '准备好了。'; $('#take-photo').disabled = false;
    $('#take-photo').onclick = async () => {
      if (!video.videoWidth) { notify('相机画面还没准备好，请稍等。'); return; }
      const canvas = document.createElement('canvas'); canvas.width = video.videoWidth; canvas.height = video.videoHeight; canvas.getContext('2d').drawImage(video, 0, 0);
      const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/jpeg', .9));
      if (cameraRequest !== token) return;
      closeDialog(); if (blob) await addImages([new File([blob], 'camera.jpg', { type: 'image/jpeg' })]);
    };
  } catch (error) {
    if (cameraRequest !== token) return;
    cameraStream?.getTracks().forEach(track => track.stop()); cameraStream = null;
    $('#camera-status').textContent = error.name === 'NotAllowedError' ? '相机权限未开启。可在地址栏的网站设置中允许，或直接添加图片。' : '没有可用的相机。请检查摄像头连接，或从设备添加图片。';
  }
}
async function startRecording() {
  if (state.busy || state.recording) return;
  if (state.note.attachments.length >= 12) { notify('每条记录最多添加 12 份素材。'); return; }
  if (!navigator.mediaDevices?.getUserMedia || !window.MediaRecorder) { notify('此浏览器不支持录音，请使用新版 Edge、Chrome 或 Safari。'); return; }
  const token = ++audioRequest, noteID = state.note.id;
  $('#record-audio').disabled = true; $('#record-audio').textContent = '等待麦克风权限…';
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    if (token !== audioRequest || state.view !== 'editor' || state.note.id !== noteID) { stream.getTracks().forEach(track => track.stop()); return; }
    audioStream = stream;
    const mimeType = ['audio/webm;codecs=opus', 'audio/mp4', 'audio/ogg;codecs=opus'].find(t => MediaRecorder.isTypeSupported(t));
    recorder = new MediaRecorder(stream, mimeType ? { mimeType } : undefined);
    const chunks = []; recorder.ondataavailable = event => { if (event.data.size) chunks.push(event.data); };
    recordingStart = Date.now(); state.recording = true;
    recordingPromise = new Promise(resolve => {
      recorder.onstop = () => {
        clearInterval(recordingInterval); stream.getTracks().forEach(track => track.stop()); audioStream = null; state.recording = false;
        const blob = new Blob(chunks, { type: recorder.mimeType || chunks[0]?.type || 'audio/webm' });
        if (blob.size && state.view === 'editor' && state.note.id === noteID) {
          state.note.attachments.push({ id: crypto.randomUUID(), kind: 'audio', blob, duration: (Date.now() - recordingStart) / 1000 });
          renderAttachments(); scheduleDraft();
        }
        recorder = null; if ($('#recording-area')) $('#recording-area').innerHTML = ''; resetRecordButton(); updateSave(); resolve();
      };
      recorder.onerror = () => { notify('录音发生中断，已录到的部分会尽量保留。'); if (recorder?.state === 'recording') recorder.stop(); };
    });
    recorder.start(500); updateSave();
    $('#recording-area').innerHTML = `<div class="recording"><span class="recording-time"><span class="recording-dot"></span>录音中 <span id="record-timer">00:00</span></span><button data-action="stop-recording">停止录音</button></div>`;
    recordingInterval = setInterval(() => {
      const secs = Math.floor((Date.now() - recordingStart) / 1000);
      if ($('#record-timer')) $('#record-timer').textContent = `${String(Math.floor(secs / 60)).padStart(2, '0')}:${String(secs % 60).padStart(2, '0')}`;
      if (secs >= 300) { stopRecording(); notify('已录满 5 分钟，声音已加入记录。'); }
    }, 250);
  } catch (error) {
    audioStream?.getTracks().forEach(track => track.stop()); audioStream = null; state.recording = false;
    if (token === audioRequest) { resetRecordButton(); notify(error.name === 'NotAllowedError' ? '麦克风权限未开启。可在地址栏的网站设置中允许后重试。' : '没有可用的麦克风，请检查设备后重试。'); }
  }
}
function resetRecordButton() { if ($('#record-audio')) { $('#record-audio').disabled = false; $('#record-audio').innerHTML = `${icon('mic')}语音`; } }
async function stopRecording() { if (recorder?.state === 'recording') { recorder.stop(); await recordingPromise; } }

function showHelp() {
  openDialog(`${dialogHeader('随手记录，安心留下')}<div class="dialog-body"><div class="dialog-scroll"><div class="help-row"><strong>Windows、Mac 和手机都可以</strong>用浏览器打开即可，建议使用新版 Edge、Chrome 或 Safari。保存快捷键为 Ctrl / ⌘ + Enter。</div><div class="help-row"><strong>记录保存在当前浏览器</strong>文字、图片和声音不会上传。不同设备、浏览器的记录互相独立；清除网站数据或无痕窗口关闭后可能丢失，请及时导出备份。</div><div class="help-row"><strong>图片与录音</strong>支持选择、拖入和粘贴图片。相机与麦克风需要浏览器授权；录音保留声音，不自动转成文字。</div><div class="help-row"><strong>这是一个可操作的 Demo</strong>保留 Figma 的记录、标签、草稿和保存流程。“快捷唤醒体验”包含 A1 截图、A2 拍照组件、B 三指上滑和 C 直接打开的完整原型流程；场景模拟不会修改系统界面或监听其他 App。</div></div><div class="dialog-buttons" style="margin-top:18px"><button class="btn primary" id="export-backup">${icon('download')}导出记录与草稿</button><button class="btn" id="import-backup">${icon('upload')}导入备份</button></div></div>`);
  $('#export-backup').onclick = () => exportBackup().catch(report);
  $('#import-backup').onclick = () => $('#backup-picker').click();
}
async function blobToData(blob) { return new Promise((resolve, reject) => { const reader = new FileReader(); reader.onload = () => resolve(reader.result); reader.onerror = () => reject(reader.error); reader.readAsDataURL(blob); }); }
async function exportBackup() {
  if (state.recording) await stopRecording();
  if (state.view === 'editor') await persistDraft();
  const archive = await readArchive();
  const notes = await Promise.all([...archive.notes, ...archive.drafts.map(n => ({ ...n, wasDraft: true }))].map(async n => ({ ...n, attachments: await Promise.all(n.attachments.map(async a => { const { blob, ...rest } = a; return { ...rest, ...(blob ? { data: await blobToData(blob) } : {}) }; })) })));
  const blob = new Blob([JSON.stringify({ format: 'thought-mosaic-web', version: 1, exportedAt: new Date().toISOString(), notes })], { type: 'application/json' });
  const href = URL.createObjectURL(blob), link = document.createElement('a'); link.href = href; link.download = `thought-mosaic-${new Date().toISOString().slice(0,10)}.json`; link.click(); setTimeout(() => URL.revokeObjectURL(href), 1000); notify('备份已导出，包含记录和草稿。');
}
$('#backup-picker').addEventListener('change', async event => {
  const file = event.target.files[0]; event.target.value = ''; if (!file) return;
  try {
    if (file.size > 100 * 1024 * 1024) throw new Error('备份文件过大，请选择小于 100 MB 的文件。');
    const data = JSON.parse(await file.text());
    if (data.format !== 'thought-mosaic-web' || data.version !== 1 || !Array.isArray(data.notes) || data.notes.length > 1000) throw new Error('这不是支持的 Thought Mosaic 备份。');
    const notes = data.notes.map(n => {
      if (typeof n.text !== 'string' || n.text.length > 1000000 || !Array.isArray(n.tags) || !n.tags.every(t => typeof t === 'string') || !Array.isArray(n.attachments) || n.attachments.length > 12 || !Number.isFinite(Date.parse(n.createdAt)) || !Number.isFinite(Date.parse(n.updatedAt))) throw new Error('备份中有无法识别的记录。');
      const attachments = n.attachments.map(a => {
        if (a.kind === 'sample') return { id: crypto.randomUUID(), kind: 'sample', ...(a.label === '照片' ? { label: '照片' } : {}) };
        if (!['image', 'screenshot', 'audio'].includes(a.kind) || typeof a.data !== 'string') throw new Error('备份中有不支持的素材。');
        const m = a.data.match(/^data:((?:image\/(?:jpeg|png|webp|gif|avif)|audio\/(?:webm|mp4|ogg|wav))(?:;codecs=[\w.-]+)?);base64,([A-Za-z0-9+/=]+)$/);
        if (!m || (a.kind !== 'audio') !== m[1].startsWith('image/')) throw new Error('备份中的素材格式无法识别。');
        const binary = atob(m[2]); const bytes = Uint8Array.from(binary, c => c.charCodeAt(0));
        return { id: crypto.randomUUID(), kind: a.kind, blob: new Blob([bytes], { type: m[1] }) };
      });
      const note = { id: crypto.randomUUID(), text: n.text, tags: normalizeTags(n.tags), attachments, createdAt: n.createdAt, updatedAt: n.updatedAt };
      if (!hasContent(note)) throw new Error('备份包含空记录，导入未执行。'); return note;
    });
    if (state.view === 'editor') await persistDraft();
    await importNotes(notes); closeDialog(); if (state.view === 'library') await goLibrary('all'); else await refresh(); channel?.postMessage('changed'); notify(`已导入 ${notes.length} 条独立副本，原有记录保持不变。`);
  } catch (error) { report(error instanceof SyntaxError ? new Error('备份文件无法读取，请选择完整的 JSON 备份。') : error); }
});

app.addEventListener('click', async event => {
  const button = event.target.closest('[data-action]'); if (!button || button.disabled) return;
  const action = button.dataset.action;
  try {
    switch (action) {
      case 'entries': await requestExit(() => openEntries()); break;
      case 'next-entry': { const next = ENTRY_ORDER[(ENTRY_ORDER.indexOf(state.note.entryMethod) + 1) % ENTRY_ORDER.length]; await openEntries(next); break; }
      case 'home': case 'done': case 'all': await requestExit(() => goLibrary('all')); break;
      case 'drafts': await requestExit(() => goLibrary('drafts')); break;
      case 'filter-tag': await requestExit(() => goLibrary('all', button.dataset.tag)); break;
      case 'new': await requestExit(() => openEditor()); break;
      case 'capture-new': await requestExit(async () => { await openEditor(); await openCamera(); }); break;
      case 'sample': await requestExit(async () => { const note = newNote(); note.text = '两个人的手势很自然，想用在下一张人物画里。'; note.tags = ['街头观察', '绘画参考']; note.attachments = [{ id: crypto.randomUUID(), kind: 'sample' }]; await openEditor(note); scheduleDraft(); }); break;
      case 'open-note': {
        const n = (state.filter === 'drafts' ? state.drafts : state.notes).find(n => n.id === button.dataset.id);
        const draft = state.drafts.find(d => d.id === n.id);
        if (state.filter === 'drafts' || !draft) await openEditor(n, state.filter === 'drafts' ? n.baseUpdatedAt : n.updatedAt);
        else { await openEditor(draft, draft.baseUpdatedAt); notify('这条记录有未完成修改，已为你恢复草稿。'); }
        break;
      }
      case 'exit': await requestExit(); break;
      case 'save': await save(); break;
      case 'finish-typing': $('#thought').blur(); button.focus(); break;
      case 'tags': openTags(); break;
      case 'add-image': $('#thought').blur(); $('#image-picker').click(); break;
      case 'remove-attachment': state.note.attachments = state.note.attachments.filter(a => a.id !== button.dataset.id); renderAttachments(); updateSave(); scheduleDraft(); break;
      case 'record': await startRecording(); break;
      case 'stop-recording': await stopRecording(); break;
      case 'camera': await openCamera(); break;
      case 'help': showHelp(); break;
      case 'delete': {
        if (state.busy) { notify('正在处理素材，请稍等一下。'); break; }
        openDialog(`${dialogHeader('删除这条记录？')}<div class="dialog-body"><p>这条记录和它的素材将从当前浏览器删除。此操作无法撤销。</p><div class="dialog-buttons"><button class="btn danger" id="confirm-delete">删除记录</button><button class="btn" data-dialog="close">取消</button></div></div>`);
        $('#confirm-delete').onclick = async () => { try { clearTimeout(draftTimer); if (state.recording) await stopRecording(); clearTimeout(draftTimer); await draftQueue; await deleteNote(state.note.id); pendingDraft = false; closeDialog(); await goLibrary('all'); channel?.postMessage('changed'); notify('记录已删除'); } catch (e) { report(e); } };
        break;
      }
    }
  } catch (error) { report(error); }
});

async function openEntries(plan = state.entryPlan) {
  state.entryPlan = ENTRY_PLANS[plan] ? plan : 'a1'; state.entryStep = 'ready'; state.entryScreenshot = null; state.view = 'entries'; state.note = null; state.busy = false;
  render(); window.scrollTo(0, 0);
}
async function enterFromPlan(plan, realCamera = false) {
  const note = newNote(); note.entryMethod = plan;
  if (plan === 'a1') {
    if (!state.entryScreenshot) throw new Error('请先模拟截图，再开始记录。');
    note.attachments = [{ id: crypto.randomUUID(), kind: 'screenshot', name: '原型截图.png', blob: state.entryScreenshot }];
  }
  if (plan === 'a2' && !realCamera) note.attachments = [{ id: crypto.randomUUID(), kind: 'sample', label: '照片' }];
  await openEditor(note); if (hasContent(note)) scheduleDraft();
  if (realCamera) await openCamera();
}
app.addEventListener('click', async event => {
  const planButton = event.target.closest('[data-entry-plan]'), actionButton = event.target.closest('[data-entry]');
  try {
    if (planButton) { await openEntries(planButton.dataset.entryPlan); return; }
    if (!actionButton || state.view !== 'entries' || state.busy) return;
    switch (actionButton.dataset.entry) {
      case 'restart': await openEntries(); break;
      case 'take-screenshot':
        state.busy = true; actionButton.disabled = true;
        try { state.entryScreenshot = await makeDemoScreenshot(); state.entryStep = 'captured'; render(); }
        finally { state.busy = false; if (actionButton.isConnected) actionButton.disabled = false; }
        break;
      case 'capture-screenshot': await enterFromPlan('a1'); break;
      case 'widget': state.entryStep = 'camera'; render(); break;
      case 'sample-photo': await enterFromPlan('a2'); break;
      case 'real-camera': await enterFromPlan('a2', true); break;
      case 'swipe': await enterFromPlan('b'); break;
      case 'direct': await enterFromPlan('c'); break;
    }
  } catch (e) { report(e); }
});

document.addEventListener('keydown', event => {
  if (event.isComposing || dialog.open) return;
  if ((event.ctrlKey || event.metaKey) && event.key === 'Enter' && state.view === 'editor') { event.preventDefault(); save(); }
  if (event.key === 'Escape' && state.view === 'editor') { event.preventDefault(); requestExit().catch(report); }
});
window.addEventListener('beforeunload', event => { if (pendingDraft || state.busy || state.recording) { event.preventDefault(); event.returnValue = ''; } });
document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'hidden' && state.view === 'editor') { stopRecording().then(() => persistDraft()).catch(storageFailed); } });
window.addEventListener('pagehide', () => { audioRequest++; cameraRequest++; audioStream?.getTracks().forEach(t => t.stop()); cameraStream?.getTracks().forEach(t => t.stop()); });
if (channel) channel.onmessage = async () => { if (state.view === 'library') { await refresh(); render(); renderCards(); } };
try { await refresh(); const entry = new URL(location.href).searchParams.get('entry'); if (ENTRY_PLANS[entry]) await openEntries(entry); else { render(); renderCards(); } } catch (error) { state.storageError = '浏览器存储不可用。请允许网站保存本地数据，再重新打开页面。'; render(); report(error); }
