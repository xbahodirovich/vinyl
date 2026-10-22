#!/usr/bin/env python3
"""Register the built app's native messaging host for Chrome or Edge."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import shlex

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--browser', choices=['chrome', 'edge'], default='chrome')
parser.add_argument('--app', type=Path)
parser.add_argument('--uninstall', action='store_true')
args = parser.parse_args()
project = Path(__file__).resolve().parent.parent
directory = Path.home() / 'Library/Application Support' / ('Google/Chrome' if args.browser == 'chrome' else 'Microsoft Edge') / 'NativeMessagingHosts'
manifest_path = directory / 'local.sidea.browser.json'
launcher = directory / 'sidea-host.sh'
if args.uninstall:
    manifest_path.unlink(missing_ok=True)
    launcher.unlink(missing_ok=True)
    print('Removed Vinyl browser bridge. Remove the extension in your browser too.')
else:
    executable = (args.app or project / 'build/Vinyl.app') / 'Contents/MacOS/Vinyl'
    if not executable.is_file():
        parser.error('Build the app first with Scripts/build.sh')
    key = json.loads((project / 'BrowserExtension/manifest.json').read_text())['key']
    digest = hashlib.sha256(base64.b64decode(key)).hexdigest()[:32]
    extension_id = ''.join(chr(ord('a') + int(char, 16)) for char in digest)
    directory.mkdir(parents=True, exist_ok=True)
    launcher.write_text('#!/bin/sh\nexec ' + shlex.quote(str(executable.resolve())) + ' --native-host "$@"\n')
    launcher.chmod(0o755)
    manifest_path.write_text(json.dumps({
        'name': 'local.sidea.browser', 'description': 'Vinyl Yandex Music bridge',
        'path': str(launcher), 'type': 'stdio',
        'allowed_origins': ['chrome-extension://' + extension_id + '/']
    }, indent=2) + '\n')
    print('Bridge registered for ' + args.browser + '. Load BrowserExtension as an unpacked extension, then reload Yandex Music.')
