#!/usr/bin/env python3
# Vì sao: chủ quyết ngay trong CLI («Task-… 1A», «ừ làm đi») mà máy không ghi thẻ → thẻ đứng sai trạng thái.
# Luật markdown = xác suất → chuyển thành cổng (skill bot-nhan-viec mục 7). Một tệp, ba chế độ. Fail-open.
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

# Mã dự án oHa-…; mã cũ Task-… chủ gõ lại vẫn tính, quy đổi sang oHa- (thẻ trong kho đã đổi tên).
MA = re.compile(r"(?:" + NGUON_MA + r")-(?:\d{8}-\d{2,3}|CANH)", re.I if TIEN_TO != "oHa" else 0)


def doi_ma(m):
    return TIEN_TO + "-" + m.split("-", 1)[1]
QUYET = re.compile(r"\b\d[A-D]\b|\b(ừ|ok|oke|chốt|giữ nguyên|bỏ|làm đi)\b", re.I)
TIN_MAY = ("<task-notification>", "[SYSTEM NOTIFICATION")   # thông báo máy KHÔNG phải lời chủ
TRAN_CHAN = 3


def lenh_bash(dong):
    """Lấy mọi chuỗi command của tool_use Bash trong một dòng transcript."""
    try:
        d = json.loads(dong)
    except Exception:
        return []
    ra = []
    for c in (d.get("message") or {}).get("content") or []:
        if isinstance(c, dict) and c.get("type") == "tool_use" and c.get("name") == "Bash":
            ra.append(str((c.get("input") or {}).get("command", "")))
    return ra


def main():
    che_do = sys.argv[1] if len(sys.argv) > 1 else "--pre"
    d = json.load(sys.stdin)
    os.makedirs("/tmp/claude_hooks/ghi-the", exist_ok=True)
    kho = f"/tmp/claude_hooks/ghi-the/{d.get('session_id', 'x')}.json"
    tp = d.get("transcript_path") or ""

    if che_do == "--prompt":                       # UserPromptSubmit: lưu {mã, mốc}; không bao giờ chặn
        p = d.get("prompt", "") or ""
        if any(t in p for t in TIN_MAY):
            return
        ma = sorted({doi_ma(x) for x in MA.findall(p)})
        if ma and QUYET.search(p):
            moc = sum(1 for _ in open(tp, encoding="utf-8", errors="ignore")) if os.path.exists(tp) else 0
            json.dump({"ma": ma, "moc": moc, "lan": 0}, open(kho, "w"))
        return

    if che_do == "--stop":                         # Stop: CỔNG CHÍNH
        if not os.path.exists(kho):
            return
        k = json.load(open(kho))
        cmds = []
        if os.path.exists(tp):
            with open(tp, encoding="utf-8", errors="ignore") as f:
                for i, dong in enumerate(f):
                    if i >= k.get("moc", 0):
                        cmds += lenh_bash(dong)
        if any("khong-can-ghi-the:" in c for c in cmds):
            os.remove(kho)
            return
        thieu = [m for m in k["ma"] if not any(
            re.search(r"sep_viec\.py\s+(ghi|chuyen)\b", c)
            and re.search(r"--ma\s+['\"]?(?:" + NGUON_MA + r")-" + re.escape(m.split("-", 1)[1]) + r"\b", c, re.I) for c in cmds)]
        if not thieu or k.get("lan", 0) >= TRAN_CHAN:
            os.remove(kho)
            return
        k["lan"] = k.get("lan", 0) + 1
        json.dump(k, open(kho, "w"))
        ly_do = " ; ".join(f"python3 scripts/sep-viec/sep_viec.py ghi --ma {m} --noi-dung '<tình hình ngắn>'" for m in thieu)
        print(json.dumps({"decision": "block", "reason":
              f"Chủ vừa quyết trên thẻ {', '.join(thieu)} trong CLI mà chưa ghi thẻ. Ghi: {ly_do} "
              f"(hoặc chạy lệnh có chữ «khong-can-ghi-the: <lý do>» nếu thật sự không cần)."}, ensure_ascii=False))
        return

    # --pre (PreToolUse:Bash): nội dung ghi có dấu chép nguyên văn → chỉ nhắc, không chặn.
    if d.get("tool_name") != "Bash":
        return
    c = str((d.get("tool_input") or {}).get("command", ""))
    if re.search(r"sep_viec\.py\s+(ghi|chuyen)\b", c) and (re.search(r"\b(tao|mày)\b", c) or re.search(r"«[^»]{120,}»", c)):
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext":
              "Ghi TÌNH HÌNH ngắn lên thẻ bằng lời đời thường, đừng chép nguyên văn lời chủ."}}, ensure_ascii=False))


try:
    main()
except Exception:
    pass
sys.exit(0)
