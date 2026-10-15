#!/usr/bin/env python3
"""afk_hoi_inbox_gate.py — PreToolUse hook, matcher `AskUserQuestion`.

Founder đang AFK (cờ do `afk_mode.py` bật, đọc qua `afk_trang_thai.py`) → CHẶN AskUserQuestion.
Lý do: hộp hỏi trong CLI không ai bấm, cả luồng đứng chờ tới lúc founder về. Anh Thành 11/10/2026:
«tao đã bảo tao đang /afk sao mày cứ hỏi cái câu AskUserQuestion thế … đã bảo /afk thì câu hỏi gửi
theo list vào inbox mà … fix đi». Luật markdown đã nói mà vẫn hỏi → chuyển xuống cổng tất định.

Lối ra (cổng phải có lối ra):
  · gửi danh sách câu hỏi vào inbox founder rồi CHỐT phương án đề xuất, chạy tiếp;
  · founder gõ «tao về rồi» / «ngồi máy rồi» / «tắt afk», hoặc quá 8 tiếng → cờ tự tắt, cổng im.
Không phá cổng Stop ép «phải gọi AskUserQuestion» (askback_enforce, ve_cho_founder, nghi_truoc_gate):
lượt gọi bị chặn VẪN nằm trong bản ghi hội thoại dưới dạng tool_use (đã đo trên bản ghi thật), nên
các cổng đó coi như đã hỏi — không kẹt vòng.

Không AFK → im, exit 0.
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import afk_trang_thai as _TT
except Exception:
    _TT = None


def loi_inbox(cwd: str) -> str:
    if "EtsyFulfillChichub" in cwd:
        return (
            "  ChicHub → MỘT tin riêng anh Thành (chạy --thu trước, rồi bỏ --thu gửi thật):\n"
            "    TASK_DEV_URL=https://fulfill.thechic.site node scripts/task-dev.mjs tin --rieng \\\n"
            "      --loai hoi --ma <Task-… của việc>   (chưa có thẻ: --loai khong-task --ly-do-khong-task \"…\") \\\n"
            "      --tieu-de \"Câu hỏi chờ anh quyết (đang AFK)\" \\\n"
            "      --da-lam $'1. <câu 1>\\n1A · <đề xuất> (đề xuất) · 1B · <khác>\\n2. …' \\\n"
            "      --xem-o \"<link màn hoặc: không có màn — chạy ngầm>\" \\\n"
            "      --can-lam \"**anh Thành** — trả lời kiểu 1A, 2B (Reply tin này)\" --thu\n"
        )
    du_an = os.path.basename(cwd.rstrip("/")) or "du-an"
    return (
        "  Dự án này → kênh inbox founder của dự án (nếu có). Không có thì ghi danh sách vào\n"
        f"    ~/.claude/afk/cau-hoi-{du_an}.md và nhắc lại đầu tiên khi founder gõ «tao về rồi».\n"
    )


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    if data.get("tool_name") != "AskUserQuestion" or _TT is None:
        return 0
    cwd = str(data.get("cwd") or os.getcwd())
    tt = _TT.dang_afk()
    tg = None
    if not tt:
        # Vé d991d9a878 (W301): lời mới nhất của anh đến từ Telegram, mới hơn lượt gõ CLI cuối = VẮNG.
        try:
            tg = _TT.vang_qua_telegram(cwd)
        except Exception:
            tg = None
        if not tg:
            return 0
    if tt:
        con = max(0, int(tt.get("het_han", 0)) - int(time.time()))
        dau = "⛔ ANH THÀNH ĐANG AFK"
        duoi = f"Cờ AFK tự hết sau {con // 3600} giờ {(con % 3600) // 60} phút, hoặc khi anh gõ «tao về rồi»."
    else:
        gio = lambda x: time.strftime("%H:%M %d/%m", time.localtime(x)) if x else "chưa có"
        dau = ("⛔ ANH THÀNH ĐANG LÀM QUA TELEGRAM (lời mới nhất của anh %s, lượt gõ CLI cuối %s)"
               % (gio(tg["tg"]), gio(tg["cli"])))
        duoi = "Cổng tự mở khi anh gõ một lượt trong CLI (mới hơn lời Telegram cuối)."
    ly_do = (
        dau + " → CẤM AskUserQuestion (hộp hỏi trong CLI không ai bấm, cả luồng đứng chờ).\n"
        "Làm thay: gom MỌI câu cần anh quyết thành DANH SÁCH đánh số `1.` `2.`, lựa chọn mang mã\n"
        "`1A · 1B · 1C`, khuyến nghị đặt đầu ghi «(đề xuất)», gửi MỘT tin vào INBOX:\n"
        + loi_inbox(cwd)
        + "Rồi KHÔNG CHỜ: chọn phương án đề xuất / theo quy trình mã đã có, ghi `CHỐT: … — vì …`,\n"
        "việc khác chạy tiếp. Lượt gọi bị chặn này đã tính là «đã hỏi» với các cổng Stop.\n"
        + duoi
    )
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": ly_do,
                }
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
