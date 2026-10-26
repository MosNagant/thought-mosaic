export const DEFAULT_TAGS = ['街头观察', '人物动作', '绘画参考', '日常生活'];
export function normalizeTags(tags) {
  const seen = new Set();
  return tags.map(t => Array.from(String(t).trim()).slice(0, 24).join('')).filter(t => {
    const key = t.toLocaleLowerCase();
    if (!t || seen.has(key)) return false;
    seen.add(key); return true;
  });
}
export function newNote() {
  const now = new Date().toISOString();
  return { id: crypto.randomUUID(), text: '', tags: [], attachments: [], createdAt: now, updatedAt: now };
}
export function hasContent(note) { return Boolean(note.text.trim() || note.attachments.length); }
export function title(note) { return note.text.trim().split('\n')[0] || (note.attachments.some(a => a.kind === 'audio') ? '一段声音，一点灵感' : '图片里的灵感'); }
export function signature(note) { return JSON.stringify([note.text, normalizeTags(note.tags), note.attachments.map(a => a.id)]); }
export function matches(note, query, tag = '') {
  const q = query.trim().toLocaleLowerCase();
  return (!tag || note.tags.includes(tag)) && (!q || `${note.text} ${note.tags.join(' ')}`.toLocaleLowerCase().includes(q));
}
export function prepareSave(note, now = new Date().toISOString()) {
  if (!hasContent(note)) throw new Error('写下一点想法，或添加图片、语音后再保存。');
  return { ...note, tags: normalizeTags(note.tags), updatedAt: now };
}

let dbPromise;
export function database() {
  if (!dbPromise) dbPromise = new Promise((resolve, reject) => {
    const request = indexedDB.open('thought-mosaic-web', 1);
    request.onupgradeneeded = () => {
      const db = request.result;
      db.createObjectStore('notes', { keyPath: 'id' });
      db.createObjectStore('drafts', { keyPath: 'id' });
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => { dbPromise = null; reject(request.error); };
    request.onblocked = () => { dbPromise = null; reject(new Error('请先关闭其他 Thought Mosaic 标签页，再重新打开。')); };
  });
  return dbPromise;
}
async function transaction(stores, mode, action) {
  const db = await database();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(stores, mode);
    let result;
    tx.oncomplete = () => resolve(typeof result === 'function' ? result() : result);
    tx.onerror = tx.onabort = () => reject(tx.error || new Error('浏览器存储未完成，请重试。'));
    result = action(tx);
  });
}
export async function readArchive() {
  return transaction(['notes', 'drafts'], 'readonly', tx => {
    const n = tx.objectStore('notes').getAll(), d = tx.objectStore('drafts').getAll();
    return () => ({ notes: n.result.sort((a,b) => b.updatedAt.localeCompare(a.updatedAt)), drafts: d.result.sort((a,b) => b.updatedAt.localeCompare(a.updatedAt)) });
  });
}
export async function putDraft(note, baseUpdatedAt) {
  return transaction(['drafts'], 'readwrite', tx => tx.objectStore('drafts').put({ ...note, updatedAt: new Date().toISOString(), baseUpdatedAt }));
}
export async function removeDraft(id) { return transaction(['drafts'], 'readwrite', tx => tx.objectStore('drafts').delete(id)); }
export async function saveNote(note, expectedUpdatedAt = null) {
  const saved = prepareSave(note);
  const db = await database();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(['notes', 'drafts'], 'readwrite');
    let conflict = false;
    const request = tx.objectStore('notes').get(note.id);
    request.onsuccess = () => {
      if ((request.result?.updatedAt ?? null) !== expectedUpdatedAt) { conflict = true; tx.abort(); return; }
      tx.objectStore('notes').put(saved);
      tx.objectStore('drafts').delete(note.id);
    };
    tx.oncomplete = () => resolve(saved);
    tx.onerror = tx.onabort = () => reject(conflict ? new Error('这条记录已在另一个标签页更新。当前修改已保留为草稿，请重新打开后核对。') : tx.error);
  });
}
export async function deleteNote(id) { return transaction(['notes', 'drafts'], 'readwrite', tx => { tx.objectStore('notes').delete(id); tx.objectStore('drafts').delete(id); }); }
export async function importNotes(notes) {
  return transaction(['notes'], 'readwrite', tx => {
    // A restored copy gets a fresh ID, so import never overwrites existing work.
    for (const note of notes) tx.objectStore('notes').put({ ...note, id: crypto.randomUUID() });
  });
}
