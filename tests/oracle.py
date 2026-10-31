"""Independent exhaustive walk/boarding enumeration: no label dominance pruning.

Enumerates complete bounded journeys on small synthetic timetables, then applies
all-pairs Pareto filtering to score triples. This is not an industrial benchmark.
"""
import json, pathlib, random, subprocess
ROOT=pathlib.Path(__file__).resolve().parent.parent

def reference(request):
    t=request['timetable'];q=request['query'];stop={s['id']:s for s in t['stops']}
    maximum=q.get('max_boardings',4);max_walk=q.get('max_walk',1800);latest=q.get('latest',259199)
    access=q.get('accessible',False);scores=set();visits=0
    def visit(at,time,boardings,walked):
        nonlocal visits
        visits+=1
        assert visits<200000,'oracle scenario too large'
        if at==q['to']:scores.add((time,boardings,walked));return
        for f in t['footpaths']:
            if f['from']!=at or walked+f['duration']>max_walk or time+f['duration']>latest:continue
            if access and (not f['accessible'] or not stop[f['to']]['accessible']):continue
            visit(f['to'],time+f['duration'],boardings,walked+f['duration'])
        if boardings>=maximum:return
        ready=time+(stop[at]['min_change'] if boardings else 0)
        for trip in t['trips']:
            if trip['cancelled'] or (access and not trip['accessible']):continue
            calls=trip['calls'];delay=trip['delay']
            for i,c in enumerate(calls[:-1]):
                if c['stop']!=at or not c['pickup'] or c['departure']+delay<ready:continue
                if access and not stop[at]['accessible']:continue
                for d in calls[i+1:]:
                    end=d['arrival']+delay
                    if not d['dropoff'] or end>latest:continue
                    if access and not stop[d['stop']]['accessible']:continue
                    visit(d['stop'],end,boardings+1,walked)
    if not access or (stop[q['from']]['accessible'] and stop[q['to']]['accessible']):visit(q['from'],q['departure'],0,0)
    result=sorted(s for s in scores if not any(other!=s and all(a<=b for a,b in zip(other,s)) for other in scores))
    return result,visits

def cases():
    rng=random.Random(20261031);result=[]
    for i in range(240):
        stops=[{'id':c,'name':c,'min_change':rng.randrange(3),'accessible':rng.random()>.15} for c in 'ABCD']
        trips=[]
        for j in range(5):
            times=sorted(rng.sample(range(1,24),3));ids=[rng.choice('ABCD') for _ in range(3)]
            calls=[{'stop':s,'arrival':time,'departure':time,'pickup':rng.random()>.15,'dropoff':rng.random()>.15} for s,time in zip(ids,times)]
            trips.append({'id':str(j),'calls':calls,'accessible':rng.random()>.2,'cancelled':rng.random()<.1,'delay':rng.randrange(3)})
        links=[]
        for j,(a,b) in enumerate([('A','B'),('B','A'),('B','D'),('C','D')]):
            if rng.random()>.4:links.append({'id':str(j),'from':a,'to':b,'duration':rng.randrange(1,4),'accessible':rng.random()>.2})
        q={'from':'A','to':'D','departure':rng.randrange(4),'latest':26,'max_boardings':2,'max_walk':4,'accessible':i%3==0}
        result.append({'schema_version':1,'timetable':{'name':f'generated-{i}','stops':stops,'trips':trips,'footpaths':links},'query':q})
    return result

def main():
    requests=cases();process=subprocess.run(['node','tests/oracle_bridge.mjs'],cwd=ROOT,input=json.dumps(requests),text=True,capture_output=True,encoding='utf-8',check=True)
    results=json.loads(process.stdout);visits=0;journeys=0
    for index,(request,actual) in enumerate(zip(requests,results)):
        assert 'error' not in actual,(index,actual)
        expected,count=reference(request);visits+=count
        scores=sorted((j['arrival'],j['boardings'],j['walked']) for j in actual['journeys']);journeys+=len(scores)
        assert scores==expected,(index,scores,expected,request)
    print(json.dumps({'cases':len(requests),'exhaustive_states':visits,'returned_journeys':journeys,'seed':20261031,'result':'all score frontiers match independent exhaustive enumeration'}))

if __name__=='__main__':main()
