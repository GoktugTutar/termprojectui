#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  FLUTTER_HOME="${VERCEL_TEMP:-/tmp}/flutter"
  if [ ! -d "$FLUTTER_HOME" ]; then
    git clone https://github.com/flutter/flutter.git --branch stable --depth 1 "$FLUTTER_HOME"
  fi
  export PATH="$PATH:$FLUTTER_HOME/bin"
fi

flutter --version
flutter pub get
flutter build web --release --dart-define=API_BASE_URL="${API_BASE_URL:-}"
