import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {route_request} from '../dist/engine.js';
const root=resolve(import.meta.dirname,'..');
const source=name=>readFileSync(resolve(root,'examples',name),'utf8');
const scores=r=>r.journeys.map(j=>[j.arrival,j.boardings,j.walked]);
const run=(args,input)=>spawnSync(process.execPath,['bin/tripfrontier.mjs',...args],{cwd:root,input,encoding:'utf8'});
test('commuter frontier and delay-induced missed transfer',()=>{
  const r=JSON.parse(route_request(source('commute.json')));
  assert.deepEqual(scores(r),[[30600,2,0],[31200,1,0]]);
  const request=JSON.parse(source('commute.json'));
  request.scenario={updates:[{id:'local',delay:61,cancelled:false}]};
  assert.deepEqual(scores(JSON.parse(route_request(JSON.stringify(request)))),[[31200,1,0]]);
});
test('accessibility and walking are independent constraints',()=>{
  const request=JSON.parse(source('accessible.json'));
  const r=JSON.parse(route_request(JSON.stringify(request)));
  assert.deepEqual(scores(r),[[30600,1,240]]);
  request.query.accessible=false;
  assert.deepEqual(scores(JSON.parse(route_request(JSON.stringify(request)))),[[30000,1,60]]);
});
test('night service retains service-day times beyond midnight',()=>{
  const r=JSON.parse(route_request(source('overnight.json')));
  assert.deepEqual(scores(r),[[87000,2,0],[88200,1,0]]);
});
test('raw duplicate keys, exact-looking fractions and unknown fields reject',()=>{
  const original=source('commute.json');
  for(const malformed of [original.replace('"schema_version": 1','"schema_version": 1,"schema_versio\\u006e":1'),original.replace('"departure": 28800','"departure": 28800.000000000000000001'),original.replace('"departure": 28800','"departure": 2.88e4'),original.replace('"max_walk": 0','"max_wlak":0')]){
    assert.equal(JSON.parse(route_request(malformed)).error.code,'INVALID_INPUT');
  }
});
test('search-limit response never exposes a partial frontier',()=>{
  const req=JSON.parse(source('commute.json'));req.query.max_labels=1;
  const r=JSON.parse(route_request(JSON.stringify(req)));
  assert.equal(r.error.code,'SEARCH_LIMIT');assert.equal(r.journeys,undefined);
});
test('CLI help, file/stdin, output export and exit statuses',()=>{
  assert.equal(run(['--help']).status,0);
  assert.equal(run(['examples/commute.json']).status,0);
  assert.equal(run(['-'],source('overnight.json')).status,0);
  assert.equal(run(['missing.json']).status,2);
  assert.equal(run(['-'],'{').status,2);
  const req=JSON.parse(source('commute.json'));req.query.latest=28800;
  assert.equal(run(['-'],JSON.stringify(req)).status,1);
  const dir=mkdtempSync(resolve(tmpdir(),'tripfrontier-'));
  try{const file=resolve(dir,'r.json');const p=run(['examples/commute.json','--out',file]);assert.equal(p.status,0);assert.deepEqual(JSON.parse(readFileSync(file,'utf8')),JSON.parse(p.stdout));}
  finally{rmSync(dir,{recursive:true,force:true});}
});
test('Unicode, separators and markup are opaque IDs in the public bridge',()=>{
  const req=JSON.parse(source('commute.json'));const id='<img src=x onerror=alert(1)>汉字/🔧';
  req.timetable.trips[0].id=id;
  const r=JSON.parse(route_request(JSON.stringify(req)));
  assert.equal(r.journeys[0].legs[0].id,id);
});
