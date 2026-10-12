#!/usr/bin/env python3
"""afk_trang_thai.py — MỘT nguồn trạng thái «founder đang AFK» cho mọi hook.

Ghi: `afk_mode.py` (UserPromptSubmit) — bật khi founder báo rời máy, tắt khi founder báo đã về.
Đọc: `afk_hoi_inbox_gate.py` (PreToolUse:AskUserQuestion) — đang AFK thì chặn hỏi trong CLI.

WHY cờ nằm ở thư mục người dùng chứ không theo phiên: founder rời máy là rời MỌI phiên, mọi dự án;
phiên mới mở lúc founder vắng cũng không được hỏi trong CLI (anh Thành 11/10/2026: «đã bảo /afk thì
câu hỏi gửi theo list vào inbox mà»).
WHY tự hết sau 8 tiếng: founder hay quên gõ «tao về rồi»; cờ sống mãi thì hôm sau ngồi máy vẫn bị cấm
hỏi — cổng chặn phải có lối ra.
"""
import json
import os
import time

THU_MUC = os.path.expanduser("~/.claude/afk")
TEP = os.path.join(THU_MUC, "trang-thai.json")
HAN_GIAY = 8 * 3600


def bat(trich: str = "") -> None:
    os.makedirs(THU_MUC, exist_ok=True)
    bay_gio = int(time.time())
    with open(TEP, "w", encoding="utf-8") as f:
        json.dump(
            {"bat_luc": bay_gio, "het_han": bay_gio + HAN_GIAY, "trich": trich[:200]},
            f,
            ensure_ascii=False,
        )


def tat() -> None:
    try:
        os.remove(TEP)
    except FileNotFoundError:
        pass


def dang_afk():
    """dict trạng thái nếu đang AFK và chưa hết hạn, ngược lại None."""
    try:
        with open(TEP, encoding="utf-8") as f:
            tt = json.load(f)
    except Exception:
        return None
    if int(tt.get("het_han", 0)) <= int(time.time()):
        tat()
        return None
    return tt
