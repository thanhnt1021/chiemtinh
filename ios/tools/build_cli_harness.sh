#!/bin/bash
# Biên dịch CLI đối chiếu cho macOS (chạy nhanh, cùng mã nguồn Swift với app iOS).
set -e
IOS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-/tmp/chiemtinh_swift_harness}"
WORK="$(mktemp -d)"
C_DIR="$IOS_DIR/ChiemTinh/Src/CSwissEph"

echo "== Biên dịch libswe (C) =="
for f in "$C_DIR"/*.c; do
  clang -c -O2 -I"$C_DIR" -Wno-everything -o "$WORK/$(basename "$f" .c).o" "$f"
done
ar rcs "$WORK/libswe.a" "$WORK"/*.o

echo "== Biên dịch Swift =="
swiftc -O \
  -import-objc-header "$C_DIR/ChiemTinh-Bridging-Header.h" \
  -I "$C_DIR" \
  "$IOS_DIR/ChiemTinh/Src/Core/"*.swift \
  "$IOS_DIR/tools/SwiftHarness/main.swift" \
  "$WORK/libswe.a" \
  -o "$OUT"
echo "== Xong: $OUT =="
