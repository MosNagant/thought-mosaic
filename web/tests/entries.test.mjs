import test from 'node:test';
import assert from 'node:assert/strict';
import { isUpwardSwipe, ENTRY_ORDER } from '../dist/entries.js';
const start = [{x:10,y:200},{x:60,y:205},{x:110,y:200}];
test('all four prototype entry routes are available',()=>assert.deepEqual(ENTRY_ORDER,['a1','a2','b','c']));
test('requires three fingers moving up together, not taps or horizontal scrolls',()=>{
  assert.equal(isUpwardSwipe(start,start.map(p=>({x:p.x+10,y:p.y-100})),500),true);
  assert.equal(isUpwardSwipe(start,start,100),false);
  assert.equal(isUpwardSwipe(start,start.map(p=>({x:p.x+150,y:p.y-100})),500),false);
  assert.equal(isUpwardSwipe(start,start.map(p=>({x:p.x,y:p.y+100})),500),false);
  assert.equal(isUpwardSwipe(start.slice(0,2),start.slice(0,2),100),false);
  assert.equal(isUpwardSwipe(start,start.map(p=>({x:p.x,y:p.y-100})),3000),false);
});
test('desktop drag uses an explicit single-pointer simulation',()=>{
  assert.equal(isUpwardSwipe([{x:10,y:150}],[{x:10,y:50}],500),false);
  assert.equal(isUpwardSwipe([{x:10,y:150}],[{x:10,y:50}],500,1),true);
});
