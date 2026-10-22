#!/usr/bin/env python3
"""Reject release bundles containing common local home-directory paths."""
import re
import sys
from pathlib import Path

app = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/Vinyl.app')
if not app.is_dir():
    raise SystemExit('App bundle missing; build first.')
pattern = re.compile(rb'/(?:Users|home)/[A-Za-z0-9_.-]+/')
findings = [str(p.relative_to(app)) for p in app.rglob('*') if p.is_file() and pattern.search(p.read_bytes())]
if findings:
    for name in findings:
        print('FAIL local home path in bundle: ' + name)
    raise SystemExit(1)
print('Bundle privacy check passed: no home-directory paths found.')
