#!/usr/bin/env python3
"""User safety layer: no authentication, no live locker termination, no daemons."""
import fcntl
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time


def running():
    r = subprocess.run(['pgrep', '-u', str(os.getuid()), '-x', 'hyprlock'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if r.returncode not in (0, 1):
        raise RuntimeError('Cannot determine locker state; refusing to replace it')
    return r.returncode == 0


def notify(text):
    print(text, file=sys.stderr)
    subprocess.run(['notify-send', '-a', 'HyDE', 'Hyprlock', text], check=False)


def atomic_write(path, text):
    mode = path.stat().st_mode & 0o777
    fd, tmp = tempfile.mkstemp(prefix='.' + path.name + '.', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as f:
            os.fchmod(f.fileno(), mode)
            f.write(text)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def main():
    config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config'))
    state = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state'))
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', '/run/user/' + str(os.getuid()))) / 'hyde'
    if not runtime.is_dir():
        raise RuntimeError('Session runtime directory unavailable')
    action = sys.argv[1]
    selected = None
    if action == '--select':
        if running():
            notify('Unlock normally before changing the lock layout.')
            return 1
        layouts = {}
        for directory in [config / 'hypr/hyprlock', config / 'hyde/hyprlock']:
            if not directory.is_dir():
                continue
            for path in sorted(directory.rglob('*.conf')):
                if path.name == 'theme.conf' or '\n' in path.stem:
                    continue
                if path.stem in layouts:
                    raise RuntimeError('Duplicate layout name; rename it before selecting')
                layouts[path.stem] = path.absolute()
        theme = config / 'hypr/hyprlock/theme.conf'
        if theme.is_file():
            layouts = {'Theme Preference': theme, **layouts}
        if not layouts:
            raise RuntimeError('No layouts found')
        result = subprocess.run([
            'rofi', '-dmenu', '-i', '-p', 'Hyprlock layout',
            '-select', os.environ.get('HYPRLOCK_LAYOUT', ''),
            '-theme', os.environ.get('ROFI_HYPRLOCK_STYLE') or 'clipboard'],
            input='\n'.join(layouts) + '\n', text=True, capture_output=True)
        if result.returncode:
            return 0
        selected = result.stdout.strip()
        if selected not in layouts:
            raise RuntimeError('Choose an existing layout from the list')
    with open(runtime / 'lockscreen-operation.lock', 'a') as guard:
        deadline = time.monotonic() + 5
        while True:
            try:
                fcntl.flock(guard, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if action == '--launch':
                    if running():
                        return 0  # The concurrent request has secured the session.
                    if time.monotonic() < deadline:
                        time.sleep(0.05)
                        continue
                notify('Another lockscreen operation is in progress; retry the request.')
                return 1
        if running():
            if action == '--launch':
                return 0  # Never replace a running authentication conversation.
            notify('Unlock normally before changing the lock configuration.')
            return 1
        if action == '--select':
            main_config = config / 'hypr/hyprlock.conf'
            state_file = state / 'hyde/staterc'
            old_main, old_state = main_config.read_text(), state_file.read_text()
            if len(re.findall(r'^\$LAYOUT_PATH\s*=.*$', old_main, re.M)) != 1:
                raise RuntimeError('Unexpected layout declaration; configuration left intact')
            new_main = re.sub(r'^\$LAYOUT_PATH\s*=.*$',
                              lambda _: '$LAYOUT_PATH=' + str(layouts[selected]), old_main, flags=re.M)
            declaration = 'HYPRLOCK_LAYOUT=' + shlex.quote(selected)
            if re.search(r'^HYPRLOCK_LAYOUT=.*$', old_state, re.M):
                new_state = re.sub(r'^HYPRLOCK_LAYOUT=.*$', lambda _: declaration, old_state, flags=re.M)
            else:
                new_state = old_state.rstrip() + '\n' + declaration + '\n'
            backup_root = state / 'hyde/lock-selector-backups'
            backup_root.mkdir(mode=0o700, parents=True, exist_ok=True)
            backup = Path(tempfile.mkdtemp(prefix=time.strftime('%Y%m%d-%H%M%S-'), dir=backup_root))
            shutil.copy2(main_config, backup / 'hyprlock.conf')
            shutil.copy2(state_file, backup / 'staterc')
            atomic_write(main_config, new_main)
            try:
                atomic_write(state_file, new_state)
            except Exception:
                atomic_write(main_config, old_main)
                raise
            notify('Layout saved: ' + selected + '. It will apply on the next normal lock.')
            return 0
        if action not in ('--launch', '--edit'):
            raise RuntimeError('Unknown operation')
        started = time.monotonic()
        result = subprocess.run(sys.argv[2:])
        if result.returncode == 0 and action == '--launch' and time.monotonic() - started < 1:
            # Keep concurrent wrappers serialized through asynchronous scope startup.
            for _ in range(20):
                if running():
                    break
                time.sleep(0.1)
        return result.returncode


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError) as error:
        print('Hyprlock safety layer: ' + str(error), file=sys.stderr)
        sys.exit(1)
