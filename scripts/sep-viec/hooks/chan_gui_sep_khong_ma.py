#!/usr/bin/env python3
# Chặn mọi lệnh gửi vào nhóm sếp mà không đi qua CLI hoặc không có mã việc (oHa-…; mã cũ Task-… vẫn tính).
# Vì sao: tin gửi bằng sendMessage thẳng không có mã → sếp trả lời sẽ không vào sổ việc (skill bot-nhan-viec luật 6.3).
# Thêm (mục 7e.8): thợ (subagent) không được chạy THẬT `phuong-an` / `ap-phuong-an` — chỉ `--thu` hoặc kho thử cục bộ;
# duyệt lượt là việc của phiên chính, chủ nhà OK mới làm.
import json, os, re, sys


def tien_to_du_an():
    """Đa dự án (W47 21/10/2026): tiền tố mã đọc từ SEP_VIEC_DU_AN trong .env của dự án; thiếu = oHa (mã cũ Task-… vẫn tính)."""
    goc = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    t = os.environ.get("SEP_VIEC_DU_AN") or ""
    try:
        for d in open(os.path.join(goc, ".env"), encoding="utf-8"):
            if not t and d.strip().startswith("SEP_VIEC_DU_AN="):
                t = d.split("=", 1)[1].strip().strip('"').strip("'")
    except Exception:
        pass
    return t if re.fullmatch(r"[A-Za-z]{2,10}", t or "") else "oHa"


TIEN_TO = tien_to_du_an()
NGUON_MA = "oHa|Task" if TIEN_TO == "oHa" else re.escape(TIEN_TO)

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if d.get("tool_name") != "Bash":
    sys.exit(0)
cmd = d.get("tool_input", {}).get("command", "")

la_tho = bool(d.get("agent_id")) or "/subagents/" in str(d.get("transcript_path") or "")
if la_tho and re.search(r"sep_viec\.py\s+(phuong-an|ap-phuong-an)\b", cmd) and "--thu" not in cmd \
        and not re.search(r"SEP_VIEC_URL=['\"]?http://(127\.0\.0\.1|localhost)", cmd):
    print("⛔ Thợ không chạy thật phuong-an / ap-phuong-an (skill bot-nhan-viec 7e.8) — chỉ --thu hoặc kho thử cục bộ.\n"
          "Duyệt lượt là việc của phiên chính: chủ nhà OK phương án thì phiên chính mới áp.", file=sys.stderr)
    sys.exit(2)

gui_tg = re.search(r"send(Message|MediaGroup|Document|Photo)", cmd) and ("api.telegram.org" in cmd or "TG_CHAT_SEP" in cmd)
# Nhắn riêng chủ nhà được phép (không phải nhóm sếp).
if not gui_tg or "sep_viec.py" in cmd or "TG_CHU_NHA_ID" in cmd or re.search(r"(" + NGUON_MA + r")-\d{8}-\d+", cmd, re.I if TIEN_TO != "oHa" else 0):
    sys.exit(0)
print(f"⛔ Gửi vào nhóm sếp mà KHÔNG có mã {TIEN_TO}-… → sếp trả lời sẽ mất khỏi sổ việc.\n"
      f"Tin chữ: python3 scripts/sep-viec/sep_viec.py gui --ma {TIEN_TO}-<ngày giao gốc>-NN ...\n"
      f"Ảnh/PDF gửi kèm thì ghi mã {TIEN_TO}-… vào caption.", file=sys.stderr)
sys.exit(2)
