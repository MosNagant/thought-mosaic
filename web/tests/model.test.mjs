import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeTags, newNote, hasContent, signature, matches, prepareSave } from '../dist/model.js';

test('empty and tag-only notes cannot be saved; audio-only notes can', () => {
  const note = newNote(); note.text = '  \n '; note.tags = ['灵感'];
  assert.equal(hasContent(note), false);
  assert.throws(() => prepareSave(note));
  note.attachments.push({ id: 'audio', kind: 'audio', blob: new Blob(['audio']) });
  assert.equal(hasContent(note), true);
  assert.equal(prepareSave(note).attachments.length, 1);
});
test('normalize Chinese and mixed-case tags without splitting Unicode characters', () => {
  assert.deepEqual(normalizeTags([' 灵感 ', '灵感', 'Art', 'ART', '', '😀'.repeat(25)]), ['灵感', 'Art', '😀'.repeat(24)]);
});
test('search finds text and tags together with tag filters', () => {
  const note = { ...newNote(), text: '街角的两个人\nA moment', tags: ['绘画参考'] };
  assert.equal(matches(note, ' moment '), true);
  assert.equal(matches(note, '绘画', '绘画参考'), true);
  assert.equal(matches(note, '两个人', '日常生活'), false);
});
test('dirty state detects cleared content, tag changes and attachment removals', () => {
  const note = { ...newNote(), text: '你好', attachments: [{ id: 'photo', kind: 'image' }] };
  const original = signature(note);
  assert.equal(signature(structuredClone(note)), original);
  assert.notEqual(signature({ ...note, text: '' }), original);
  assert.notEqual(signature({ ...note, attachments: [] }), original);
  assert.notEqual(signature({ ...note, tags: ['参考'] }), original);
});
test('save preserves creation date and attachment blobs, normalizes tags without mutating input', () => {
  const note = { ...newNote(), text: '原型测试', tags: [' 参考 ', '参考'], attachments: [{ id: 'p', blob: new Blob(['image']) }] };
  const saved = prepareSave(note, '2026-10-26T12:00:00.000Z');
  assert.equal(saved.createdAt, note.createdAt);
  assert.equal(saved.updatedAt, '2026-10-26T12:00:00.000Z');
  assert.deepEqual(saved.tags, ['参考']);
  assert.equal(note.tags.length, 2);
  assert.equal(saved.attachments[0].blob, note.attachments[0].blob);
});
