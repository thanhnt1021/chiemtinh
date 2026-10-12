#!/bin/bash
# Xuất AppIcon.appiconset từ một file SVG trong thư mục này.
#   bash ios/design/logo/render-appicon.sh                       -> dùng phương án mặc định (C)
#   bash ios/design/logo/render-appicon.sh logo-a-banh-xe.svg    -> đổi sang phương án khác
#
# Công cụ: qlmanage (WebKit, có sẵn macOS) để rasterise SVG, magick để thu nhỏ và BỎ ALPHA.
# Icon iOS không được có alpha, nên mọi PNG đều đi qua "-alpha remove -alpha off"
# rồi verify lại bằng sips.
set -euo pipefail

SVG_NAME="${1:-logo-c-astrolabe.svg}"
HERE="$(cd "$(dirname "$0")" && pwd)"
IOS_ROOT="$(cd "$HERE/../.." && pwd)"
SVG="$HERE/$SVG_NAME"
SET="$IOS_ROOT/ChiemTinh/Src/Assets.xcassets/AppIcon.appiconset"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -f "$SVG" ] || { echo "KHONG THAY $SVG"; exit 1; }
command -v qlmanage >/dev/null || { echo "thieu qlmanage"; exit 1; }
command -v magick   >/dev/null || { echo "thieu magick (brew install imagemagick)"; exit 1; }

echo "== Nguon: $SVG_NAME"
mkdir -p "$SET"

# 1) SVG -> PNG 1024 (qlmanage đặt tên là <ten>.svg.png)
qlmanage -t -s 1024 -o "$TMP" "$SVG" >/dev/null 2>&1
BASE="$TMP/$SVG_NAME.png"
[ -f "$BASE" ] || { echo "qlmanage khong render duoc"; exit 1; }

# 2) Xuất mọi cỡ Xcode cần cho iPhone + ô 1024 của App Store.
#    Nền đặc lấy đúng màu trời đêm của logo nên không hở viền khi bỏ alpha.
GROUND='#070B18'
for S in 40 58 60 80 87 120 180 1024; do
  magick "$BASE" -background "$GROUND" -alpha remove -alpha off \
    -filter Lanczos -resize "${S}x${S}" -strip \
    "PNG24:$SET/icon-$S.png"
done

# 3) Verify: mọi PNG phải đúng kích thước và hasAlpha: no
echo "== Verify"
FAIL=0
for S in 40 58 60 80 87 120 180 1024; do
  OUT=$(sips -g pixelWidth -g pixelHeight -g hasAlpha "$SET/icon-$S.png")
  W=$(echo "$OUT" | awk '/pixelWidth/{print $2}')
  H=$(echo "$OUT" | awk '/pixelHeight/{print $2}')
  A=$(echo "$OUT" | awk '/hasAlpha/{print $2}')
  printf "  icon-%-4s %sx%s hasAlpha=%s" "$S.png" "$W" "$H" "$A"
  if [ "$W" != "$S" ] || [ "$H" != "$S" ] || [ "$A" != "no" ]; then
    echo "   <-- SAI"; FAIL=1
  else
    echo "   OK"
  fi
done
[ "$FAIL" = 0 ] || { echo "CO FILE SAI CHUAN"; exit 1; }

# 4) Contents.json — bộ iPhone đầy đủ + ô ios-marketing 1024
cat > "$SET/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon-40.png",   "idiom" : "iphone", "scale" : "2x", "size" : "20x20" },
    { "filename" : "icon-60.png",   "idiom" : "iphone", "scale" : "3x", "size" : "20x20" },
    { "filename" : "icon-58.png",   "idiom" : "iphone", "scale" : "2x", "size" : "29x29" },
    { "filename" : "icon-87.png",   "idiom" : "iphone", "scale" : "3x", "size" : "29x29" },
    { "filename" : "icon-80.png",   "idiom" : "iphone", "scale" : "2x", "size" : "40x40" },
    { "filename" : "icon-120.png",  "idiom" : "iphone", "scale" : "3x", "size" : "40x40" },
    { "filename" : "icon-120.png",  "idiom" : "iphone", "scale" : "2x", "size" : "60x60" },
    { "filename" : "icon-180.png",  "idiom" : "iphone", "scale" : "3x", "size" : "60x60" },
    { "filename" : "icon-1024.png", "idiom" : "ios-marketing", "scale" : "1x", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

echo "== Da ghi $SET"
ls -1 "$SET"
