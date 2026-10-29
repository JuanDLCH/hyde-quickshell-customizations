#!/usr/bin/env python3
"""One-shot MPRIS actions: existing playerctld selects the active player."""
import sys
from gi.repository import Gio, GLib
ACTIONS = {'previous': ('CanGoPrevious', 'Previous'), 'next': ('CanGoNext', 'Next'), 'play-pause': (None, 'PlayPause')}
if len(sys.argv) != 2 or sys.argv[1] not in ACTIONS:
    raise SystemExit(2)
try:
    proxy = Gio.DBusProxy.new_for_bus_sync(Gio.BusType.SESSION, Gio.DBusProxyFlags.DO_NOT_AUTO_START, None,
        'org.mpris.MediaPlayer2.playerctld', '/org/mpris/MediaPlayer2', 'org.mpris.MediaPlayer2.Player', None)
    capability, method = ACTIONS[sys.argv[1]]
    if capability is None:
        status = proxy.get_cached_property('PlaybackStatus')
        capability = 'CanPause' if status and status.unpack() == 'Playing' else 'CanPlay'
    allowed = proxy.get_cached_property(capability)
    control = proxy.get_cached_property('CanControl')
    if allowed and allowed.unpack() and (control is None or control.unpack()):
        proxy.call_sync(method, None, Gio.DBusCallFlags.NONE, 1500, None)
except GLib.Error:
    # Missing player/capability or a player disappearing between lookup and click.
    pass
