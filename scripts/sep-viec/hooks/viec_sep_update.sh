#!/usr/bin/env bash
# mo-phien (SessionStart): kéo sổ + in tin chưa đọc ≤6 dòng + nhắc bật con canh.
# không tham số (UserPromptSubmit): «check viec sep» → chèn quy trình + moi; câu khác chỉ đọc tệp trạng thái canh (không gọi mạng).
# LUÔN exit 0 — hook không bao giờ chặn câu gõ.
DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
TT="$DIR/.claude/sep-viec/trang-thai.json"; PID="$DIR/.claude/sep-viec/canh.pid"; NHAC="$DIR/.claude/sep-viec/da-nhac.txt"
CLI="python3 scripts/sep-viec/sep_viec.py"
canh_song(){ [ -f "$PID" ] && kill -0 "$(cat "$PID" 2>/dev/null)" 2>/dev/null; }
[ -n "${SEP_VIEC_URL:-}" ] || grep -q "^SEP_VIEC_URL=" "$DIR/.env" 2>/dev/null || exit 0   # máy chủ chưa dựng xong thì im
if [ "${1:-}" = "mo-phien" ]; then
  cd "$DIR" || exit 0
  keo=$($CLI keo 2>&1 | head -n 1); moi=$($CLI moi 2>&1)
  so=$(printf '%s\n' "$moi" | grep -c '^#[0-9]')
  echo "[Việc sếp] ${keo:-(không kéo được sổ)} · $so tin chưa đọc (mới nhất ở dưới, đủ: $CLI moi)"
  printf '%s\n' "$moi" | grep '^📋 DUYỆT LƯỢT'   # 7e: lượt duyệt cần máy luôn hiện, không bị cắt
  printf '%s\n' "$moi" | grep -v '^→' | grep -v '^📋 DUYỆT LƯỢT' | tail -n 5
  canh_song && echo "[Việc sếp] Con canh đang chạy." \
            || echo "[Việc sếp] Bật con canh NỀN (run_in_background, timeout 7200000): $CLI canh"
  exit 0
fi
prompt=$(python3 -c "import sys,json
try: print(json.load(sys.stdin).get('prompt',''))
except Exception: pass" 2>/dev/null)
if printf '%s' "$prompt" | grep -qiE 'check[[:space:]]+(viec|việc)[[:space:]]+(sep|sếp)'; then
  echo "⚡ LỆNH \"check viec sep\" → làm ĐÚNG .claude/commands/check-viec-sep.md. Tin chưa đọc lúc này:"
  (cd "$DIR" && $CLI moi 2>&1) || echo "(không lấy được — tự chạy: $CLI moi)"
  exit 0
fi
[ -f "$TT" ] || exit 0
ids=$(python3 -c "import json,sys
try: print(','.join(map(str,json.load(open(sys.argv[1])).get('ids',[]))))
except Exception: pass" "$TT" 2>/dev/null)
dl=$(python3 -c "import json,sys
try:
  d=json.load(open(sys.argv[1])).get('duyet_luot')
  print('DL%s %s' % (d['id'], d['trang_thai']) if d else '')
except Exception: pass" "$TT" 2>/dev/null)
if [ -n "$dl" ] && [ "$dl" != "$(cat "$NHAC.dl" 2>/dev/null)" ]; then
  echo "[Việc sếp] 📋 Lượt duyệt $dl đang cần máy — làm mục «Duyệt lượt» trong .claude/commands/check-viec-sep.md."
  printf '%s' "$dl" > "$NHAC.dl"
fi
if [ -n "$ids" ] && [ "$ids" != "$(cat "$NHAC" 2>/dev/null)" ]; then
  echo "[Việc sếp] Còn tin sếp chưa đọc (#${ids//,/, #}) — gõ «check viec sep» khi rảnh."
  printf '%s' "$ids" > "$NHAC"
fi
exit 0
