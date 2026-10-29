"""Private Google Calendar read-only cache and reminder delivery. No UI polling."""
from __future__ import annotations
import calendar, contextlib, datetime as dt, fcntl, hashlib, json, os, pathlib, sqlite3, subprocess, sys, tempfile, urllib.parse
from zoneinfo import ZoneInfo
os.umask(0o077)
def _local_zone():
    # System timezone: $TZ, else the /etc/localtime symlink target, else UTC.
    name = os.environ.get('TZ') or ''
    if not name:
        with contextlib.suppress(OSError):
            name = os.path.realpath('/etc/localtime').split('/zoneinfo/', 1)[-1]
    try: return ZoneInfo(name)
    except Exception: return ZoneInfo('UTC')
TZ = _local_zone()
CONFIG = pathlib.Path(os.environ.get('XDG_CONFIG_HOME', pathlib.Path.home()/'.config'))/'hyde-calendar'
STATE = pathlib.Path(os.environ.get('XDG_STATE_HOME', pathlib.Path.home()/'.local/state'))/'hyde-calendar'
SCOPES = ['https://www.googleapis.com/auth/calendar.calendarlist.readonly', 'https://www.googleapis.com/auth/calendar.events.readonly']
API = 'https://www.googleapis.com/calendar/v3/'
class CalendarError(Exception): pass

def directories():
    for p in (CONFIG, STATE):
        p.mkdir(parents=True, exist_ok=True, mode=0o700)
        if p.stat().st_mode & 0o777 != 0o700:p.chmod(0o700)

def atomic_json(path, value):
    directories()
    fd, name = tempfile.mkstemp(dir=path.parent, prefix='.pending-')
    try:
        with os.fdopen(fd, 'w') as f: json.dump(value, f); f.flush(); os.fsync(f.fileno())
        os.replace(name, path); path.chmod(0o600)
    finally:
        if os.path.exists(name): os.unlink(name)

@contextlib.contextmanager
def db():
    directories(); c=sqlite3.connect(STATE/'calendar.sqlite', timeout=20); c.row_factory=sqlite3.Row
    c.executescript('''
    CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT);
    CREATE TABLE IF NOT EXISTS calendars(id TEXT PRIMARY KEY,name TEXT,color TEXT,timezone TEXT,selected INTEGER,reminders TEXT);
    CREATE TABLE IF NOT EXISTS events(calendar TEXT,id TEXT,data TEXT,start REAL,end REAL,PRIMARY KEY(calendar,id));
    CREATE TABLE IF NOT EXISTS coverage(calendar TEXT,month TEXT,event TEXT,PRIMARY KEY(calendar,month,event));
    CREATE TABLE IF NOT EXISTS sent(key TEXT PRIMARY KEY,delivered REAL);
    ''')
    if (STATE/'calendar.sqlite').stat().st_mode & 0o777 != 0o600:(STATE/'calendar.sqlite').chmod(0o600)
    try:
        yield c
        c.commit()
    except Exception:
        c.rollback();raise
    finally:c.close()

def meta(key, default=None):
    with db() as c:
        r=c.execute('SELECT value FROM meta WHERE key=?',(key,)).fetchone()
    return r[0] if r else default

def set_meta(key,value):
    with db() as c: c.execute('INSERT OR REPLACE INTO meta VALUES(?,?)',(key,str(value)))

def connected(): return (CONFIG/'token.json').exists()

def import_client(path):
    # Read only when explicitly selected by the user, never print its contents.
    data=json.loads(pathlib.Path(path).read_text())
    conf=data.get('installed',{})
    if not conf.get('client_id') or not conf.get('client_secret'): raise CalendarError('Choose a Desktop app OAuth JSON file.')
    if conf.get('auth_uri') != 'https://accounts.google.com/o/oauth2/auth' or conf.get('token_uri') != 'https://oauth2.googleapis.com/token':
        raise CalendarError('OAuth endpoints must belong to Google.')
    atomic_json(CONFIG/'client.json',data)

def authorize():
    from google_auth_oauthlib.flow import InstalledAppFlow
    if not (CONFIG/'client.json').exists(): raise CalendarError('Select your Desktop OAuth JSON first.')
    with open(CONFIG/'client.json') as f: config=json.load(f)
    flow=InstalledAppFlow.from_client_config(config,SCOPES,autogenerate_code_verifier=True)
    credentials=flow.run_local_server(host='127.0.0.1',bind_addr='127.0.0.1',port=0,
        authorization_prompt_message='',success_message='Calendar connected. You may close this tab.',
        open_browser=True,timeout_seconds=180,access_type='offline',prompt='consent')
    atomic_json(CONFIG/'token.json',json.loads(credentials.to_json()))

def session():
    from google.oauth2.credentials import Credentials
    from google.auth.transport.requests import AuthorizedSession, Request
    if not connected(): raise CalendarError('Google Calendar is not connected.')
    with open(CONFIG/'token.json') as f: saved=json.load(f)
    credentials=Credentials.from_authorized_user_info(saved,SCOPES)
    if credentials.expired:
        try: credentials.refresh(Request())
        except Exception: raise CalendarError('Google authorization expired or network unavailable. Reconnect if needed.') from None
        atomic_json(CONFIG/'token.json',json.loads(credentials.to_json()))
    return AuthorizedSession(credentials)

def api_pages(http,path,params=None):
    params=dict(params or {})
    while True:
        response=http.get(API+path,params=params,timeout=25)
        if response.status_code==429 or response.status_code>=500: raise CalendarError('Google is temporarily unavailable. Cached events are preserved.')
        if response.status_code in (401,403): raise CalendarError('Google access denied. Check API access and authorization.')
        if not response.ok: raise CalendarError('Google Calendar request failed. Cached events are preserved.')
        result=response.json(); yield result
        token=result.get('nextPageToken')
        if not token: break
        params['pageToken']=token

def shift_month(month,delta):
    y,m=map(int,month.split('-')); total=y*12+m-1+delta; return f'{total//12:04d}-{total%12+1:02d}'

def month_bounds(month):
    y,m=map(int,month.split('-')); start=dt.datetime(y,m,1,tzinfo=TZ); end=dt.datetime.fromisoformat(shift_month(month,1)+'-01').replace(tzinfo=TZ); return start,end

def stamp(part,timezone=str(TZ)):
    if 'dateTime' in part:
        value=dt.datetime.fromisoformat(part['dateTime'].replace('Z','+00:00'))
        return value.replace(tzinfo=ZoneInfo(part.get('timeZone',timezone))) if value.tzinfo is None else value
    return dt.datetime.fromisoformat(part['date']).replace(tzinfo=ZoneInfo(timezone))

def clean_text(value,limit=4000):
    # Google descriptions may carry light HTML; keep readable text and make links plain.
    import html,re
    value=re.sub(r'<br\s*/?>|</p>|</div>|</li>','\n',value or '',flags=re.I)
    value=re.sub(r'<a\s[^>]*href="([^"]+)"[^>]*>.*?</a>',r'\1',value,flags=re.I|re.S)
    value=html.unescape(re.sub(r'<[^>]+>','',value))
    return re.sub(r'\n{3,}','\n\n',value).strip()[:limit]

def normalize(event,cal,defaults):
    start,end=stamp(event['start'],cal['timezone']),stamp(event['end'],cal['timezone'])
    settings=event.get('reminders',{}); reminders=defaults if settings.get('useDefault',False) else settings.get('overrides',[])
    offsets=sorted({int(r['minutes']) for r in reminders if r.get('method')=='popup' and 0<=int(r.get('minutes',-1))<=40320})
    conference=event.get('conferenceData',{}); video=any(p.get('entryPointType')=='video' for p in conference.get('entryPoints',[]))
    return {'id':event['id'],'calendar':cal['id'],'title':event.get('summary') or '(Untitled event)',
        'start':start.isoformat(),'end':end.isoformat(),'all_day':'date' in event['start'],
        'date_start':event['start'].get('date'),'date_end':event['end'].get('date'),
        'location':event.get('location',''),'video':video,'conference':conference.get('conferenceSolution',{}).get('name',''),
        'attendees':len([a for a in event.get('attendees',[]) if a.get('responseStatus')!='declined']),
        'reminders':offsets,
        'description':clean_text(event.get('description','')),
        'video_url':next((p.get('uri','') for p in conference.get('entryPoints',[]) if p.get('entryPointType')=='video'),'') or event.get('hangoutLink',''),
        'html_link':event.get('htmlLink',''),
        'organizer':(event.get('organizer') or {}).get('displayName') or (event.get('organizer') or {}).get('email','')}

def sync(requested=None,http=None):
    directories()
    with open(STATE/'sync.lock','a') as lock:
        try: fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError: return
        if not connected() and http is None: return
        http=http or session(); today=dt.datetime.now(TZ).strftime('%Y-%m')
        requested=requested or meta('requested_month',today)
        # Fixed rolling cache plus a requested month, never fetch years between them.
        months=sorted({shift_month(today,i) for i in (-1,0,1,2)} | {shift_month(requested,i) for i in (-1,0,1)})
        try:
            calendars=[x for page in api_pages(http,'users/me/calendarList',{'maxResults':250}) for x in page.get('items',[])]
            with db() as c:
                old={r['id']:r['selected'] for r in c.execute('SELECT id,selected FROM calendars')}
                ids=[]
                for raw in calendars:
                    cid=raw['id']; ids.append(cid)
                    c.execute('INSERT OR REPLACE INTO calendars VALUES(?,?,?,?,?,?)',(cid,raw.get('summaryOverride',raw.get('summary','Calendar')),raw.get('backgroundColor','#8b86d6'),raw.get('timeZone','America/Bogota'),old.get(cid,int(raw.get('selected',True))),json.dumps(raw.get('defaultReminders',[]))))
                for previous in list(old):
                    if previous not in ids:
                        c.execute('DELETE FROM calendars WHERE id=?',(previous,));c.execute('DELETE FROM coverage WHERE calendar=?',(previous,));c.execute('DELETE FROM events WHERE calendar=?',(previous,))
                selected=[dict(x) for x in c.execute('SELECT * FROM calendars WHERE selected=1')]
            for cal in selected:
                for month in months:
                    lo,hi=month_bounds(month); fetched=[]
                    params={'timeMin':lo.isoformat(),'timeMax':hi.isoformat(),'singleEvents':'true','showDeleted':'false','timeZone':'America/Bogota','maxResults':2500,'orderBy':'startTime'}
                    for page in api_pages(http,'calendars/'+urllib.parse.quote(cal['id'],safe='')+'/events',params):
                        defaults=page.get('defaultReminders',json.loads(cal['reminders']))
                        for raw in page.get('items',[]):
                            if raw.get('status')=='cancelled' or 'start' not in raw or 'end' not in raw: continue
                            fetched.append(normalize(raw,cal,defaults))
                    # Replace coverage only after every page of this month succeeds.
                    with db() as c:
                        c.execute('DELETE FROM coverage WHERE calendar=? AND month=?',(cal['id'],month))
                        for event in fetched:
                            c.execute('INSERT OR REPLACE INTO events VALUES(?,?,?,?,?)',(cal['id'],event['id'],json.dumps(event),stamp({'dateTime':event['start']}).timestamp(),stamp({'dateTime':event['end']}).timestamp()))
                            c.execute('INSERT OR REPLACE INTO coverage VALUES(?,?,?)',(cal['id'],month,event['id']))
                        c.execute('DELETE FROM events WHERE calendar=? AND id NOT IN (SELECT event FROM coverage WHERE calendar=?)',(cal['id'],cal['id']))
                with db() as c:
                    placeholders=','.join('?' for _ in months)
                    c.execute(f'DELETE FROM coverage WHERE calendar=? AND month NOT IN ({placeholders})',[cal['id'],*months])
                    c.execute('DELETE FROM events WHERE calendar=? AND id NOT IN (SELECT event FROM coverage WHERE calendar=?)',(cal['id'],cal['id']))
            set_meta('last_sync',dt.datetime.now().timestamp());set_meta('error','')
        except CalendarError as e: set_meta('error',str(e));raise
        except Exception: set_meta('error','Sync unavailable. Your cached events are preserved.');raise CalendarError('Sync unavailable. Your cached events are preserved.') from None
        finally:
            if hasattr(http,'credentials'):atomic_json(CONFIG/'token.json',json.loads(http.credentials.to_json()))
            if hasattr(http,'close'): http.close()

def snapshot():
    with db() as c:
        calendars=[dict(x) for x in c.execute('SELECT * FROM calendars ORDER BY name')]
        events=[json.loads(x[0]) for x in c.execute('SELECT e.data FROM events e JOIN calendars c ON c.id=e.calendar WHERE c.selected=1')]
    lookup={c['id']:c for c in calendars}
    for event in events:
        c=lookup[event['calendar']];event.update(calendar_name=c['name'],color=c['color'])
    return calendars,events

def for_day(events,day):
    lo=dt.datetime.combine(day,dt.time(),TZ);hi=lo+dt.timedelta(days=1)
    found=[];seen=set()
    for e in events:
        key=(e['calendar'],e['id'])
        if key in seen: continue
        if e.get('all_day'): visible=e['date_start']<=day.isoformat()<e['date_end']
        else: visible=stamp({'dateTime':e['start']})<hi and stamp({'dateTime':e['end']})>lo
        if visible:found.append(e);seen.add(key)
    return sorted(found,key=lambda e:(not e.get('all_day'),e['start'],e['title']))

def remind(now=None,deliver=None):
    now=now or dt.datetime.now(TZ).timestamp()
    # Never announce potentially cancelled events from a long-stale cache.
    if now-float(meta('last_sync',0))>900:return 0
    calendars,events=snapshot();sent=0
    for e in events:
        start=stamp({'dateTime':e['start']}).timestamp()
        for offset in e.get('reminders',[]):
            due=start-offset*60
            if not now-120<=due<=now:continue
            key=hashlib.sha256(json.dumps([e['calendar'],e['id'],start,offset]).encode()).hexdigest()
            with db() as c:
                claimed=c.execute('INSERT OR IGNORE INTO sent VALUES(?,?)',(key,now)).rowcount
            if not claimed:continue
            when='All day' if e.get('all_day') else stamp({'dateTime':e['start']}).astimezone(TZ).strftime('%H:%M')
            try:
                if deliver:deliver(e,when)
                else:subprocess.run(['notify-send','--app-name','HyDE Calendar','--icon','x-office-calendar','--urgency','normal','--',e['title'],when+' · '+e['calendar_name']],check=True,timeout=10,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
                sent+=1
            except Exception:
                with db() as c:c.execute('DELETE FROM sent WHERE key=?',(key,))
    return sent

def main():
    command=sys.argv[1] if len(sys.argv)>1 else 'sync'
    try:
        if command=='sync':sync(sys.argv[2] if len(sys.argv)>2 else None)
        elif command=='remind':remind()
        elif command=='auth':authorize();sync()
        elif command=='import-client':import_client(sys.argv[2])
        else:raise CalendarError('Unknown calendar command.')
    except CalendarError as e:
        if command=='auth':set_meta('error','Authorization did not complete. Review Google consent and reconnect.')
        print(str(e),file=sys.stderr);return 1
    except Exception:
        if command=='auth':set_meta('error','Authorization did not complete. Review Google consent and reconnect.')
        print('Calendar operation failed; private details were not logged.',file=sys.stderr);return 1
    return 0
if __name__=='__main__':sys.exit(main())
