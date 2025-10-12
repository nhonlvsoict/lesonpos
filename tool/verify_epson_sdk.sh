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

all_ok=true
if [[ ${#missing[@]} -eq 0 ]]; then
  echo "All Epson ePOS2 SDK binaries are present."
else
  all_ok=false
  echo "Missing Epson ePOS2 SDK binaries:" >&2
  for path in "${missing[@]}"; do
    echo "  - $path" >&2
  done
  echo >&2
  echo "Download the Epson ePOS SDK for Android and copy the files to the paths" >&2
  echo "listed above. See android/README.md for detailed instructions." >&2
fi

gradle_file="${ROOT_DIR}/android/app/build.gradle"
if [[ ! -f "${gradle_file}" ]]; then
  all_ok=false
  echo "android/app/build.gradle is missing. Add the Flutter module build script with the Epson dependency." >&2
else
  if ! grep -q "implementation files('libs/ePOS2.jar')" "${gradle_file}"; then
    all_ok=false
    echo "android/app/build.gradle does not declare implementation files('libs/ePOS2.jar')." >&2
  else
    echo "android/app/build.gradle contains the required Epson dependency."
  fi
fi

if [[ ${all_ok} == true ]]; then
  exit 0
else
  exit 1
fi
