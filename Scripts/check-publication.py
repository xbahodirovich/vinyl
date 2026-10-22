#!/usr/bin/env python3
"""Check Git-publishable files without printing potentially sensitive content.

A targeted guardrail, not a comprehensive secret scanner. Run before committing.
"""
import re
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PATTERNS = {
    'private key': re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----'),
    'GitHub token': re.compile(rb'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})'),
    'AWS access key': re.compile(rb'(?:AKIA|ASIA)[A-Z0-9]{16}'),
    'service secret': re.compile(rb'\bsk-(?:proj-)?[A-Za-z0-9_-]{32,}'),
    'personal macOS path': re.compile(rb'/Users/[A-Za-z0-9_.-]+/'),
    'email address': re.compile(rb'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'),
}
FORBIDDEN_PARTS = {'.env', '.DS_Store', '__pycache__', '.swiftpm', '.impeccable', '.local', '.codex', '.agents', 'xcuserdata'}
FORBIDDEN_SUFFIXES = {'.pem', '.key', '.p12', '.pfx', '.mobileprovision', '.provisionprofile', '.dmg', '.pyc'}

def publishable_files():
    result = subprocess.run(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT, check=True, capture_output=True)
    return sorted(set(p.decode() for p in result.stdout.split(b'\0') if p))

def inspect():
    findings = []
    paths = publishable_files()
    # Detect accidental nested repository gitlinks; vendored sources must be regular files.
    staged = subprocess.run(['git', 'ls-files', '--stage'], cwd=ROOT, check=True, capture_output=True, text=True).stdout
    for line in staged.splitlines():
        if line.startswith('160000 '): findings.append((line.split('\t')[-1], 'embedded repository/gitlink'))
    for name in paths:
        path = ROOT / name
        if not path.is_file(): continue
        if any(part in FORBIDDEN_PARTS for part in path.relative_to(ROOT).parts) or path.suffix in FORBIDDEN_SUFFIXES:
            findings.append((name, 'private/generated file selected for publication'))
        data = path.read_bytes()
        # Raw scan also catches personal paths in PNG text chunks and compiled icons.
        for label, pattern in PATTERNS.items():
            if pattern.search(data): findings.append((name, label))
    for name, reason in findings: print(f'FAIL {name}: {reason}')
    if findings: return 1
    print(f'Publication checks passed: {len(paths)} publishable files; no targeted secret/path patterns found.')
    print('Review the staged diff too. This check cannot prove that a repository contains no secrets.')
    return 0

if __name__ == '__main__': sys.exit(inspect())
