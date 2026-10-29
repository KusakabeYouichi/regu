#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME_PATH="$ROOT_DIR/régu.xcodeproj/xcshareddata/xcschemes/régu.xcscheme"

if [[ ! -f "$SCHEME_PATH" ]]; then
  exit 0
fi

# Keep scheme identifiers in NFC/precomposed form to avoid noisy diffs (écritu と同じ対策)
perl -CSDA -i -pe 's/(?:e&#x301;|e&#769;|&#x[eE]9;|&#233;|e\x{301}|Ã©|é)gu\.xcodeproj/\x{E9}gu.xcodeproj/g; s/r(?:e&#x301;|e&#769;|&#x[eE]9;|&#233;|e\x{301}|Ã©|é)gu"/r\x{E9}gu"/g' "$SCHEME_PATH"
