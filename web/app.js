import {route_request} from './engine.js';
const $=id=>document.getElementById(id);
const node=(tag,value,cls)=>{const n=document.createElement(tag);n.textContent=value;if(cls)n.className=cls;return n;};
const svg=(tag,attrs={},value)=>{const n=document.createElementNS('http://www.w3.org/2000/svg',tag);for(const [k,v] of Object.entries(attrs))n.setAttribute(k,v);if(value!==undefined)n.textContent=value;return n;};
let base,report,selected=0,current;
const time=seconds=>`${String(Math.floor(seconds/3600)).padStart(2,'0')}:${String(Math.floor(seconds%3600/60)).padStart(2,'0')}:${String(seconds%60).padStart(2,'0')}`;
const name=id=>base?.timetable.stops.find(s=>s.id===id)?.name||id;
function error(message){
  report=null;$('error').hidden=false;$('error').textContent=message;
  $('journeys').replaceChildren();$('diagram').replaceChildren();$('export').disabled=true;
  for(const id of ['earliest','alternatives','trip-count','search-state'])$(id).textContent='—';
  $('result-count').textContent='未生成结果';$('work-count').textContent='';
}
function draw(journey){
  const panel=$('diagram');panel.replaceChildren();
  if(!journey){panel.append(node('p','在给定班次和约束中没有可行行程。','empty'));return;}
  const legs=journey.legs,points=[current.query.from,...legs.map(l=>l.to)];
  const s=svg('svg',{viewBox:'0 0 670 124',role:'img','aria-label':'所选行程的接驳和乘车示意图'});panel.append(s);
  const x=i=>45+(points.length===1?0:i/(points.length-1)*580);
  legs.forEach((l,i)=>{
    s.append(svg('line',{x1:x(i),x2:x(i+1),y1:56,y2:56,stroke:l.kind==='walk'?'#9fae8c':'#315c63','stroke-width':l.kind==='walk'?3:7,'stroke-dasharray':l.kind==='walk'?'5 5':''}));
    s.append(svg('text',{x:(x(i)+x(i+1))/2,y:29,'text-anchor':'middle'},l.kind==='walk'?`接驳 ${l.arrival-l.departure}s`:l.id));
  });
  points.forEach((p,i)=>{
    s.append(svg('circle',{cx:x(i),cy:56,r:8,fill:'#fdfdf9',stroke:'#315c63','stroke-width':3}));
    s.append(svg('text',{x:x(i),y:88,'text-anchor':'middle'},name(p)));
    const at=i===0?current.query.departure:legs[i-1].arrival;
    s.append(svg('text',{x:x(i),y:108,'text-anchor':'middle'},time(at)));
  });
}
function render(){
  $('error').hidden=true;$('export').disabled=false;
  const journeys=report.journeys;$('earliest').textContent=journeys.length?time(journeys[0].arrival):'无方案';
  $('alternatives').textContent=journeys.length;$('trip-count').textContent=base.timetable.trips.length;
  $('search-state').textContent='完整';$('result-count').textContent=`${journeys.length} 个方案`;
  $('work-count').textContent=`${report.labels} 个标签 / ${report.work} 次候选操作`;
  $('journeys').replaceChildren();
  if(!journeys.length)$('journeys').append(node('p','没有找到满足当前限制的行程。可以调整出发时间、上车次数或接驳预算。','empty'));
  journeys.forEach((j,i)=>{
    const card=node('article','',`journey ${i===selected?'selected':''}`);card.tabIndex=0;card.setAttribute('role','button');card.setAttribute('aria-label',`选择 ${time(j.arrival)} 到达的行程`);
    const summary=node('div','','journey-summary'),arrival=node('div',time(j.arrival),'arrival-time');arrival.append(node('small','到达'));
    const scores=node('div','','journey-score');scores.append(node('span',`${j.boardings} 次上车`,'score-chip primary-score'),node('span',`接驳 ${j.walked} 秒`,'score-chip'),node('span',`${Math.round((j.arrival-report.query.departure)/60)} 分钟`,'score-chip'));
    summary.append(arrival,scores);card.append(summary);
    const chain=node('div','','legs');
    j.legs.forEach((leg,index)=>{if(index)chain.append(node('span','→','leg-arrow'));chain.append(node('span',leg.kind==='walk'?`${name(leg.from)} → ${name(leg.to)}`:leg.id,leg.kind==='walk'?'walk-badge':'ride-badge'));});
    if(!j.legs.length)chain.append(node('span','已在目的地','walk-badge'));
    card.append(chain,node('div',j.legs.map(l=>`${name(l.from)} ${time(l.departure)} → ${name(l.to)} ${time(l.arrival)}`).join('  ·  '),'leg-detail'));
    const choose=()=>{selected=i;render();};card.onclick=choose;card.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();choose();}};
    $('journeys').append(card);
  });
  draw(journeys[selected]);
}
function load(source){
  const result=JSON.parse(route_request(source));
  if(result.error){error(result.error.message);return;}
  base=JSON.parse(source);current=structuredClone(base);report=result;selected=0;
  for(const id of ['origin','destination']){$(id).replaceChildren();for(const s of base.timetable.stops){const option=node('option',s.name||s.id);option.value=s.id;$(id).append(option);}}
  $('origin').value=result.query.from;$('destination').value=result.query.to;$('departure').value=time(result.query.departure);
  $('boardings').value=result.query.max_boardings;$('walk-budget').value=result.query.max_walk;$('access').checked=result.query.accessible;
  $('trip').replaceChildren();for(const t of base.timetable.trips){const option=node('option',t.id);option.value=t.id;$('trip').append(option);}
  $('delay').value=0;$('cancel').checked=false;render();
}
function calculate(){
  if(!base)return;
  const spelling=$('departure').value;
  if(!/^\d{1,2}:[0-5]\d:[0-5]\d$/.test(spelling)){error('请输入 HH:MM:SS 格式的服务日时间。');return;}
  const parts=spelling.split(':').map(Number),departure=parts[0]*3600+parts[1]*60+parts[2];
  const input=structuredClone(base);input.query={...input.query,from:$('origin').value,to:$('destination').value,departure,max_boardings:Number($('boardings').value),max_walk:Number($('walk-budget').value),accessible:$('access').checked};
  const id=$('trip').value;
  if(id){
    const updates=input.scenario?.updates?.filter(u=>u.id!==id)||[];
    updates.push({id,delay:Number($('delay').value),cancelled:$('cancel').checked});
    input.scenario={...input.scenario,updates};
  }
  const result=JSON.parse(route_request(JSON.stringify(input)));
  if(result.error){error(result.error.message);return;}
  report=result;current=input;selected=0;render();
}
async function example(file){
  try{const response=await fetch(`data/${file}`);if(!response.ok)throw Error('示例加载失败');const source=await response.text();$('source').value=source;load(source);document.querySelectorAll('[data-example]').forEach(b=>b.classList.toggle('selected',b.dataset.example===file));}
  catch(e){error(e.message);}
}
for(const b of document.querySelectorAll('[data-example]'))b.onclick=()=>example(b.dataset.example);
for(const id of ['origin','destination','departure','boardings','walk-budget','access','delay','cancel'])$(id).addEventListener('change',calculate);
$('trip').onchange=()=>{const trip=base.timetable.trips.find(t=>t.id===$('trip').value);$('delay').value=trip?.delay||0;$('cancel').checked=trip?.cancelled||false;calculate();};
$('calculate').onclick=calculate;
$('apply-source').onclick=()=>{load($('source').value);document.querySelectorAll('[data-example]').forEach(b=>b.classList.remove('selected'));};
$('export').onclick=()=>{if(!report)return;const link=document.createElement('a'),url=URL.createObjectURL(new Blob([JSON.stringify({request:current,report},null,2)+'\n'],{type:'application/json'}));link.href=url;link.download='tripfrontier-report.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),2000);};
example('commute.json');
