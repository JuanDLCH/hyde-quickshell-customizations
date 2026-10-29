#!/usr/bin/env python3
"""JSON bridge for the Quickshell calendar. Reads the cache backend.py maintains.

  calendar_json.py snapshot [YYYY-MM-DD ...]   print state as JSON
  calendar_json.py select <calendar-id> <0|1>  toggle a calendar
"""
import datetime as dt, json, sys
import backend as B

SPAN_DAYS = 130  # about two months either side of today covers any month the UI can show between syncs

def event_view(e):
    if e.get('all_day'):
        start = end = ''
    else:
        start, end = [B.stamp({'dateTime': e[k]}).astimezone(B.TZ).strftime('%H:%M') for k in ('start', 'end')]
    return {
        'title': e['title'], 'calendar': e['calendar_name'], 'color': e['color'], 'allDay': bool(e.get('all_day')),
        'start': start, 'end': end, 'location': e.get('location') or '', 'video': bool(e.get('video')),
        'conference': e.get('conference') or '', 'attendees': e.get('attendees') or 0,
        'description': e.get('description') or '', 'videoUrl': e.get('video_url') or '', 'htmlLink': e.get('html_link') or '',
        'organizer': e.get('organizer') or '', 'date': e.get('date_start') or e['start'][:10],
    }

def snapshot(center):
    B.directories()
    connected = B.connected()
    calendars, events = B.snapshot() if connected else ([], [])
    days = {}
    for i in range(-SPAN_DAYS, SPAN_DAYS + 1):
        day = center + dt.timedelta(days=i)
        found = B.for_day(events, day)
        if found:
            days[day.isoformat()] = [event_view(e) for e in found]
    return {
        'connected': connected, 'hasClient': (B.CONFIG / 'client.json').exists(),
        'error': B.meta('error', '') or '', 'lastSync': float(B.meta('last_sync', 0) or 0),
        'today': dt.datetime.now(B.TZ).date().isoformat(),
        'calendars': [{'id': c['id'], 'name': c['name'], 'color': c['color'], 'selected': bool(c.get('selected', 1))} for c in calendars],
        'days': days,
    }

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'snapshot'
    if cmd == 'snapshot':
        center = dt.date.fromisoformat(sys.argv[2]) if len(sys.argv) > 2 else dt.datetime.now(B.TZ).date()
        print(json.dumps(snapshot(center)))
    elif cmd == 'select':
        with B.db() as c:
            c.execute('UPDATE calendars SET selected=? WHERE id=?', (int(sys.argv[3]), sys.argv[2]))
    return 0

if __name__ == '__main__':
    sys.exit(main())
