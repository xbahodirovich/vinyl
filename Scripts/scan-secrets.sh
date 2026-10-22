#!/bin/bash
# Scan exactly the files Git would publish, not ignored local diagnostics.
set -euo pipefail
cd "$(dirname "$0")/.."
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)
    PLATFORM=darwin_arm64
    SHA256=b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5 ;;
  Darwin-x86_64)
    PLATFORM=darwin_x64
    SHA256=dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709 ;;
  *) echo 'This pinned scanner bootstrap currently supports macOS only.' >&2; exit 1 ;;
esac
SCAN_DIR=$(mktemp -d "${TMPDIR:-/tmp}/vinyl-secret-scan.XXXXXX")
trap 'rm -rf "$SCAN_DIR"' EXIT
curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
  "https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_${PLATFORM}.tar.gz" \
  --output "$SCAN_DIR/gitleaks.tar.gz"
printf '%s  %s\n' "$SHA256" "$SCAN_DIR/gitleaks.tar.gz" | shasum -a 256 -c -
tar -xzf "$SCAN_DIR/gitleaks.tar.gz" -C "$SCAN_DIR" gitleaks
python3 - "$SCAN_DIR/source" <<'PY'
import shutil
import subprocess
import sys
from pathlib import Path
root = Path.cwd().resolve()
target = Path(sys.argv[1])
target.mkdir()
files = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'])
for name in sorted(set(files.split(b'\0'))):
    if not name:
        continue
    relative = Path(name.decode())
    source = root / relative
    if source.is_symlink():
        raise SystemExit('Refusing symlink in publication snapshot: ' + str(relative))
    if source.is_file():
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
PY
"$SCAN_DIR/gitleaks" dir "$SCAN_DIR/source" --config "$PWD/.gitleaks.toml" --redact --no-banner
