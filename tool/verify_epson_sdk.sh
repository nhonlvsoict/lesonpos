#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

missing=()
check_file() {
  local rel="$1"
  if [[ ! -f "${ROOT_DIR}/${rel}" ]]; then
    missing+=("$rel")
  fi
}

check_file android/app/libs/ePOS2.jar
check_file android/app/src/main/jniLibs/arm64-v8a/libepos2.so
check_file android/app/src/main/jniLibs/armeabi-v7a/libepos2.so
check_file android/app/src/main/jniLibs/x86_64/libepos2.so

if [[ ${#missing[@]} -eq 0 ]]; then
  echo "All Epson ePOS2 SDK binaries are present."
else
  echo "Missing Epson ePOS2 SDK binaries:" >&2
  for path in "${missing[@]}"; do
    echo "  - $path" >&2
  done
  echo >&2
  echo "Download the Epson ePOS SDK for Android and copy the files to the paths" >&2
  echo "listed above. See android/README.md for detailed instructions." >&2
  exit 1
fi
