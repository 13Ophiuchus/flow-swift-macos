#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "==> Swift version"
swift --version

echo "==> Cleaning build artifacts"
swift package clean

echo "==> Resolving dependencies"
swift package resolve

echo "==> Running full test suite"
swift test --parallel

echo "==> Done"
