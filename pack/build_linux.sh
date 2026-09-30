#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Building Linux Flutter client ==="
cd "$PROJECT_DIR/client_flutter"
flutter pub get
flutter build linux --release

echo "=== Copying to release dir ==="
mkdir -p /mnt/d/release/note123-v1.0.0
cp -r build/linux/x64/release/bundle /mnt/d/release/note123-v1.0.0/note123-linux-x64-v1.0.0

echo "=== Linux build done ==="
ls -la /mnt/d/release/note123-v1.0.0/
