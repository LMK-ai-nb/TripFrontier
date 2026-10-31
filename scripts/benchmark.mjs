import {performance} from 'node:perf_hooks';
import {writeFileSync,mkdirSync} from 'node:fs';
import {cpus} from 'node:os';
import {route_request} from '../dist/engine.js';
const stops=Array.from({length:40},(_,i)=>({id:`s${i}`,name:`Stop ${i}`,min_change:60,accessible:true}));
const trips=[];
for(let wave=0;wave<24;wave++)for(let corridor=0;corridor<8;corridor++){
  const calls=[];
  for(let j=0;j<=5&&corridor*5+j<40;j++){
    const at=28800+corridor*500+wave*600+j*70;
    calls.push({stop:`s${corridor*5+j}`,arrival:at,departure:at,pickup:true,dropoff:true});
  }
  trips.push({id:`c${corridor}-w${wave}`,calls,accessible:true,cancelled:false,delay:0});
}
const footpaths=Array.from({length:39},(_,i)=>({id:`walk-${i}`,from:`s${i}`,to:`s${i+1}`,duration:250,accessible:true}));
const source=JSON.stringify({schema_version:1,timetable:{name:'synthetic-corridors',stops,trips,footpaths},query:{from:'s0',to:'s39',departure:28800,max_boardings:8,max_walk:900}});
for(let i=0;i<2;i++)route_request(source);
let report;const samples=[];
for(let i=0;i<7;i++){const t=performance.now();report=JSON.parse(route_request(source));samples.push(performance.now()-t);}
if(report.error||!report.complete||report.journeys.length===0)throw Error(JSON.stringify(report));
samples.sort((a,b)=>a-b);
const result={date:'2026-10-31',runtime:process.version,platform:process.platform,cpu:cpus()[0]?.model,
  stops:40,trips:trips.length,calls:trips.reduce((sum,t)=>sum+t.calls.length,0),footpaths:39,
  warmups:2,samples_ms:samples,median_ms:samples[3],labels:report.labels,work:report.work,journeys:report.journeys.length,
  includes:'JSON parsing, validation, network indexing, routing, witness construction, serialization and JS result parsing',
  limitations:'One synthetic network and one query; no real-feed, memory, worst-case or national-scale throughput claim.'};
mkdirSync('artifacts',{recursive:true});writeFileSync('artifacts/benchmark.json',JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
