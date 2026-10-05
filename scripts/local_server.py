#!/usr/bin/env python3
"""Install, inspect, or remove the per-user macOS local KMA proxy."""
import argparse
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import time
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
LABEL = 'com.limhiru.weather-api'
SERVICE = Path.home() / 'Library' / 'LaunchAgents' / f'{LABEL}.plist'
DEPLOY = Path.home() / 'Library' / 'Application Support' / 'WeatherLocalServer'
TARGET = f'gui/{os.getuid()}/{LABEL}'
DOMAIN = f'gui/{os.getuid()}'


def run(*args, check=True):
    return subprocess.run(['launchctl', *args], check=check, capture_output=True, text=True)


def health():
    try:
        with urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=2) as response:
            return response.read().decode('utf-8')
    except Exception:
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['install', 'status', 'remove'])
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('This local service uses macOS launchd.')
    if args.action == 'status':
        result = run('print', TARGET, check=False)
        print('Installed:', SERVICE.exists(), 'Running:', result.returncode == 0, 'Health:', health())
        return
    if args.action == 'remove':
        run('bootout', TARGET, check=False)
        SERVICE.unlink(missing_ok=True)
        shutil.rmtree(DEPLOY, ignore_errors=True)
        print('Local weather server service removed. Credential file was not changed.')
        return
    if not (ROOT / 'server/.env').exists():
        parser.error('Create server/.env with KMA_SERVICE_KEY before installing.')
    if SERVICE.exists():
        try:
            current = plistlib.loads(SERVICE.read_bytes())
        except Exception as error:
            parser.error(f'Existing service file is unreadable: {error}')
        if current.get('Label') != LABEL or current.get('WorkingDirectory') not in (str(ROOT), str(DEPLOY)):
            parser.error(f'An unrelated or moved service file exists: {SERVICE}')
        run('bootout', TARGET, check=False)
    SERVICE.parent.mkdir(parents=True, exist_ok=True)
    package = DEPLOY / 'server'
    package.mkdir(parents=True, exist_ok=True)
    for name in ('__init__.py', 'app.py', 'weather.py', '.env'):
        shutil.copy2(ROOT / 'server' / name, package / name)
    (package / '.env').chmod(0o600)
    python_executable = shutil.which('python3') or sys.executable
    config = {
        'Label': LABEL,
        'ProgramArguments': [python_executable, '-m', 'server.app'],
        'WorkingDirectory': str(DEPLOY),
        'RunAtLoad': True,
        'KeepAlive': True,
        'StandardOutPath': '/tmp/weather-server.log',
        'StandardErrorPath': '/tmp/weather-server-error.log',
    }
    SERVICE.write_bytes(plistlib.dumps(config))
    SERVICE.chmod(0o600)
    loaded = run('bootstrap', DOMAIN, str(SERVICE), check=False)
    if loaded.returncode != 0:
        raise SystemExit(f'Could not start local service: {loaded.stderr.strip()}')
    for _ in range(60):
        status = health()
        if status:
            print('Local weather server is running at http://127.0.0.1:8080:', status)
            return
        time.sleep(.5)
    raise SystemExit('Service loaded but health check did not respond; inspect /tmp/weather-server-error.log')


if __name__ == '__main__':
    main()
