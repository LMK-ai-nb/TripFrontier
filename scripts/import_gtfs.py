"""Compile a documented, strict static GTFS subset into one service-day timetable.

No third-party Python packages. Unsupported semantics are rejected, never flattened.
This is a schedule adapter; journey search remains in MoonBit.
"""
import argparse, csv, datetime as dt, io, json, pathlib, re

class ImportError(ValueError):
    pass

def integer(value, field, maximum=259199):
    if not re.fullmatch(r"[0-9]+", value or ""):
        raise ImportError(f"{field}: expected a nonnegative decimal integer")
    v=int(value)
    if v>maximum: raise ImportError(f"{field}: value exceeds limit")
    return v

def clock(value):
    if not re.fullmatch(r"[0-9]{1,2}:[0-9]{2}:[0-9]{2}", value or ""):
        raise ImportError("arrival/departure requires explicit H[H]:MM:SS; interpolation is unsupported")
    h,m,s=map(int,value.split(':'))
    if h>71 or m>59 or s>59: raise ImportError("invalid service-day time")
    return h*3600+m*60+s

def read_table(root, name, required=(), optional=False):
    path=root/name
    if not path.exists():
        if optional:return []
        raise ImportError(f"missing {name}")
    if path.stat().st_size>16777216:raise ImportError(f"{name}: file exceeds 16 MiB")
    source=path.read_text(encoding='utf-8-sig')
    reader=csv.reader(io.StringIO(source,newline=''),strict=True)
    try:header=next(reader)
    except StopIteration:raise ImportError(f"{name}: missing header")
    if len(header)!=len(set(header)) or any(not h for h in header):raise ImportError(f"{name}: duplicate/empty header")
    if not set(required).issubset(header):raise ImportError(f"{name}: missing required columns")
    result=[]
    for row in reader:
        if not row or not any(row):continue
        if len(row)!=len(header):raise ImportError(f"{name}: malformed row width")
        result.append(dict(zip(header,row)))
        if len(result)>100000:raise ImportError(f"{name}: row limit exceeded")
    return result

def unique(rows,key,name):
    result={}
    for row in rows:
        value=row[key]
        if not value or len(value)>128 or value in result:raise ImportError(f"{name}: empty, long or duplicate {key}")
        result[value]=row
    return result

def flag(row,name,default='0'):
    value=row.get(name,default) or default
    if value not in {'0','1','2'}:raise ImportError(f"invalid {name}")
    return value

def load_gtfs(directory, service_date, change=0):
    root=pathlib.Path(directory)
    date=dt.date.fromisoformat(service_date)
    if not 0<=change<=86400:raise ImportError("default change must be 0..86400")
    stamp=date.strftime('%Y%m%d')
    calendar=read_table(root,'calendar.txt',('service_id','start_date','end_date','monday','tuesday','wednesday','thursday','friday','saturday','sunday'),optional=True)
    exceptions=read_table(root,'calendar_dates.txt',('service_id','date','exception_type'),optional=True)
    if not calendar and not exceptions:raise ImportError("calendar.txt or calendar_dates.txt must define the selected service date")
    active=set();known_services=set();calendar_ids=set()
    weekday=['monday','tuesday','wednesday','thursday','friday','saturday','sunday'][date.weekday()]
    for row in calendar:
        sid=row['service_id']
        if not sid or sid in calendar_ids:raise ImportError("duplicate or empty calendar service")
        calendar_ids.add(sid);known_services.add(sid)
        for field in ['start_date','end_date']:
            if not re.fullmatch(r'\d{8}',row[field]):raise ImportError('calendar date must be YYYYMMDD')
            dt.datetime.strptime(row[field],'%Y%m%d')
        if row['start_date']>row['end_date']:raise ImportError('calendar range reversed')
        for day in ['monday','tuesday','wednesday','thursday','friday','saturday','sunday']:
            if row[day] not in {'0','1'}:raise ImportError('invalid weekday flag')
        if row['start_date']<=stamp<=row['end_date'] and row[weekday]=='1':active.add(sid)
    seen=set()
    for row in exceptions:
        sid=row['service_id'];key=(sid,row['date'])
        if not sid or key in seen:raise ImportError('duplicate or empty calendar exception')
        seen.add(key);known_services.add(sid)
        if not re.fullmatch(r'\d{8}',row['date']):raise ImportError('invalid calendar exception date')
        dt.datetime.strptime(row['date'],'%Y%m%d')
        if row['exception_type'] not in {'1','2'}:raise ImportError('invalid calendar exception type')
        if row['date']==stamp:
            if row['exception_type']=='1':active.add(sid)
            else:active.discard(sid)
    stops=unique(read_table(root,'stops.txt',('stop_id','stop_name')),'stop_id','stops')
    trips=unique(read_table(root,'trips.txt',('trip_id','service_id','route_id')),'trip_id','trips')
    if not 1<=len(stops)<=512:raise ImportError('subset limit: 1..512 stops')
    for name in ['frequencies.txt','pathways.txt']:
        if read_table(root,name,optional=True):raise ImportError(name+' semantics are not supported by this adapter')
    agency=read_table(root,'agency.txt',optional=True)
    zones={a.get('agency_timezone','') for a in agency}
    if len(zones)>1:raise ImportError('multiple agency timezones are unsupported')
    output_stops=[]
    for sid,s in stops.items():
        location=s.get('location_type','') or '0'
        if location not in {'0','1'}:raise ImportError('only stop/platform and station locations are supported')
        parent=s.get('parent_station','')
        if parent and (parent not in stops or parent==sid):raise ImportError('unknown or self-referencing parent station')
        if parent and ((stops[parent].get('location_type','') or '0')!='1' or location=='1'):
            raise ImportError('parent must be a station; nested stations unsupported')
        if len(s['stop_name'])>256:raise ImportError('stop name exceeds core limit')
        access=flag(s,'wheelchair_boarding')
        if access=='0' and parent:access=flag(stops[parent],'wheelchair_boarding')
        output_stops.append({'id':sid,'name':s['stop_name'],'min_change':change,'accessible':access=='1'})
    indexed_stops={s['id']:s for s in output_stops}
    calls={}
    for tid,t in trips.items():
        if t['service_id'] not in known_services:raise ImportError('trip references undefined service')
        if t.get('block_id',''):raise ImportError('block interlining is unsupported; select non-interlined trips')
        flag(t,'wheelchair_accessible')
        if t['service_id'] in active:calls[tid]=[]
    seen=set()
    rows=read_table(root,'stop_times.txt',('trip_id','stop_id','stop_sequence','arrival_time','departure_time'))
    for row in rows:
        tid=row['trip_id']
        if tid not in trips or row['stop_id'] not in stops:raise ImportError('stop_time references unknown trip/stop')
        seq=integer(row['stop_sequence'],'stop_sequence',2000000);key=(tid,seq)
        if key in seen:raise ImportError('duplicate stop sequence')
        seen.add(key)
        if tid not in calls:continue
        if (stops[row['stop_id']].get('location_type','') or '0')!='0':raise ImportError('stop_time must reference a platform/stop')
        for f in ['start_pickup_drop_off_window','end_pickup_drop_off_window','location_group_id','location_id','pickup_booking_rule_id','drop_off_booking_rule_id']:
            if row.get(f,''):raise ImportError('flexible/booking stop semantics unsupported')
        pickup=row.get('pickup_type','') or '0';dropoff=row.get('drop_off_type','') or '0'
        if pickup not in {'0','1'} or dropoff not in {'0','1'}:raise ImportError('on-demand pickup/drop-off unsupported')
        for f in ['continuous_pickup','continuous_drop_off']:
            if row.get(f,'') not in {'','1'}:raise ImportError('continuous pickup/drop-off unsupported')
        calls[tid].append((seq,{'stop':row['stop_id'],'arrival':clock(row['arrival_time']),
            'departure':clock(row['departure_time']),'pickup':pickup=='0','dropoff':dropoff=='0'}))
    output_trips=[];total=0
    for tid,values in calls.items():
        values.sort(key=lambda x:x[0]);seq=[c for _,c in values]
        if not 2<=len(seq)<=128:raise ImportError('active trip requires 2..128 explicit stop times')
        total+=len(seq)
        previous=0
        for c in seq:
            if not previous<=c['arrival']<=c['departure']:raise ImportError('nonmonotonic stop times')
            previous=c['departure']
        output_trips.append({'id':tid,'calls':seq,'accessible':flag(trips[tid],'wheelchair_accessible')=='1','cancelled':False,'delay':0})
    if len(output_trips)>2048 or total>20000:raise ImportError('service day exceeds trip/call capacity')
    links=[];seen=set()
    for row in read_table(root,'transfers.txt',('from_stop_id','to_stop_id','transfer_type'),optional=True):
        if any(row.get(f,'') for f in ['from_trip_id','to_trip_id','from_route_id','to_route_id']):raise ImportError('route/trip-specific transfers unsupported')
        a,b=row['from_stop_id'],row['to_stop_id']
        if a not in stops or b not in stops or (a,b) in seen:raise ImportError('unknown or duplicate transfer pair')
        seen.add((a,b))
        if row['transfer_type']!='2':raise ImportError('only explicit minimum-time transfers (type 2) are supported')
        seconds=integer(row.get('min_transfer_time',''),'min_transfer_time',86400)
        if a==b:indexed_stops[a]['min_change']=max(indexed_stops[a]['min_change'],seconds)
        else:
            if seconds==0:raise ImportError('walking link must have positive duration')
            # GTFS transfer type 2 does not prove physical wheelchair accessibility.
            links.append({'id':f'transfer-{len(links)}','from':a,'to':b,'duration':seconds,'accessible':False})
    if len(links)>4096:raise ImportError('too many transfers')
    result={'name':root.name+' / '+service_date,'stops':output_stops,'trips':output_trips,'footpaths':links}
    metadata={'service_date':service_date,'active_services':sorted(active),'agency_timezone':next(iter(zones),None),
        'contract':'static-explicit-stop-times-v1','default_change_seconds':change,
        'unverified_transfer_links_accessible':False,'data_source':str(root.resolve()),
        'notes':['No street geometry, inferred walking links, route fares, multi-service-day union, or realtime feed fetching.',
                 'Distinct-stop transfer durations are walking; the arrival stop min_change is additionally required after a prior boarding.']}
    return result,metadata

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('directory');p.add_argument('--date',required=True);p.add_argument('--change',type=int,default=0);p.add_argument('--out',required=True)
    args=p.parse_args()
    try:
        t,meta=load_gtfs(args.directory,args.date,args.change)
        output=pathlib.Path(args.out);output.parent.mkdir(parents=True,exist_ok=True)
        output.write_text(json.dumps(t,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        output.with_suffix('.metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(json.dumps({'trips':len(t['trips']),'stops':len(t['stops']),'service_date':args.date,'output':str(output)},ensure_ascii=False))
    except (ValueError,OSError,csv.Error) as e:p.exit(2,str(e)+'\n')

if __name__=='__main__':main()
