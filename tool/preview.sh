#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")/.."
if [ ! -f build/web/index.html ]; then
  flutter pub get
  flutter build web --release --no-web-resources-cdn
fi
printf 'Open http://127.0.0.1:8765 in your browser. Press Ctrl+C to stop.\n'
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/web
